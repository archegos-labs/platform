# Runbook: migrating ClusterTrainingRuntimes off the Kubeflow Trainer operator release

One-time, per-cluster procedure. Run it **before** the first `terragrunt apply` that
carries the decoupled layout (`runtimes.defaultEnabled=false` on `helm_release.kubeflow_trainer`
plus the separate `helm_release.kubeflow_trainer_runtimes`).

## Why this exists

The upstream `kubeflow-trainer` chart bundled the 8 `ClusterTrainingRuntime` blueprints
into the same Helm release as the operator. That operator runs an in-pod cert rotator for
its validating webhook: on every `helm upgrade` the rotator refreshes the CA and patches the
new `caBundle` into the webhook configs immediately, but the webhook server keeps serving the
**old** cert until `certwatcher` reloads it from the projected mount ~20s later. Any
`ClusterTrainingRuntime` CREATE/UPDATE during that window is validated against the new
`caBundle` while the server presents the old cert, so it fails:

```
Error: cannot patch "<runtime>" with kind ClusterTrainingRuntime: ... failed calling webhook
"validator.clustertrainingruntime.trainer.kubeflow.org": ... tls: failed to verify certificate:
x509: certificate signed by unknown authority ... "kubeflow-trainer-ca"
```

Because the bundled CRs are patched inside that same `helm upgrade`, **every** operator
upgrade raced the window and failed. The fix moves the CRs into their own release
(`kubeflow-trainer-runtimes`) so the operator release never patches a webhook-validated
resource. See `kubeflow/charts/kubeflow-trainer-runtimes/Chart.yaml` for the full rationale.

The catch: on a cluster that **already** has the runtimes bundled, the plain code change is
not a no-op. `helm upgrade` would see the 8 CRs removed from the operator manifest and
**delete** them, then the new release would **recreate** them through the still-racing
webhook — reproducing the original failure. This runbook converts that into a clean,
in-place **adoption** (empty diff, zero webhook calls during CI) by doing the real spec
update while the webhook is healthy, then handing ownership to the new release.

## When to run / when to skip

- **Run it** on any existing cluster whose `ClusterTrainingRuntime`s are currently owned by
  the `kubeflow-trainer` release (check Step 1). This is the migration case.
- **Skip it** on a greenfield cluster with no `ClusterTrainingRuntime`s. The operator installs
  with runtimes off, then `kubeflow-trainer-runtimes` CREATEs them fresh. That CREATE can still
  catch the operator's initial cert-rotation window once; if the `kubeflow_trainer_runtimes`
  release fails with the x509 error, **re-run the apply** — the operator is `deployed` and quiet
  on the second pass, so the webhook is stable and the CREATE succeeds. (See Troubleshooting.)

## Variables

```bash
NS=kubeflow-system
RUNTIMES="deepspeed-distributed jax-distributed mlx-distributed torch-distributed \
torchtune-llama3.2-1b torchtune-llama3.2-3b torchtune-qwen2.5-1.5b xgboost-distributed"
CHART=kubeflow/charts/kubeflow-trainer-runtimes   # run from repo root
```

The chart is the source of truth for the runtime specs and the `helm.sh/resource-policy: keep`
annotation, so Step 3 applies whatever version is vendored there. Keep this runbook's
expectations in sync with that chart.

## Step 1 — Target the cluster and confirm the migration case

```bash
kubectl config current-context          # MUST be the intended cluster
kubectl get clustertrainingruntime -o custom-columns=\
'NAME:.metadata.name,RELEASE:.metadata.annotations.meta\.helm\.sh/release-name,KEEP:.metadata.annotations.helm\.sh/resource-policy'
```

- If `RELEASE` is `kubeflow-trainer` for the 8 CRs → migration case, continue.
- If there are no CRs → greenfield; skip to "When to run / when to skip".
- If `RELEASE` is already `kubeflow-trainer-runtimes` and `KEEP=keep` → migration already done; skip to Step 6.

## Step 2 — Confirm the webhook is healthy before touching anything

The migration relies on the webhook being consistent *now* so the spec update in Step 3
is accepted. Verify the served CA matches the webhook `caBundle`, and that a server-side
dry-run patch passes:

```bash
SCA=$(kubectl get secret kubeflow-trainer-webhook-cert -n "$NS" \
  -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -fingerprint)
WCA=$(kubectl get validatingwebhookconfiguration validator.trainer.kubeflow.org \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | openssl x509 -noout -fingerprint)
[ "$SCA" = "$WCA" ] && echo "CA CONSISTENT" || { echo "MISMATCH — wait and re-check"; }

kubectl label clustertrainingruntime torch-distributed _hc=1 --dry-run=server --overwrite
```

If the CA is inconsistent or the dry-run returns the x509 error, the rotator is mid-refresh.
Wait ~30s and re-check until both pass. Do **not** proceed during a refresh.

## Step 3 — Land the current runtime specs + `keep` (real change, webhook healthy)

This applies the vendored 2.x specs and the `helm.sh/resource-policy: keep` annotation in
one shot. On a cluster where the runtimes are at an older image tag, this is the genuine
upgrade — it is validated by the (currently healthy) webhook, so it succeeds here instead
of racing inside CI.

```bash
helm template kubeflow-trainer-runtimes "$CHART" | kubectl apply -f -
```

The `missing kubectl.kubernetes.io/last-applied-configuration` warnings are expected and
harmless (the CRs were created by Helm, not `kubectl apply`).

## Step 4 — Hand Helm ownership to the new release

So the `kubeflow-trainer-runtimes` release adopts these CRs instead of colliding on
ownership metadata:

```bash
for n in $RUNTIMES; do
  kubectl annotate clustertrainingruntime "$n" \
    meta.helm.sh/release-name=kubeflow-trainer-runtimes \
    meta.helm.sh/release-namespace="$NS" \
    --overwrite
done
```

`helm.sh/resource-policy: keep` is what stops the operator's runtimes-off upgrade from
deleting these CRs in Step 6; it was set by the chart manifest in Step 3.

## Step 5 — Verify the cluster now matches the chart (empty-diff adoption)

```bash
kubectl diff -f <(helm template kubeflow-trainer-runtimes "$CHART"); echo "diff exit: $?"
kubectl get clustertrainingruntime -o custom-columns=\
'NAME:.metadata.name,RELEASE:.metadata.annotations.meta\.helm\.sh/release-name,KEEP:.metadata.annotations.helm\.sh/resource-policy'
```

Expected: `kubectl diff` exits `0` (no diff), and every CR shows
`RELEASE=kubeflow-trainer-runtimes`, `KEEP=keep`. A non-empty diff means CI will issue a
webhook-validated patch and could race — reconcile it (re-run Step 3) before proceeding.

## Step 6 — Apply the decoupled layout via CI

Merge/deploy the branch so `terragrunt apply` runs the new `kubeflow/terraform/main.tf`. With
the cluster prepped:

- `helm_release.kubeflow_trainer` upgrades with `runtimes.defaultEnabled=false`. The 8 CRs are
  removed from its manifest but **kept** (resource-policy), so it deletes nothing and patches
  no webhook-validated resource → reaches `deployed` even from a prior `failed` state.
- `helm_release.kubeflow_trainer_runtimes` installs and **adopts** the 8 existing CRs (ownership
  matches, diff empty) → no webhook calls → succeeds.

## Step 7 — Post-checks

```bash
helm ls -n "$NS" | grep -E 'kubeflow-trainer($|-runtimes)'   # both Released/deployed
kubectl get clustertrainingruntime                            # all 8 present
```

## Troubleshooting

- **`invalid ownership metadata ... must equal "kubeflow-trainer-runtimes": current value is "kubeflow-trainer"`**
  during the `kubeflow_trainer_runtimes` install → Step 4 was skipped or incomplete. Re-run
  Step 4, then re-apply.
- **x509 `unknown authority` on the runtimes release** → a CR CREATE/UPDATE hit the cert
  window (greenfield, or a non-empty diff slipped through). It is transient: confirm the
  operator is `deployed` (`helm ls -n "$NS"`), confirm the webhook is healthy (Step 2), and
  **re-run the apply**. The operator no-op on the second pass does not refresh the cert, so
  the webhook is stable.
- **Operator release stuck `failed`** → the runtimes-off upgrade is what clears it; ensure
  Steps 3–5 are done so the upgrade has no CRs to patch, then apply.

## Caveats (DR / teardown)

- The `keep` policy means `helm uninstall kubeflow-trainer-runtimes` or `terraform destroy`
  leaves the 8 cluster-scoped CRs behind as **orphans** still bearing
  `meta.helm.sh/release-name: kubeflow-trainer-runtimes`. Before rebuilding the stack, delete
  them so a fresh install adopts cleanly:
  ```bash
  for n in $RUNTIMES; do kubectl delete clustertrainingruntime "$n" --ignore-not-found; done
  ```
- A rebuilt/DR cluster restored from such orphans is a *migration case*, not greenfield — run
  this runbook (or delete the orphans first and treat it as greenfield).
- Editing the vendored runtimes requires bumping `version` in
  `kubeflow/charts/kubeflow-trainer-runtimes/Chart.yaml`, or the helm provider treats the local
  chart as unchanged and `terragrunt apply` skips the update.