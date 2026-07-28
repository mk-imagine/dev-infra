# Data-science / curriculum-authoring image.
#
# Parent is py-sci-jupyter-torch-latex, so the LaTeX devcontainer.metadata
# LABEL (sidecar mount, PATH, VS Code extensions/settings) is inherited --
# curriculum sources render to PDF/Beamer as well as .ipynb.
#
# Adds the notebook-authoring and execution stack that the parent chain
# lacks: programmatic notebook execution (nbclient/nbformat), plotting
# (matplotlib/seaborn), extended serialization (dill), and pytest for
# in-notebook verification cells. Also carries the figure-rendering stack --
# hand-authored SVG diagrams are rasterized and measured here rather than on
# whatever host happens to be driving the build.

FROM ghcr.io/mk-imagine/py-sci-jupyter-torch-latex:latest

USER root

# fonts-dejavu  — the typeface curriculum figures are authored in. py-manim
#                 already renders with DejaVu, so pinning the same family here
#                 means an animation and the hand-authored SVG of the same
#                 diagram agree instead of drifting apart. With no system font
#                 installed, fontconfig silently substitutes and every measured
#                 text extent is wrong -- the failure is invisible in the PNG.
# fontconfig    — font discovery (fc-match/fc-list). Also how a build script
#                 asserts the intended family actually resolved rather than
#                 trusting that it did.
# libcairo2     — cairosvg's rendering backend.
# librsvg2-bin  — rsvg-convert, the reference SVG->PNG renderer for this image.
#                 It shapes text through Pango/HarfBuzz; cairosvg goes through
#                 cairo's "toy" text API, which is fine for embedding but not
#                 trustworthy for measuring text-heavy figures. Both ship; the
#                 README names which one is authoritative.
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# The default user is non-root, so a `pip install` run inside a live container
# (a consuming repo installing its own package editable, say) cannot write to
# system site-packages and silently falls back to the user scheme. Imports still
# work, but console scripts land in ~/.local/bin, which is not otherwise on PATH
# -- so an installed CLI comes back "command not found" while `import` succeeds.
# pip warns about this and the warning scrolls past in container-create output.
#
# Set here rather than as devcontainer.metadata remoteEnv so it also holds for a
# plain `docker run`. The inherited LaTeX remoteEnv interpolates
# ${containerEnv:PATH}, so it composes with this rather than overwriting it.
ENV PATH="/home/devuser/.local/bin:${PATH}"

USER devuser
