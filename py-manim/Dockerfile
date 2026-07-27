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
# them after pip install (keeping only libcairo2 / libpango-1.0-0) would trim a
# few hundred MB, but is deliberately not done here to keep this Dockerfile
# consistent with the rest of the chain.
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
