#!/bin/sh
# Smoke test for py-dsml. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/py-dsml/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; its ancestors' tests cover what it inherits.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

case ":$PATH:" in
  *:/home/devuser/.local/bin:*) ;;
  *) fail "/home/devuser/.local/bin is not on PATH ($PATH)" ;;
esac

command -v rsvg-convert >/dev/null 2>&1 || fail "rsvg-convert is not on PATH"

# fontconfig substitutes silently: a missing family shows up as wrong glyph
# metrics in a figure, never as an error.
family=$(fc-match -f '%{family}' DejaVuSans)
case "$family" in
  *"DejaVu Sans"*) ;;
  *) fail "DejaVu Sans is not installed; fontconfig substituted '$family'" ;;
esac

python3 -m pytest --version >/dev/null 2>&1 || fail "pytest does not run"

out=$(python3 - <<'PY'
import os, tempfile
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import dill, imagehash, nbclient, nbformat, seaborn, torch
from PIL import Image

d = tempfile.mkdtemp()

# Executing a notebook is what this image is for.
nb = nbformat.v4.new_notebook()
nb.cells = [nbformat.v4.new_code_cell("print(6 * 7)")]
nbclient.NotebookClient(nb, kernel_name="python3", timeout=120).execute()
assert nb.cells[0].outputs[0]["text"].strip() == "42", nb.cells[0].outputs

# A seaborn figure to both raster and vector.
fig, ax = plt.subplots()
seaborn.lineplot(x=[0, 1, 2], y=[0, 1, 4], ax=ax)
fig.savefig(os.path.join(d, "figure.png"))
fig.savefig(os.path.join(d, "figure.svg"))

# dill round-trips what pickle cannot.
assert dill.loads(dill.dumps(lambda v: v + 1))(1) == 2

# imagehash on the rendered figure.
assert len(str(imagehash.phash(Image.open(os.path.join(d, "figure.png"))))) == 16
print(d)
PY
) || fail "notebook execution, plotting, dill or imagehash does not work"

rsvg-convert "$out/figure.svg" -o "$out/from-svg.png" || fail "rsvg-convert could not render the SVG"
[ -s "$out/from-svg.png" ] || fail "rsvg-convert produced an empty PNG"

echo "ok: py-dsml"
