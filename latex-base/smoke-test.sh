#!/bin/sh
# Smoke test for latex-base. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/latex-base/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# The same command works locally against a `docker build -t latex-base:local`.
#
# It checks this image's own contract. TinyTeX is not in the image -- it arrives
# through the latex-shared volume -- so nothing here compiles LaTeX; that is
# latex-sidecar's smoke test.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

# The latex-shared volume is owned by UID 1000; any other UID cannot write to it.
[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

# Every tool the Dockerfile installs is on PATH.
for tool in perl fc-cache gpg wget git python3 pdftoppm pdftocairo pdfinfo pdftotext; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH"
done

# TinyTeX's binaries are found once the volume is mounted.
case ":$PATH:" in
  *:/opt/TinyTeX/bin/current:*) ;;
  *) fail "/opt/TinyTeX/bin/current is not on PATH ($PATH)" ;;
esac

# poppler reads a real PDF, not just exists: a missing shared library still
# passes `command -v` above and fails here. python3 writes a one-page PDF so no
# TeX is needed.
tmp=$(mktemp -d)
python3 - "$tmp/t.pdf" <<'PY'
import sys
content = b"BT /F1 24 Tf 20 40 Td (smoke-test) Tj ET"
objs = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Contents 4 0 R"
    b" /Resources << /Font << /F1 5 0 R >> >> >>",
    b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
]
out = bytearray(b"%PDF-1.4\n")
offsets = []
for n, body in enumerate(objs, 1):
    offsets.append(len(out))
    out += b"%d 0 obj\n" % n + body + b"\nendobj\n"
xref = len(out)
out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
out += b"".join(b"%010d 00000 n \n" % o for o in offsets)
out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
open(sys.argv[1], "wb").write(out)
PY

pages=$(pdfinfo "$tmp/t.pdf" | awk '/^Pages:/ {print $2}')
[ "$pages" = 1 ] || fail "pdfinfo read '$pages' pages from a one-page PDF"
pdftotext "$tmp/t.pdf" - | grep -q smoke-test || fail "pdftotext did not extract the page text"
pdftoppm -png -r 36 "$tmp/t.pdf" "$tmp/page" || fail "pdftoppm exited non-zero"
set -- "$tmp"/page*.png
[ -s "$1" ] || fail "pdftoppm produced no PNG"

echo "ok: latex-base"
