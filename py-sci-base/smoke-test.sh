#!/bin/sh
# Smoke test for py-sci-base. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/py-sci-base/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks what this image adds. Every Python image descends from it, so each
# child's own smoke test covers only that child's layer.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

for tool in git curl gcc make pdfinfo pdftotext pdftoppm; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH"
done

# The scientific stack does real work: a DataFrame round-trips through .xlsx,
# which needs numpy, pandas and openpyxl together.
python3 - <<'PY' || fail "numpy/pandas/openpyxl could not round-trip a DataFrame through xlsx"
import os, tempfile
import numpy as np
import pandas as pd
df = pd.DataFrame({"x": np.arange(3), "y": np.linspace(0.0, 1.0, 3)})
path = os.path.join(tempfile.mkdtemp(), "t.xlsx")
df.to_excel(path, index=False, engine="openpyxl")
back = pd.read_excel(path, engine="openpyxl")
assert back.equals(df), back
PY

# poppler reads a real PDF, not just exists: a missing shared library passes
# `command -v` and fails here.
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

echo "ok: py-sci-base"
