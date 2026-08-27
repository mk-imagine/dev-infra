FROM rocker/r-ver:4.5.2

ARG PANDOC_VERSION=3.9
ARG TARGETARCH

# 1. Install system dependencies
#
# libuv1-dev is required by the R package `fs`, which vendored its own libuv
# until 2.1.0 and now links the system one. `fs` is not in r-packages.txt -- it
# arrives as a transitive dependency, and when it fails to configure it takes
# sass, gargle and pkgload with it, and through them bslib, rmarkdown,
# roxygen2, googledrive, googlesheets4, reprex, languageserver and tidyverse.
# The build error that surfaces names tidyverse, not fs, so start at the first
# configure failure rather than the last one reported.
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Pandoc (pinned version, multi-arch)
RUN curl -sL "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-linux-${TARGETARCH}.tar.gz" \
    | tar xz --strip-components=1 -C /usr/local/

# 3. Create devuser with UID 1000 and grant R library permissions
RUN useradd -m -u 1000 devuser && \
    chown -R devuser:devuser /usr/local/lib/R/site-library

# 4. Install radian (R console)
RUN pip3 install --no-cache-dir --break-system-packages radian

# 5. Install core R packages as devuser
USER devuser
COPY r-packages.txt /tmp/
COPY install.R /tmp/
RUN Rscript /tmp/install.R

# 6. Install APA CSL style for pandoc
RUN mkdir -p /home/devuser/.pandoc/csl && \
    curl -sL -o /home/devuser/.pandoc/csl/apa.csl \
      https://www.zotero.org/styles/apa
