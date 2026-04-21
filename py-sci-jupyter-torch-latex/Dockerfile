# Derived image: adds LaTeX-specific devcontainer metadata on top of the base
# Python / Jupyter / Torch image. No additional packages — LaTeX binaries come
# from the `latex-sidecar` image via the `latex-shared` Docker named volume.
#
# The devcontainer.metadata LABEL lets every consuming devcontainer.json
# inherit the sidecar mount, PATH extension, and VS Code extensions/settings
# without duplicating them per-repo.
# Spec: https://containers.dev/implementors/spec/#image-metadata

FROM ghcr.io/mk-imagine/py-sci-jupyter-torch:latest

LABEL devcontainer.metadata='[{"mounts":["source=latex-shared,target=/opt/TinyTeX,type=volume"],"remoteEnv":{"PATH":"/opt/TinyTeX/bin/current:${containerEnv:PATH}"},"customizations":{"vscode":{"extensions":["James-Yu.latex-workshop","tecosaur.latex-utilities"],"settings":{"latex-workshop.latex.outDir":"%DIR%/build","latex-workshop.latex.autoBuild.run":"onFileChange","latex-workshop.latex.recipe.default":"latexmk (latexmk)","latex-workshop.view.pdf.viewer":"tab","latex-workshop.latex.clean.subfolder.enabled":true,"latex-workshop.latex.autoClean.run":"onFailed","latex-workshop.message.update.show":false}}}}]'
