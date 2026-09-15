#!/bin/sh
# Smoke test for py-manim. CI runs it inside the freshly built image, before
# anything is published, with the image's devcontainer.metadata label passed in:
#
#   docker run --rm --entrypoint /bin/sh -e DEVCONTAINER_METADATA="<label>" \
#     -v "$PWD/py-manim/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; its ancestors' tests cover what it inherits.
# MathTex needs the latex-shared volume, which CI does not mount, so this
# renders a Text scene: that exercises Pango, Cairo and ffmpeg without TeX.
# latex-sidecar's test covers manim's TeX path (latex -> DVI -> dvisvgm).
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

for tool in manim ffmpeg; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH"
done

# Set in the image itself so a plain `docker run` finds TinyTeX once mounted.
case ":$PATH:" in
  *:/opt/TinyTeX/bin/current:*) ;;
  *) fail "/opt/TinyTeX/bin/current is not on PATH ($PATH)" ;;
esac

python3 - <<'PY' || fail "devcontainer.metadata label is missing or does not mount latex-shared"
import json, os
entry = json.loads(os.environ.get("DEVCONTAINER_METADATA") or "null")[0]
assert any("source=latex-shared" in m and "target=/opt/TinyTeX" in m for m in entry["mounts"]), entry.get("mounts")
assert entry["remoteEnv"]["PATH"].startswith("/opt/TinyTeX/bin/current:"), entry["remoteEnv"]
PY

tmp=$(mktemp -d)
cat > "$tmp/scene.py" <<'PY'
from manim import Scene, Text

class Smoke(Scene):
    def construct(self):
        self.add(Text("smoke-test"))
        self.wait(0.2)
PY
cd "$tmp"
manim -ql --disable_caching --media_dir "$tmp/media" -o smoke scene.py Smoke >render.log 2>&1 \
  || { tail -25 render.log >&2; fail "manim could not render a Text scene"; }
find "$tmp/media" -name 'smoke.mp4' -size +0 | grep -q . || fail "manim rendered no video"

echo "ok: py-manim"
