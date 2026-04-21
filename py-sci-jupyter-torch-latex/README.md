# py-sci-jupyter-torch-latex

Thin derived image of `py-sci-jupyter-torch` that bakes LaTeX-specific
devcontainer configuration into image metadata. Works with the
`latex-sidecar` volume to give consuming repos a fully-wired LaTeX
editing environment with zero duplicated config.

## What it provides

Via a `devcontainer.metadata` LABEL (inherited by any `devcontainer.json`
that references this image):

- **Mount**: `latex-shared` named volume at `/opt/TinyTeX`
- **PATH**: `/opt/TinyTeX/bin/current` prepended
- **VS Code extensions**: `James-Yu.latex-workshop`, `tecosaur.latex-utilities`
- **LaTeX Workshop settings**: build via `latexmk`, output to `<dir>/build`,
  auto-build on save, PDF in tab, conservative auto-clean.

## Build & publish

```bash
docker build -t ghcr.io/mk-imagine/py-sci-jupyter-torch-latex:latest .
docker push ghcr.io/mk-imagine/py-sci-jupyter-torch-latex:latest
```

## Use in a devcontainer

```jsonc
{
    "name": "my-latex-repo",
    "image": "ghcr.io/mk-imagine/py-sci-jupyter-torch-latex:latest",
    "initializeCommand": "docker pull ghcr.io/mk-imagine/latex-sidecar:latest && docker run --rm -v latex-shared:/opt/TinyTeX ghcr.io/mk-imagine/latex-sidecar:latest",
    "remoteUser": "devuser"
}
```

The `mounts`, `remoteEnv`, and `customizations` keys are inherited from
the image — repos only need to declare the sidecar `initializeCommand`
(host-side, can't be baked in) plus whatever is project-specific.
