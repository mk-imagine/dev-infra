#!/bin/sh
# Smoke test for r-stats-psy. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/r-stats-psy/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; r-stats-base's test covers what it inherits.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

tmp=$(mktemp -d)
cat > "$tmp/check.R" <<'R'
pkgs <- c("psych", "emmeans", "car", "effectsize", "heplots", "ppcor",
          "lm.beta", "agricolae", "mvoutlier", "interactions")
for (p in pkgs) suppressPackageStartupMessages(library(p, character.only = TRUE))

# The core workflow runs: a model, its marginal means, a type-II ANOVA, and a
# descriptive summary that agrees with base R.
fit <- lm(mpg ~ factor(cyl), data = mtcars)
stopifnot(nrow(as.data.frame(emmeans(fit, "cyl"))) == 3)
stopifnot("factor(cyl)" %in% rownames(car::Anova(fit)))
stopifnot(abs(psych::describe(mtcars$mpg)$mean - mean(mtcars$mpg)) < 1e-9)
R
Rscript "$tmp/check.R" >"$tmp/check.log" 2>&1 || { tail -25 "$tmp/check.log" >&2; fail "the psychology stats stack does not work"; }

echo "ok: r-stats-psy"
