#!/bin/sh
# Smoke test for r-stats-base. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/r-stats-base/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# install.R already fails the build when a package does not install. This checks
# that packages load -- a missing shared library installs fine and fails here --
# and that the pieces work together.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

for tool in R Rscript pandoc radian git jq tmux curl wget; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not on PATH"
done
radian --version >/dev/null 2>&1 || fail "radian does not run"

tmp=$(mktemp -d)
cat > "$tmp/check.R" <<'R'
pkgs <- c("dplyr", "tidyverse", "readxl", "reshape2", "ggplot2", "latex2exp",
          "rmarkdown", "knitr", "formatR", "caret", "languageserver", "httpgd")
for (p in pkgs) suppressPackageStartupMessages(library(p, character.only = TRUE))

# A graphics device works, not just ggplot2's code.
plot <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
ggsave(file.path(tempdir(), "plot.pdf"), plot, width = 3, height = 2)
stopifnot(file.size(file.path(tempdir(), "plot.pdf")) > 0)

# rmarkdown -> knitr -> pandoc, end to end.
rmd <- file.path(tempdir(), "report.Rmd")
writeLines(c("---", "title: smoke-test", "output: html_document", "---", "", "Answer: `r 6 * 7`"), rmd)
html <- rmarkdown::render(rmd, quiet = TRUE)
stopifnot(any(grepl("Answer: 42", readLines(html, warn = FALSE))))
R
Rscript "$tmp/check.R" >"$tmp/check.log" 2>&1 || { tail -25 "$tmp/check.log" >&2; fail "the R stack does not work"; }

echo "ok: r-stats-base"
