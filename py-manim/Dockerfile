# Manim animation image.
#
# Parent is py-sci-jupyter rather than a deeper image in the chain: manim's
# `%%manim` cell magic renders a scene and embeds the resulting video inline in
# the notebook output, which is the practical authoring loop for animations.
# The Jupyter layer costs three pure-Python packages; the torch images below it
# would add a multi-GB stack this image never imports.
#
# LaTeX comes from the `latex-shared` volume, not from packages here. Manim's
# Tex/MathTex path is `latex` -> .dvi -> `dvisvgm` -> SVG, so the volume must
# provide standalone, dvisvgm and babel-english (see latex-sidecar).

FROM ghcr.io/mk-imagine/py-sci-jupyter:latest

USER root

# ffmpeg          — manim shells out to it to mux frames into video
# libcairo2-dev   — pycairo publishes no wheels and builds from source
# libpango1.0-dev — manimpango (text layout), likewise built from source
# pkg-config      — pycairo's build uses it to locate cairo
#
# The -dev packages are build-time requirements that stay in the image. Dropping
# them is possible but deliberately not done. Measured on arm64, it saves 180MB
# (1.70GB -> 1.52GB) and costs more than it returns:
#   - The purge must share a RUN with the pip install. A later layer cannot
#     shrink an earlier one, so a separate cleanup layer reclaims nothing.
#   - That means hand-maintaining a runtime list (libcairo2, libpango-1.0-0,
#     libpangocairo-1.0-0) apart from the build list. A mistake there surfaces
#     at runtime in a published image, not as a failed build.
#   - It also abandons the flat apt-packages.txt convention used chain-wide.
# build-essential is not reclaimable at all — it lives in py-sci-base's layer.
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Mount the sidecar volume and put TinyTeX on PATH. The LaTeX-authoring VS Code
# extensions carried by py-sci-jupyter-torch-latex are intentionally omitted:
# manim invokes latex internally, so the binaries are needed but a .tex editing
# IDE is not.
LABEL devcontainer.metadata='[{"mounts":["source=latex-shared,target=/opt/TinyTeX,type=volume"],"remoteEnv":{"PATH":"/opt/TinyTeX/bin/current:${containerEnv:PATH}"},"customizations":{"vscode":{"extensions":["ms-python.python","ms-toolsai.jupyter"]}}}]'

# Also set PATH in the image itself so `docker run` works without a devcontainer.
ENV PATH="/opt/TinyTeX/bin/current:${PATH}"

USER devuser
