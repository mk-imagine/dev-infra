# latex-base — minimal runtime image for consuming the latex-shared volume.
#
# Companion to latex-sidecar. The sidecar POPULATES the shared TinyTeX volume;
# this image is the minimal Debian base that RUNS LaTeX from it. Consuming
# devcontainers mount the `latex-shared` volume at /opt/TinyTeX (PATH already
# points at /opt/TinyTeX/bin/current below).
#
# Do NOT install a system texlive here — TinyTeX lives entirely in the volume.
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime dependencies for XeLaTeX/LuaLaTeX + latexmk + on-demand tlmgr installs:
#   perl            — latexmk is a Perl script
#   libfontconfig1  — XeLaTeX fails to start without it (fontspec / OpenType)
#   fontconfig      — fc-cache for fonts installed into the volume
#   gnupg           — tlmgr verified downloads
#   wget            — tlmgr package downloader
#   ca-certificates — HTTPS for tlmgr / CTAN
#   git             — devcontainer / source hygiene
#   python3         — utility scripts (e.g. aux-file cleanup)
RUN apt-get update && apt-get install -y --no-install-recommends \
        perl \
        libfontconfig1 \
        fontconfig \
        gnupg \
        wget \
        ca-certificates \
        git \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# UID 1000 user matching the ownership of the latex-shared volume (devuser in
# latex-sidecar). Keeps file ownership consistent across the sidecar and here.
RUN useradd -m -u 1000 devuser

# Make the volume's TinyTeX binaries discoverable once the volume is mounted.
ENV PATH="/opt/TinyTeX/bin/current:${PATH}"

USER devuser
WORKDIR /home/devuser
