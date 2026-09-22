#!/bin/sh
# Every package named in latex-sidecar/latex_packages.txt exists in the TeX Live
# repository the sidecar installs from.
#
# TeX Live changes with no commit here. l3backend was folded into l3kernel
# upstream between two sidecar builds, and the next build failed with "package
# l3backend not present in repository". This finds that in seconds, without a
# build, by reading the repository's package database directly -- not through
# `tlmgr info`, which answers from a possibly stale local copy.
#
#   sh .github/scripts/check-tex-packages.sh [package-list]
set -eu
export LC_ALL=C

list=${1:-latex-sidecar/latex_packages.txt}
tlnet=${TLNET:-https://tlnet.yihui.org}

fail() {
  if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::error file=$list::$*"; else echo "FAIL: $*"; fi
}

# A pipeline's status is its last command's, so sed failing on a missing list
# would not stop the script: it would check nothing and report success.
[ -f "$list" ] && [ -r "$list" ] || { fail "$list is not a readable file"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 3 "$tlnet/tlpkg/texlive.tlpdb.xz" -o "$tmp/tlpdb.xz"
# Decompress as its own command, not at the head of a pipeline, so a corrupt or
# truncated download stops the script instead of yielding a partial list.
xz -dc "$tmp/tlpdb.xz" > "$tmp/tlpdb"
sed -n 's/^name //p' "$tmp/tlpdb" | sort -u > "$tmp/available"
[ -s "$tmp/available" ] || { fail "read no package names from $tlnet"; exit 1; }

# The same filtering latex-sidecar/Dockerfile applies before `xargs tlmgr install`.
sed 's/#.*//' "$list" | grep -v -E '(\.universal-darwin|^[[:space:]]*$)' \
  | awk '{ for (i = 1; i <= NF; i++) print $i }' | sort -u > "$tmp/wanted"
[ -s "$tmp/wanted" ] || { fail "read no package names from $list"; exit 1; }

missing=$(comm -23 "$tmp/wanted" "$tmp/available")
if [ -n "$missing" ]; then
  for pkg in $missing; do
    fail "$pkg is not in the TeX Live repository at $tlnet"
  done
  exit 1
fi
echo "ok: all $(wc -l < "$tmp/wanted" | tr -d ' ') packages in $list exist in $tlnet"
