FROM ghcr.io/mk-imagine/r-stats-base:latest

COPY r-packages.txt /tmp/
COPY install.R /tmp/

USER devuser
RUN Rscript /tmp/install.R
