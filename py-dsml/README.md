# py-dsml

Data-science / curriculum-authoring image. Parent: `py-sci-jupyter-torch-latex`.

Completes the notebook-authoring and headless-execution stack that the
`py-sci-*` chain does not carry, so a consuming repo can generate, execute,
and verify notebooks without installing anything at container start.

## What it adds

| Package | Why |
|---|---|
| `nbclient`, `nbformat` | Execute notebooks programmatically — the engine behind headless "run every notebook end-to-end" gates. Without these, no notebook can be executed outside the Jupyter UI. |
| `matplotlib`, `seaborn` | Plotting. `seaborn` also pulls the statistical-plot layer used for distribution and correlation figures. |
| `dill` | Serialization beyond `pickle` — lambdas, closures, and fitted-model bundles. |
| `pytest` | Verification cells and build-script tests. |

**Inherited from `py-sci-base`:** git, curl, build-essential, poppler-utils, numpy, pandas, openpyxl
**Inherited from `py-sci-jupyter`:** ipython, ipywidgets, ipykernel
**Inherited from `py-sci-jupyter-ml`:** scikit-learn, scikit-optimize, optuna
**Inherited from `py-sci-jupyter-torch`:** torch, torchvision, torchaudio (CPU wheels)
**Inherited from `py-sci-jupyter-torch-latex`:** the `devcontainer.metadata` LABEL — `latex-shared` volume mount, `/opt/TinyTeX/bin/current` on `PATH`, LaTeX Workshop extensions/settings

## Deliberately NOT included

- **Project-local packages.** Anything installed editable from a consuming
  repo (e.g. a repo's own `nbtools`-style helper package) stays in that repo
  and is installed via `pip install -e` at container start. Baking it here
  would freeze a project's internal tooling into a shared image.
- **Course- or project-specific Jupyter kernelspecs.** This image ships the
  stock `python3` kernel only. A consuming repo that wants a named kernel
  should create the kernelspec in its own `postCreateCommand` — or, for
  headless execution, pass the kernel explicitly (e.g. `--kernel python3`)
  rather than depending on a named kernel existing in the image.

## Build & publish

```bash
docker build -t ghcr.io/mk-imagine/py-dsml:latest .
docker push ghcr.io/mk-imagine/py-dsml:latest
```

CI builds and pushes on any change under `py-dsml/`, and on
`workflow_dispatch` cascade from the parent's `trigger-children` job.

## Use in a devcontainer

```jsonc
{
    "name": "my-curriculum-repo",
    "image": "ghcr.io/mk-imagine/py-dsml:latest",
    "initializeCommand": "docker pull ghcr.io/mk-imagine/latex-sidecar:latest && docker run --rm -v latex-shared:/opt/TinyTeX ghcr.io/mk-imagine/latex-sidecar:latest",
    "postCreateCommand": "mkdir -p ~/.config/git && { curl -fsSL https://gist.githubusercontent.com/mk-imagine/cf71d040d468af090a7fe65568470a09/raw/ignore -o ~/.config/git/ignore || echo 'warn: global gitignore fetch failed; continuing without it'; } && git config --global core.excludesfile ~/.config/git/ignore",
    "remoteUser": "devuser"
}
```

The `mounts`, `remoteEnv`, and `customizations` keys are inherited from the
LaTeX parent — drop the `initializeCommand` if the repo has no LaTeX output.

### A note on the global-gitignore fetch

The `curl` above is wrapped so a fetch failure **warns instead of aborting
container creation**. In the original `&&`-chained form, an unreachable gist
took the whole `postCreateCommand` down with it and the container came up
misconfigured; git tolerates an `excludesfile` that does not exist, so
continuing is strictly better than failing.

The URL is a **mutable** gist ref (`/raw/ignore` always serves the latest
revision). That is deliberate — it is how the ignore rules propagate to every
consuming repo without touching each one — but it does mean the fetched
content can change without review. A repo that needs reproducibility over
propagation can pin the immutable revision instead:

```
https://gist.githubusercontent.com/mk-imagine/cf71d040d468af090a7fe65568470a09/raw/3841eeada1c2164f6ae33d54f1d6f8c7dd298dff/ignore
```

Pinning is a per-repo call, not a default: it trades away the central-update
property the shared gist exists to provide. The unpinned form remains the
repo-wide convention (see the "New devcontainer checklist"), so changing the
default belongs in that checklist rather than in one image's README.
