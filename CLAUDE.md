# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Docker images published to `ghcr.io/mk-imagine/` and built via GitHub Actions. All images are multi-arch (linux/amd64 + linux/arm64) except `py-torch-cuda`, which is amd64-only. Builds are triggered automatically on push to `main` when files under the relevant image directory change, and every pull request that touches an image builds and smoke-tests it without publishing anything.

There is no application code. "Building" means building a Docker image; "testing" means running the built image and checking that the thing it exists to do actually works — which is what each image's `smoke-test.sh` does, and CI runs it before anything is published. Mistakes that no build would report are the job of the **Checks** workflow (see *CI/CD*).

## Image hierarchy

```
latex-sidecar          ← standalone TinyTeX init container (populates latex-shared volume)
latex-base             ← standalone minimal Debian runtime that CONSUMES latex-shared

plantuml               ← standalone PlantUML CLI (JRE + Graphviz + pinned plantuml.jar)

py-torch-cuda          ← standalone GPU/PyTorch image (CUDA wheels, amd64-only)

r-stats-base           ← rocker/r-ver:4.5.2, pandoc, radian, core R packages
  └── r-stats-psy      ← base + psychology/stats R packages

py-sci-base            ← python:3.13-slim + numpy, pandas, openpyxl
  ├── py-sci-psy       ← plotly + kaleido + chromium; LaTeX metadata; no Jupyter
  └── py-sci-jupyter   ← base + Jupyter infrastructure
        ├── py-manim   ← manim + cairo/pango/ffmpeg; LaTeX via latex-shared volume
        └── py-sci-jupyter-ml    ← jupyter + scikit-learn, optuna
              └── py-sci-jupyter-torch  ← ml + torch stack (CPU wheels)
                    └── py-sci-jupyter-torch-latex  ← LaTeX devcontainer metadata (no packages)
                          └── py-dsml   ← nbclient/nbformat, matplotlib/seaborn, dill, pytest, SVG rendering
```

`latex-sidecar` and `latex-base` are a pair, not a parent/child: the sidecar
*populates* the `latex-shared` volume, `latex-base` is the smallest image that
*runs* LaTeX from it. Neither has a `FROM` relationship to the other or to
anything else in the repo.

`py-sci-psy` hangs off `py-sci-base` rather than the Jupyter chain because its
consumer is script-driven: the Jupyter layer is the part it does not want, not
the torch layer. It copies the LaTeX `devcontainer.metadata` LABEL from
`py-sci-jupyter-torch-latex` rather than inheriting it, since that image sits on
the other branch of the tree — **keep the two copies in sync.** The Checks workflow fails a pull request if they differ.

`py-torch-cuda` is a separate root rather than a child of `py-sci-base`, and
**it is the one image in this repo that breaks the shared conventions.** Three
deviations, all deliberate and all documented in its Dockerfile and workflow:

| Convention | `py-torch-cuda` | Why |
|---|---|---|
| One runner per architecture, merged into a multi-arch manifest | **amd64 only, single job** | PyTorch publishes CUDA wheels for x86_64 alone. With one architecture there is nothing to merge, so the build job tags and pushes directly — no `merge` job and no architecture check. |
| `cache-from`/`cache-to: type=gha` | **no GHA cache** | The image is 8.07GB against GitHub's 10GB per-repo cache cap. In practice this repo's caches are always empty anyway — entries expire after 7 days unused and builds here are ~monthly — so the cache would never be warm, and writing 8GB of it costs upload time every build. |
| `--extra-index-url` (as in `py-sci-jupyter-torch`) | **`--index-url`** | The "extra" form leaves PyPI in the resolver path, which is how a GPU image silently gets CPU-only torch. Replacing the index makes a bad index fail loudly. |

Do not "fix" these to match the other images.

> **Ampere check when bumping the CUDA index.** CUDA 13 already dropped every
> architecture below Turing. After changing the `cu1xx` index in
> `requirements.txt`, confirm the target card's arch is still compiled in rather
> than assuming — `torch.cuda.get_arch_list()` must contain it (`sm_86` for the
> RTX 3070), or Ampere silently falls back to PTX JIT.

Child images are rebuilt automatically via `workflow_dispatch` cascade from the parent workflow's `trigger-children` job.

The Checks workflow fails any pull request that leaves a child out of its
parent's `trigger-children` matrix, so the cascade cannot quietly break.

## Building and verifying locally

Every child Dockerfile pins `FROM ghcr.io/mk-imagine/<parent>:latest` — the
**published** parent, not your working tree. A plain `docker build` of a child
therefore silently tests your change against the last image CI published, not
against the parent you just edited.

To exercise a chain change locally, build each ancestor under the tag its child
expects, bottom-up:

```bash
docker build -t ghcr.io/mk-imagine/py-sci-base:latest      py-sci-base/
docker build -t ghcr.io/mk-imagine/py-sci-jupyter:latest   py-sci-jupyter/
docker build -t py-dsml:local                              py-dsml/
```

Local builds are single-arch (host only). CI builds each arch natively on its own
runner, so an arm64-only local pass does not prove the amd64 build. To check the
other arch before pushing:

```bash
docker buildx build --platform linux/amd64 -t py-dsml:amd64 py-dsml/   # --load is single-arch only
```

Every image directory has a `smoke-test.sh` that checks what the image exists to
do rather than that files exist — the sidecar compiles a moloch beamer deck,
`py-sci-psy` exports a figure through chromium, `py-dsml` executes a notebook.
CI runs it inside the freshly built image before anything is published. Run it
the same way against a local build:

```bash
img=py-dsml   # any image directory
docker build -t "${img}:local" "$img/"
docker run --rm --entrypoint /bin/sh \
  -e DEVCONTAINER_METADATA="$(docker image inspect "${img}:local" --format '{{json .Config.Labels}}' | jq -r '.["devcontainer.metadata"] // ""')" \
  -v "$PWD/$img/smoke-test.sh:/smoke-test.sh:ro" \
  "${img}:local" /smoke-test.sh
```

Write `${img}:local`, not `$img:local`: zsh reads `:l` as its lowercase modifier
and silently turns the reference into `py-dsmlocal`.

A smoke test covers its own image's layer, not what it inherits; each ancestor's
test covers that. Images that carry a `devcontainer.metadata` label check it,
which is why the label is passed in — it cannot be read from inside a container.
`py-torch-cuda` checks that torch is a CUDA build, but a runner has no GPU, so
the Ampere check above stays manual.

## Adding packages

**R images**: Add the package name (with inline comment) to `r-packages.txt` in the relevant image directory. The shared `install.R` script strips comments, skips blanks, and installs only missing packages via CRAN, then re-checks and `stop()`s on any that failed — so a bad package name fails the build rather than shipping a broken image.

**Python images**: Add to `requirements.txt` in the relevant image directory. `#` comments are supported (pip strips them); the existing files use them for per-package rationale.

**LaTeX (latex-sidecar)**: Add to `latex-sidecar/latex_packages.txt`. Comments, blank lines, and `.universal-darwin` entries are stripped at build time by the Dockerfile before passing to `tlmgr install`.

> Note: `tlmgr` lives inside TinyTeX, so it ships in the `latex-shared` volume
> rather than in any image. The sidecar runs `tlmgr update --self --all` in the
> same layer as the package install — keep them together, or a cached
> self-update will let a stale `tlmgr` fail every install. A long-lived volume
> can drift again; recover in place with `tlmgr update --self`.

**System deps**: Add to `apt-packages.txt` in the relevant image directory, one
package per line.

> Unlike `r-packages.txt` and `latex_packages.txt`, **`apt-packages.txt` does not
> support comments**. The Dockerfiles pass it straight through as
> `$(cat /tmp/apt-packages.txt)` with no stripping, so a `#` and its trailing text
> would be handed to `apt-get install` as package names and fail the build. Put
> per-package rationale in the Dockerfile instead. The Checks workflow rejects a
> `#` in any `apt-packages.txt`.

> Two images opt out of the `apt-packages.txt` convention and inline their apt
> list in the Dockerfile: `latex-sidecar` and `latex-base`. Edit the `RUN
> apt-get install` block there; do not add an `apt-packages.txt` to those
> directories without also changing the Dockerfile to read it.

**Pinned versions** live in Dockerfile `ARG`/`FROM` lines, not in any list file:
`r-stats-base` (`rocker/r-ver:4.5.2`, `ARG PANDOC_VERSION`), `py-sci-base`
(`python:3.13-slim`), `plantuml` (`ARG PLANTUML_VERSION`). Bumping any of these
is a base-image change — expect the whole downstream chain to rebuild.

**After any package or image change, update `README.md`.** It carries the
per-image dependency tables *including inherited packages*, so adding one line to
a base image's `requirements.txt` means editing every descendant's "Inherited
from" list. Nothing generates or verifies those tables — they drift silently.

## Adding a new image

### R child image

1. Create `r-stats-<name>/` with `Dockerfile`, `r-packages.txt`, and `install.R`
2. `FROM ghcr.io/mk-imagine/r-stats-base:latest` in the Dockerfile
3. Copy `install.R` verbatim from an existing R child image (it's identical across all R images)
4. Add `.github/workflows/build-r-stats-<name>.yml` (copy an existing child workflow)
5. Add `build-r-stats-<name>.yml` to the `trigger-children` matrix in `build-r-stats-base.yml`
6. Add `r-stats-<name>/smoke-test.sh`, checking what the new image adds

### Python child image

1. Create `py-sci-<name>/` with `Dockerfile` and `requirements.txt`
2. `FROM` the appropriate parent image
3. Add `.github/workflows/build-py-sci-<name>.yml`
4. Add the workflow filename to the `trigger-children` matrix in the parent's workflow
5. Add `py-sci-<name>/smoke-test.sh`, checking what the new image adds

Step 4/5 is the one that gets forgotten — a new image builds fine on its own push
and then never rebuilds when its parent changes. The Checks workflow now fails any
pull request that misses it.

## CI/CD

Workflows live in `.github/workflows/`, one per image. All are structurally identical except `build-py-torch-cuda.yml` (see the table above). Each triggers on a `push` to `main` or a `pull_request` that touches its image directory or its own workflow file, plus `workflow_dispatch`, and runs:

- **`build`** — a matrix with one job per architecture, each on a runner *of* that architecture (`ubuntu-latest` for amd64, `ubuntu-24.04-arm` for arm64). There is no QEMU anywhere in this repo. Each leg builds into the runner's Docker and runs `<image>/smoke-test.sh` inside it; only if that passes does it push the image **untagged, by digest** and upload the digest as an artifact. The push rebuilds from the builder's cache, so the pushed layers are the tested ones.
- **`merge`** — binds both digests into one manifest list, applies `latest` and the short SHA, then fails the run unless `linux/amd64` and `linux/arm64` are both present in the published manifest.
- **`trigger-children`** (only where an image has children) — `needs: merge`, so a child starts only after the parent's new tag exists. Hanging it off `build` instead would let the child pull the previous parent.

Tags therefore appear only once every leg has built and passed its smoke test; a failed leg leaves `latest` where it was.

**Pull requests publish nothing.** Login, every push step, `merge` and `trigger-children` are skipped, so a PR run builds and smoke-tests both architectures and stops. PR runs read `main`'s layer cache but never write to it: a PR's cache entries are invisible to `main` yet count against the same 10GB cap. A newer push to a PR cancels its run in progress; runs on `main` queue instead, because cancelling one could stop it between a leg's push and the tag.

A child's PR build pulls the **published** parent, not a parent changed in the same PR (see *Building and verifying locally*), so a PR that changes both can fail the child's build until the parent is on `main`.

Because each workflow file is in its own `paths:`, a PR or merge that edits many workflows builds every one of those images, and on `main` parents also dispatch their children. The dispatched run queues behind the push-triggered one and finishes last, so each child's final `latest` is built on its new parent.

> **Untagged registry versions are not debris.** Because the legs push by digest,
> every build leaves untagged versions on the package page — they are the
> per-architecture manifests that `latest` points at. **Never run a generic
> "delete untagged versions" cleanup**: it deletes the images behind every
> multi-arch tag.

Layer caching is GitHub Actions cache (`type=gha`, `mode=max`), scoped per image *and* per platform so the two legs do not evict each other.

When copying a workflow for a new image, these are what must change:

| Where | Value |
|---|---|
| `name:` | `Build <image>` |
| `on.push.paths` **and** `on.pull_request.paths` | `"<image>/**"` and `".github/workflows/build-<image>.yml"` |
| `env.IMAGE` | `ghcr.io/mk-imagine/<image>` |
| `build` → `context:` (both build steps) | `<image>` |
| `build` → `Smoke test` | `$GITHUB_WORKSPACE/<image>/smoke-test.sh` |
| `build` → `cache-from` **and** `cache-to` | `scope=<image>-…` (inside a `format()` expression in `cache-to`) |
| `trigger-children` | present only if the image has children; lists their workflow files |

**The cache scope is the one that fails silently.** Leave another image's name in `scope=` and the two images share one cache and evict each other's layers on every build — no error, just builds that never get faster. The Checks workflow rejects it.

Manual rebuild: `gh workflow run build-<name>.yml`, or the GitHub Actions UI "Run workflow" button.

### Checks

`.github/workflows/checks.yml` runs on every pull request and every push to `main`, with no path filter, in under a minute:

| Step | Catches |
|---|---|
| `actionlint` | workflow syntax and expression errors, and shellcheck findings inside `run:` blocks |
| `shellcheck` | problems in every tracked `*.sh` |
| `.github/scripts/check-repo.py` | a cache entry with no scope, or a scope naming another image or missing its platform; any cache on `py-torch-cuda`; a build matrix missing an architecture or its native runner; a child missing from its parent's `trigger-children`, or a listed child not built `FROM` that parent; `trigger-children` needing `build` instead of `merge`; a workflow whose `paths:` omit its own directory or file, or that runs another image's smoke test; an image without `smoke-test.sh`; the two copies of the LaTeX `devcontainer.metadata` label drifting apart; a `#` in any `apt-packages.txt` |

Having no path filter is what lets it be a **required status check**. The per-image build workflows cannot be: on a pull request outside their paths they never start, and a required check that never starts blocks the PR forever. Its verdict depends only on the repository, but its tools are fetched at run time — pinned images from Docker Hub, PyYAML from PyPI — so a registry outage fails the run outright rather than changing its verdict; rerun it.

`.github/workflows/check-tex-packages.yml` confirms every name in `latex-sidecar/latex_packages.txt` exists in the TeX Live repository the sidecar installs from, by reading that repository's package database directly — `tlmgr info` answers from a local copy and can report a removed package as present. It runs when the list changes and weekly, because TeX Live changes with no commit here: `l3backend` was folded into `l3kernel` between two sidecar builds. It stays out of Checks so a mirror outage cannot block unrelated pull requests. GitHub emails a scheduled run's failure to whoever last edited its `cron:` line.

The same checks, locally from the repository root, with nothing installed on the host:

```bash
docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:1.7.12
git ls-files -z '*.sh' | xargs -0 docker run --rm -v "$PWD":/mnt -w /mnt koalaman/shellcheck:v0.11.0
docker run --rm -v "$PWD":/repo -w /repo python:3.13-slim \
  sh -c 'pip install -q --root-user-action=ignore "pyyaml>=6,<7" && python .github/scripts/check-repo.py'
sh .github/scripts/check-tex-packages.sh
```

## LaTeX sidecar design

TinyTeX is baked into the image at `/opt/staging/TinyTeX` during build. The entrypoint copies it to the mounted volume (`/opt/TinyTeX`) on first run, then creates a `bin/current` symlink pointing at the arch-specific binary dir, and `chown`s the volume to UID 1000. The copy is idempotent — skipped if `/opt/TinyTeX/bin` already exists, which also means **a sidecar rebuild does not update an already-populated volume**; delete the volume and re-run to pick up new packages.

Consuming devcontainers must mount `latex-shared` at `/opt/TinyTeX` and prepend `/opt/TinyTeX/bin/current` to `PATH`. Do not call `tinytex::install_tinytex()` or install system `texlive` in consuming images.

## Devcontainer metadata

`py-sci-jupyter-torch-latex` and `py-manim` carry a `devcontainer.metadata`
LABEL so consuming `devcontainer.json` files inherit the volume mount, `PATH`,
and VS Code extensions without duplicating them per-repo. Those images also set
`ENV PATH` directly, because the LABEL only applies under a devcontainer — a
plain `docker run` would otherwise not find the TinyTeX binaries.

The LaTeX `remoteEnv` interpolates `${containerEnv:PATH}`, so it composes with a
descendant's `ENV PATH` rather than overwriting it (see `py-dsml`, which prepends
`~/.local/bin` this way).

### New devcontainer checklist

1. Add a `postCreateCommand` that curls the global gitignore from the gist and configures git to use it:
   ```
   "postCreateCommand": "mkdir -p ~/.config/git && curl -fsSL https://gist.githubusercontent.com/mk-imagine/cf71d040d468af090a7fe65568470a09/raw/ignore -o ~/.config/git/ignore && git config --global core.excludesfile ~/.config/git/ignore"
   ```
2. If the project uses LaTeX, add the `latex-shared` volume mount and `PATH` entry (see "LaTeX sidecar design" above).
3. Set `"remoteUser": "devuser"`.

## User inside containers

All images create `devuser` with UID 1000, matching the ownership the sidecar
sets on `latex-shared`. R package installs run as `devuser` (site-library is
chowned to it). Python installs run as root (pip into system site-packages),
then the image switches to `devuser` as the default user — so a `pip install`
inside a *running* container falls back to the user scheme and lands console
scripts in `~/.local/bin`.

## Repo notes

`.history/` directories are local VS Code Local History artifacts, ignored via
the user's global gitignore rather than this repo's. They are not source — do not
read them for current state or add them to the tree.

`.gitignore` here exists solely to negate a global `CLAUDE.md` ignore rule so
this file stays in version control.
