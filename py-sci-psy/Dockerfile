# Psychology-research image: numpy/pandas modelling plus plotly figures that
# land in LaTeX documents.
#
# Parent is py-sci-base, NOT the py-sci-jupyter chain. The consuming work is
# script-driven rather than notebook-driven, so ipython/ipywidgets/ipykernel
# would be dead weight, and nothing here needs scikit-learn, optuna, or torch.
# If a torch model appears later, add the CPU wheels to this image rather than
# reparenting it under py-sci-jupyter-torch -- the Jupyter layer is the part
# that isn't wanted, not the torch layer.
#
# Deliberately NOT a child of py-torch-cuda either. That image is amd64-only
# (PyTorch publishes CUDA wheels for x86_64 alone) and is aimed at a specific
# RTX 3070 box; a child of it could not run natively on an arm64 workstation,
# and would carry multi-GB nvidia-* wheels for a workload whose heaviest
# dependency is numpy.
#
# The devcontainer.metadata LABEL is copied from py-sci-jupyter-torch-latex
# rather than inherited, since that image sits on the other branch of the tree.
# It brings in the latex-sidecar mount, the PATH extension, and the LaTeX
# VS Code setup. Keep the two copies in sync when either changes.
# Spec: https://containers.dev/implementors/spec/#image-metadata

FROM ghcr.io/mk-imagine/py-sci-base:latest

USER root

# chromium      — kaleido v1 renders figures by driving a real browser; without
#                 one, every write_image() call raises "Kaleido requires Google
#                 Chrome to be installed". Debian's chromium is used rather than
#                 `plotly_get_chrome`, which fetches Chrome for Testing — that
#                 is published for linux64 only, so it cannot serve the arm64
#                 half of a multi-arch image. chromium-sandbox is deliberately
#                 absent: kaleido launches the browser with --no-sandbox itself,
#                 and the setuid helper cannot acquire namespaces in a default
#                 container anyway.
# fonts-dejavu  — chromium ships no fonts. With none installed, exported figures
#                 render every label as tofu boxes. Same family py-manim and
#                 py-dsml use, so a figure keeps its metrics across images.
# fontconfig    — font discovery (fc-match/fc-list), and how a build script
#                 asserts the intended family actually resolved.
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# kaleido discovers /usr/bin/chromium on its own today. Pinning it makes the
# renderer explicit: figure output depends on which browser draws it, so a
# second browser arriving in the image later should not silently change what
# the figures look like.
ENV BROWSER_PATH=/usr/bin/chromium

# The default user is non-root, so a `pip install` run inside a live container
# cannot write to system site-packages and falls back to the user scheme.
# Imports still work, but console scripts land in ~/.local/bin, which is not
# otherwise on PATH — an installed CLI then comes back "command not found"
# while `import` succeeds. Same reasoning as py-dsml and py-torch-cuda.
ENV PATH="/home/devuser/.local/bin:${PATH}"

LABEL devcontainer.metadata='[{"mounts":["source=latex-shared,target=/opt/TinyTeX,type=volume"],"remoteEnv":{"PATH":"/opt/TinyTeX/bin/current:${containerEnv:PATH}"},"customizations":{"vscode":{"extensions":["James-Yu.latex-workshop","tecosaur.latex-utilities"],"settings":{"latex-workshop.latex.outDir":"%DIR%/build","latex-workshop.latex.autoBuild.run":"onFileChange","latex-workshop.latex.recipe.default":"latexmk (latexmk)","latex-workshop.view.pdf.viewer":"tab","latex-workshop.latex.clean.subfolder.enabled":true,"latex-workshop.latex.autoClean.run":"onFailed","latex-workshop.message.update.show":false}}}}]'

USER devuser
