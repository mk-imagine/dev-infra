#!/bin/sh
# Smoke test for py-sci-psy. CI runs it inside the freshly built image, before
# anything is published, with the image's devcontainer.metadata label passed in:
#
#   docker run --rm --entrypoint /bin/sh -e DEVCONTAINER_METADATA="<label>" \
#     -v "$PWD/py-sci-psy/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; py-sci-base's test covers what it inherits.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

# pip installs as devuser land console scripts in ~/.local/bin, which must be
# on PATH or an installed CLI is "command not found" while its import works.
case ":$PATH:" in
  *:/home/devuser/.local/bin:*) ;;
  *) fail "/home/devuser/.local/bin is not on PATH ($PATH)" ;;
esac

# fontconfig substitutes silently: a missing family shows up as wrong glyph
# metrics in a figure, never as an error.
family=$(fc-match -f '%{family}' DejaVuSans)
case "$family" in
  *"DejaVu Sans"*) ;;
  *) fail "DejaVu Sans is not installed; fontconfig substituted '$family'" ;;
esac

# The devcontainer.metadata label mounts latex-shared and puts TinyTeX on PATH.
# It is a copy of py-sci-jupyter-torch-latex's label, so it can drift.
python3 - <<'PY' || fail "devcontainer.metadata label is missing or does not mount latex-shared"
import json, os
entry = json.loads(os.environ.get("DEVCONTAINER_METADATA") or "null")[0]
assert any("source=latex-shared" in m and "target=/opt/TinyTeX" in m for m in entry["mounts"]), entry.get("mounts")
assert entry["remoteEnv"]["PATH"].startswith("/opt/TinyTeX/bin/current:"), entry["remoteEnv"]
PY

# kaleido renders through chromium: write_image() is the thing this image exists
# for, and it fails without a working browser. PDF output is what LaTeX consumes.
out=$(python3 - <<'PY'
import os, tempfile
import plotly.graph_objects as go
fig = go.Figure(go.Bar(x=["a", "b"], y=[1, 2]))
fig.update_layout(title_text="smoke-test")
d = tempfile.mkdtemp()
for ext in ("png", "svg", "pdf"):
    path = os.path.join(d, "figure." + ext)
    fig.write_image(path)
    assert os.path.getsize(path) > 0, path
print(d)
PY
) || fail "plotly could not export a figure through kaleido"

# The exported PDF carries its title as real text.
pdftotext "$out/figure.pdf" - | grep -q smoke-test || fail "exported PDF does not contain the figure title as text"

echo "ok: py-sci-psy"
