#!/bin/sh
# Smoke test for py-sci-jupyter-torch. CI runs it inside the freshly built image,
# before anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/py-sci-jupyter-torch/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; its ancestors' tests cover what it inherits.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

python3 - <<'PY' || fail "the torch stack does not run"
import torch
import torchaudio
import torchvision
from torchvision.ops import nms

# CPU wheels by design (requirements.txt uses the /whl/cpu index).
assert torch.version.cuda is None, f"expected CPU wheels, got a CUDA {torch.version.cuda} build"

x = torch.arange(6, dtype=torch.float32).reshape(2, 3)
assert x.sum().item() == 15.0

# torchvision's compiled ops load against this torch. A version mismatch
# between the two wheels imports fine and fails here.
boxes = torch.tensor([[0.0, 0.0, 1.0, 1.0], [0.0, 0.0, 1.0, 1.0]])
assert nms(boxes, torch.tensor([0.9, 0.8]), 0.5).tolist() == [0]
PY

echo "ok: py-sci-jupyter-torch"
