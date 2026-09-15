#!/bin/sh
# Smoke test for latex-sidecar. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/latex-sidecar/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
#
# It runs as root, against the anonymous volume Docker creates for the
# Dockerfile's VOLUME /opt/TinyTeX -- the same empty volume a consumer's first
# run sees -- and compiles one document per way consumers use TeX.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

# Populate the volume exactly as a consumer's initializeCommand does.
/usr/local/bin/entrypoint.sh >/dev/null || fail "entrypoint.sh failed"
[ -x /opt/TinyTeX/bin/current/latexmk ] || fail "bin/current does not resolve to TinyTeX's binaries"
owner=$(stat -c %u /opt/TinyTeX)
[ "$owner" = 1000 ] || fail "volume owned by UID $owner, expected 1000"

export PATH="/opt/TinyTeX/bin/current:$PATH"

# tlmgr ships in the volume, and every consumer's on-demand install goes through it.
tlmgr --version >/dev/null 2>&1 || fail "tlmgr does not run"

tmp=$(mktemp -d)
cd "$tmp"

# build <latexmk engine flag> <file> <what failed>
build() {
  latexmk "$1" -interaction=nonstopmode -halt-on-error "$2" >"$2.log" 2>&1 \
    || { tail -25 "$2.log" >&2; fail "$3"; }
}

# pdfLaTeX beamer deck with moloch, which also needs pgfopts -- a dependency
# moloch's TeX Live metadata does not declare.
cat > beamer.tex <<'TEX'
\documentclass{beamer}
\usetheme{moloch}
\begin{document}
\begin{frame}{Smoke test}Beamer with the moloch theme.\end{frame}
\begin{frame}[standout]Done\end{frame}
\end{document}
TEX
build -pdf beamer.tex "pdfLaTeX could not build a moloch beamer deck"
[ -s beamer.pdf ] || fail "no PDF from the beamer deck"

# XeLaTeX with fontspec. XeTeX links against fontconfig; a missing library or
# an unbuilt xetex.fmt fails here, not at install time.
cat > xetex.tex <<'TEX'
\documentclass{article}
\usepackage{fontspec}
\begin{document}
fontspec under XeLaTeX.
\end{document}
TEX
build -xelatex xetex.tex "XeLaTeX could not build a fontspec document"
[ -s xetex.pdf ] || fail "no PDF from XeLaTeX"

# py-manim's path: its default template, compiled to DVI and converted with
# dvisvgm --no-fonts, which is exactly what manim's Tex/MathTex runs.
cat > manim.tex <<'TEX'
\documentclass[preview]{standalone}
\usepackage[english]{babel}
\usepackage{amsmath}
\usepackage{amssymb}
\begin{document}
$\displaystyle \int_0^1 x^2\,dx = \frac{1}{3}$
\end{document}
TEX
latex -interaction=nonstopmode -halt-on-error manim.tex >manim.log 2>&1 \
  || { tail -25 manim.log >&2; fail "latex (DVI mode) failed on manim's template"; }
dvisvgm --no-fonts manim.dvi -o manim.svg >/dev/null 2>&1 || fail "dvisvgm could not convert the DVI"
grep -q '<svg' manim.svg || fail "dvisvgm did not produce an SVG"

echo "ok: latex-sidecar"
