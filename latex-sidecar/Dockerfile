# Use Debian Slim for a lightweight base without pre-existing UID 1000 users
FROM debian:12-slim

# Avoid interaction during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for TinyTeX
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    perl \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Create devuser with UID 1000 (cleaner on Debian)
RUN useradd -m -u 1000 devuser

# Switch to devuser to install TinyTeX
USER devuser
WORKDIR /home/devuser

# Install TinyTeX
RUN wget -qO- "https://yihui.org/tinytex/install-bin-unix.sh" | sh

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
