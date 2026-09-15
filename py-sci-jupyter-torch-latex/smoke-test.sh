#!/bin/sh
# Smoke test for py-sci-jupyter-torch-latex. CI runs it inside the freshly built
# image, before anything is published, with the image's devcontainer.metadata
# label passed in:
#
#   docker run --rm --entrypoint /bin/sh -e DEVCONTAINER_METADATA="<label>" \
#     -v "$PWD/py-sci-jupyter-torch-latex/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# This image adds no packages -- only the devcontainer.metadata label -- so the
# label is its whole contract.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

python3 - <<'PY' || fail "devcontainer.metadata label is missing or wrong"
import json, os
entry = json.loads(os.environ.get("DEVCONTAINER_METADATA") or "null")[0]
assert any("source=latex-shared" in m and "target=/opt/TinyTeX" in m for m in entry["mounts"]), entry.get("mounts")
assert entry["remoteEnv"]["PATH"].startswith("/opt/TinyTeX/bin/current:"), entry["remoteEnv"]
assert "James-Yu.latex-workshop" in entry["customizations"]["vscode"]["extensions"], entry["customizations"]
PY

# The torch stack underneath still loads through the label layer.
python3 -c "import torch, torchvision" || fail "torch no longer imports"

echo "ok: py-sci-jupyter-torch-latex"
