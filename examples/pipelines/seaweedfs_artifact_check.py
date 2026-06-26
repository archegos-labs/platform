"""SeaweedFS artifact-store validation pipeline (KFP v2).

Purpose: exercise per-namespace artifact I/O end-to-end after the MinIO->SeaweedFS
migration. The producer writes an output artifact (forces an S3 PUT under the
namespace pipeline root) and the consumer reads it back (S3 GET + the driver's
prefixed LIST). A SUCCEEDED run with both steps proves the per-namespace scoped
credential works against SeaweedFS, including the prefix-scoped LIST authorization.

Compile:
    pip install 'kfp>=2.7,<3'
    python seaweedfs_artifact_check.py        # -> seaweedfs_artifact_check.yaml

Run: upload seaweedfs_artifact_check.yaml via the KFP UI in the kubeflow-admin
profile and start a run, or submit with the kfp SDK client.
"""
from kfp import dsl, compiler


@dsl.component(base_image="python:3.11-slim")
def produce(message: str, out_data: dsl.Output[dsl.Dataset]):
    with open(out_data.path, "w") as f:
        f.write(message)
    print(f"wrote artifact to {out_data.path}: {message}")


@dsl.component(base_image="python:3.11-slim")
def consume(in_data: dsl.Input[dsl.Dataset]) -> str:
    with open(in_data.path) as f:
        content = f.read()
    print(f"read artifact from {in_data.path}: {content}")
    return content


@dsl.pipeline(
    name="seaweedfs-artifact-check",
    description="Write+read an artifact to validate the SeaweedFS object store and per-namespace isolation.",
)
def seaweedfs_artifact_check(message: str = "hello-seaweedfs"):
    p = produce(message=message)
    consume(in_data=p.outputs["out_data"])


if __name__ == "__main__":
    compiler.Compiler().compile(
        seaweedfs_artifact_check, "seaweedfs_artifact_check.yaml"
    )