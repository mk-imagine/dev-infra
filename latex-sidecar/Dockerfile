# Use Debian Slim for a lightweight base without pre-existing UID 1000 users
FROM debian:12-slim

# Avoid interaction during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for TinyTeX.
#   wget            — TinyTeX installer + tlmgr package downloads
#   perl            — tlmgr and latexmk are Perl scripts
#   ca-certificates — HTTPS for CTAN / tlnet
#   xz-utils        — TinyTeX bundle decompression
#   gnupg           — verifies the tlmgr package repository. Without it every
#                     tlmgr call warns "not verified: gpg unavailable" and
#                     packages are installed unauthenticated.
#   libfontconfig1  — XeTeX links against it; without it `fmtutil` cannot build
#                     xetex.fmt and any tlmgr install that triggers a format
#                     rebuild exits non-zero (see `tlmgr install babel-english`).
#   fontconfig      — fc-cache, for fonts installed into the volume
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    perl \
    ca-certificates \
    xz-utils \
    gnupg \
    libfontconfig1 \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Create devuser with UID 1000 (cleaner on Debian)
RUN useradd -m -u 1000 devuser

# Copy package list (done as root, readable by all)
COPY latex_packages.txt /tmp/latex-packages.txt

# Switch to devuser to install TinyTeX
USER devuser
WORKDIR /home/devuser

# Install TinyTeX
RUN wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh

# Bring tlmgr and the base TinyTeX bundle up to date, then install extra LaTeX
# packages (strip comments, blank lines, macOS-only entries).
#
# The `tlmgr update --self --all` MUST share a layer with the package install.
# The TinyTeX bundle above is a point-in-time snapshot while the tlnet repo
# keeps moving, so tlmgr goes stale and then refuses to do anything:
#     "tlmgr itself needs to be updated ... tlmgr: Terminating"
# If the self-update lived in its own RUN it would be served from build cache
# while this layer re-ran on any latex_packages.txt edit — reintroducing the
# exact staleness it exists to prevent. Keeping them together means tlmgr is
# always current at the moment packages are installed.
RUN TLMGR="$(echo /home/devuser/.TinyTeX/bin/*/tlmgr)" && \
    "$TLMGR" update --self --all && \
    sed 's/#.*//' /tmp/latex-packages.txt | \
    grep -v -E '(\.universal-darwin|^[[:space:]]*$)' | \
    xargs "$TLMGR" install

# Switch back to root to set up staging
USER root

# Create staging directory and move TinyTeX there
RUN mkdir -p /opt/staging && \
    mv /home/devuser/.TinyTeX /opt/staging/TinyTeX && \
    chown -R 1000:1000 /opt/staging/TinyTeX

# Prepare the target volume mount point
RUN mkdir -p /opt/TinyTeX && \
    chown 1000:1000 /opt/TinyTeX

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# The volume will be mounted at /opt/TinyTeX
VOLUME /opt/TinyTeX

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
