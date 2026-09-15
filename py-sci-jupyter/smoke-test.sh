#!/bin/sh
# Smoke test for py-sci-jupyter. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/py-sci-jupyter/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; py-sci-base's test covers what it inherits.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

# A kernel starts and executes code. Importing ipykernel does not prove that --
# the kernelspec, jupyter_client and the ZMQ transport all have to work.
python3 - <<'PY' || fail "could not start a python3 kernel and execute code in it"
import IPython, ipywidgets, ipykernel
from jupyter_client.kernelspec import KernelSpecManager
from jupyter_client.manager import start_new_kernel

specs = KernelSpecManager().find_kernel_specs()
assert "python3" in specs, f"no python3 kernelspec: {specs}"

km, kc = start_new_kernel(kernel_name="python3")
out = []
try:
    reply = kc.execute_interactive("print(6 * 7)", timeout=60, output_hook=out.append)
    assert reply["content"]["status"] == "ok", reply["content"]
    text = "".join(m["content"]["text"] for m in out if m["msg_type"] == "stream")
    assert text.strip() == "42", repr(text)
finally:
    kc.stop_channels()
    km.shutdown_kernel(now=True)
PY

echo "ok: py-sci-jupyter"
