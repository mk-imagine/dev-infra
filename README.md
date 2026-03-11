# dev-infra

Shared development infrastructure for local dev containers across all projects.

The goal is a single installation of each major tool that any devcontainer — regardless of base image (R, Python, Manim, Jupyter) — can mount and use without maintaining its own copy.

## Services

### `latex-sidecar/` — Shared TinyTeX Volume

LaTeX installations (TinyTeX/TeX Live) are 500MB+. Duplicating them across every project's Docker image wastes disk space, slows builds, and creates divergent package states. This sidecar solves that with a single named volume shared across all containers.

#### Architecture

An init container (`latex-init`) installs TinyTeX into a Docker named volume (`latex-shared`) once. All devcontainers mount the volume read-write at `/opt/TinyTeX`.

```
                    Docker Named Volume: latex-shared
                         mounted at /opt/TinyTeX
                ┌──────────┬──────────┬──────────┐
           ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌───▼──────┐
           │ psy772 │ │ psy771 │ │  Manim │ │ Jupyter  │
           │   R    │ │   R    │ │ Python │ │  Python  │
           └────────┘ └────────┘ └────────┘ └──────────┘
```

#### One-time setup

```bash
docker build -t latex-init ./latex-sidecar
docker run --rm -v latex-shared:/opt/TinyTeX latex-init
```

The init container is idempotent — safe to re-run if the volume is already populated.

#### Volume lifecycle

| Operation | Command |
|-----------|---------|
| First-time setup | `docker run --rm -v latex-shared:/opt/TinyTeX latex-init` |
| Repopulate after deletion | Same as above |
| Upgrade TinyTeX | Rebuild `latex-init`, delete volume, repopulate |
| Install a package | `tlmgr install <pkg>` from any running container |
| List installed packages | `tlmgr list --only-installed` |
| Inspect volume | `docker volume inspect latex-shared` |

#### Interface contract for consuming devcontainers

All consuming containers must conform to the following.

**1. UID 1000 user in Dockerfile**
```dockerfile
RUN useradd -m -u 1000 devuser
```

**2. Volume mount in `devcontainer.json`**
```json
"mounts": [
    "source=latex-shared,target=/opt/TinyTeX,type=volume"
]
```

**3. PATH in `devcontainer.json`**
```json
"remoteEnv": {
    "PATH": "/opt/TinyTeX/bin/current:${containerEnv:PATH}"
}
```

The `current` symlink is architecture-agnostic — it resolves to the correct binary directory for the host architecture (`aarch64-linux` on Apple Silicon, `x86_64-linux` on Intel/AMD).

**4. No local LaTeX installation** — do not call `tinytex::install_tinytex()` or `apt install texlive`. Remove any such calls from `postCreateCommand`.

#### New project checklist

- [ ] `latex-shared` volume exists and is populated (`docker volume ls | grep latex-shared`)
- [ ] `useradd -m -u 1000 devuser` in Dockerfile
- [ ] Volume mount added to `devcontainer.json`
- [ ] PATH entry added to `devcontainer.json`
- [ ] No `tinytex::install_tinytex()` or `apt install texlive` calls
- [ ] Verify: open a terminal in the container and run `pdflatex --version`
