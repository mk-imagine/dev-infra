FROM ghcr.io/mk-imagine/r-stats-base:latest

COPY r-packages.txt /tmp/
COPY install.R /tmp/

USER devuser
RUN Rscript /tmp/install.R

# Routliers is not in r-packages.txt because CRAN archived it on 2026-05-08 (the
# maintainer's email was undeliverable). install.R cannot find an archived
# package in the CRAN index and would stop the build, so its last release is
# installed from the CRAN archive instead, pinned like the other versions in
# this repo. Its dependencies (MASS, ggplot2) are already present. The trailing
# library() fails the build if the install did not take, because
# install.packages() only warns.
ARG ROUTLIERS_VERSION=0.0.0.3
RUN Rscript -e "install.packages('https://cran.r-project.org/src/contrib/Archive/Routliers/Routliers_${ROUTLIERS_VERSION}.tar.gz', repos = NULL, type = 'source'); library(Routliers)"
