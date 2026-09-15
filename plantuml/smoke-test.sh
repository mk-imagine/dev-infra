#!/bin/sh
# Smoke test for plantuml. CI runs it inside the freshly built image, before
# anything is published:
#
#   docker run --rm --entrypoint /bin/sh \
#     -v "$PWD/plantuml/smoke-test.sh:/smoke-test.sh:ro" <image> /smoke-test.sh
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" = 1000 ] || fail "running as UID $(id -u), expected 1000 (devuser)"
command -v plantuml >/dev/null 2>&1 || fail "plantuml is not on PATH"
plantuml -version 2>&1 | grep -q 'PlantUML version' || fail "plantuml -version reported no version"

# Class and component diagrams are laid out by Graphviz; plantuml's own check
# confirms it can find and run dot.
plantuml -testdot 2>&1 | grep -q 'Installation seems OK' || fail "plantuml cannot run Graphviz dot"

tmp=$(mktemp -d)
cat > "$tmp/sequence.puml" <<'UML'
@startuml
Alice -> Bob: smoke test
@enduml
UML
cat > "$tmp/class.puml" <<'UML'
@startuml
class Workflow
class Image
Workflow --> Image : builds
@enduml
UML
plantuml -tsvg "$tmp/sequence.puml" "$tmp/class.puml" >/dev/null 2>&1 || fail "plantuml failed to render"
grep -q 'smoke test' "$tmp/sequence.svg" || fail "sequence diagram SVG is missing its text"
grep -q 'Workflow' "$tmp/class.svg" || fail "class diagram SVG (laid out by Graphviz) is missing its text"

echo "ok: plantuml"
