FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Bump to latest release from https://github.com/plantuml/plantuml/releases
ARG PLANTUML_VERSION=1.2024.8

# 1. System dependencies (JRE, Graphviz, fonts, download tools)
COPY apt-packages.txt /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends \
    $(cat /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

# 2. Create devuser with UID 1000
RUN useradd -m -u 1000 devuser

# 3. Download pinned PlantUML jar and install wrapper
RUN mkdir -p /opt/plantuml && \
    curl -fsSL -o /opt/plantuml/plantuml.jar \
        "https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar" && \
    printf '#!/bin/sh\nexec java -jar /opt/plantuml/plantuml.jar "$@"\n' > /usr/local/bin/plantuml && \
    chmod +x /usr/local/bin/plantuml

WORKDIR /work
USER devuser
