# GPU / PyTorch image, targeting a single local Ubuntu box with an RTX 3070
# (Ampere, sm_86) used for prototyping.
#
# Deliberately NOT part of the py-sci-* chain and not a child of py-sci-base:
#   - It carries no Jupyter layer and none of the pandas/openpyxl science stack.
#   - It is amd64-only, because PyTorch publishes CUDA wheels for x86_64 alone.
#     As a child of a multi-arch parent it would be an image whose platform set
#     is a strict subset of its parent's.
#   - py-sci-jupyter-torch pins the /cpu wheel index. Putting a CUDA image
#     anywhere beneath it makes "which torch did I get" a live question at every
#     layer of the chain.
#   - A cascade from py-sci-base would trigger a multi-GB CUDA rebuild whenever
#     an unrelated spreadsheet dependency moved.
#
# No nvidia/cuda base image, on purpose. The PyTorch CUDA wheels vendor their
# own CUDA runtime and cuDNN as ordinary pip dependencies (the nvidia-*
# packages), so the only host requirements are the NVIDIA driver and
# nvidia-container-toolkit. An nvidia/cuda base would roughly double the image
# to supply a toolkit that only matters when compiling CUDA extensions from
# source, which this image does not do. If that need appears, add a -devel
# variant rather than inflating this one.
#
# Verified on the target hardware (driver 580.173.02, torch 2.13.0+cu132):
#   torch.cuda.get_arch_list() -> [sm_75, sm_80, sm_86, sm_90, sm_100, sm_120]
#   fp16 8192^3 matmul         -> 32.2 TFLOP/s
# sm_86 is compiled in natively, so Ampere is not running on a PTX JIT fallback
# -- worth re-checking whenever the cu index is bumped, since CUDA 13 already
# dropped every architecture below Turing.

FROM python:3.13-slim

# git, curl -- cloning and fetching experiment code on a prototyping box.
#
# Torch itself needs no apt packages whatsoever: the CUDA wheels are entirely
# self-contained. That was confirmed by installing them into a stock
# python:3.13-slim container with nothing added. These two are a usability
# choice, not a dependency.
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 devuser

COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# The default user is non-root, so a `pip install` run inside a live container
# cannot write to system site-packages and falls back to the user scheme.
# Imports still work, but console scripts land in ~/.local/bin, which is not
# otherwise on PATH -- an installed CLI then comes back "command not found"
# while `import` succeeds. Same reasoning as py-dsml.
ENV PATH="/home/devuser/.local/bin:${PATH}"

USER devuser
