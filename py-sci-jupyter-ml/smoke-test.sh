#!/bin/sh
# Smoke test for py-sci-jupyter-ml. CI runs it inside the freshly built image,
# before anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/py-sci-jupyter-ml/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# Checks this image's layer only; its ancestors' tests cover what it inherits.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"

# Each library runs, not just imports. scikit-optimize in particular has broken
# before against newer numpy and scikit-learn releases while still importing.
python3 - <<'PY' || fail "the ML stack does not run"
import numpy as np
import optuna
from sklearn.linear_model import LinearRegression
from skopt import gp_minimize

model = LinearRegression().fit(np.array([[0.0], [1.0], [2.0]]), np.array([1.0, 3.0, 5.0]))
assert abs(model.coef_[0] - 2.0) < 1e-9, model.coef_

optuna.logging.set_verbosity(optuna.logging.WARNING)
study = optuna.create_study()
study.optimize(lambda trial: trial.suggest_float("x", -1.0, 1.0) ** 2, n_trials=3)
assert len(study.trials) == 3

result = gp_minimize(lambda v: (v[0] - 0.5) ** 2, [(-1.0, 1.0)],
                     n_calls=4, n_initial_points=2, random_state=0)
assert len(result.func_vals) == 4
PY

echo "ok: py-sci-jupyter-ml"
