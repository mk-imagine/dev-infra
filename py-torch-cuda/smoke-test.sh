#!/bin/sh
# Smoke test for py-torch-cuda. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/py-torch-cuda/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# CI runners have no GPU, so this cannot check torch.cuda.is_available() or the
# compiled architecture list -- the Ampere check in CLAUDE.md stays manual. What
# it can check is the failure this image is most exposed to: a CPU-only torch
# arriving from PyPI instead of the CUDA index.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

case ":$PATH:" in
  *:/home/devuser/.local/bin:*) ;;
  *) fail "/home/devuser/.local/bin is not on PATH ($PATH)" ;;
esac

for tool in git curl; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH"
done

python3 - <<'PY' || fail "torch is not a working CUDA build"
import numpy
import torch
import torchvision
from torchvision.ops import nms

assert torch.version.cuda is not None, "torch is a CPU-only build: the CUDA index was not used"
assert "+cu" in torch.__version__, f"torch {torch.__version__} is not a CUDA wheel"
assert "+cu" in torchvision.__version__, f"torchvision {torchvision.__version__} is not a CUDA wheel"

# torchvision's compiled ops load against this torch. A version mismatch
# between the two wheels imports fine and fails here.
boxes = torch.tensor([[0.0, 0.0, 1.0, 1.0], [0.0, 0.0, 1.0, 1.0]])
assert nms(boxes, torch.tensor([0.9, 0.8]), 0.5).tolist() == [0]
assert torch.from_numpy(numpy.arange(4.0)).sum().item() == 6.0
PY

echo "ok: py-torch-cuda"
