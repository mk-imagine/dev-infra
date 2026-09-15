#!/usr/bin/env python3
"""Repository invariants for dev-infra's image builds.

Each check guards a mistake that raises no error on its own: two images sharing
one build cache, a child image that never rebuilds when its parent changes, a
copied devcontainer label that drifted, a comment apt-get would read as package
names. actionlint and shellcheck cannot see any of them.

Run from the repository root. It needs PyYAML, so CI and local runs both use a
throwaway container rather than installing anything on the host:

    docker run --rm -v "$PWD":/repo -w /repo python:3.13-slim \\
      sh -c 'pip install -q "pyyaml>=6,<7" && python .github/scripts/check-repo.py'
"""

import json
import os
import pathlib
import re
import sys

import yaml

REGISTRY = "ghcr.io/mk-imagine/"
WORKFLOWS = pathlib.Path(".github/workflows")

# Built for one architecture in a single job with no cache, deliberately -- see
# the py-torch-cuda table in CLAUDE.md.
SINGLE_ARCH = {"py-torch-cuda"}
RUNNERS = {"linux/amd64": "ubuntu-latest", "linux/arm64": "ubuntu-24.04-arm"}

# py-sci-psy copies py-sci-jupyter-torch-latex's label rather than inheriting
# it, and CLAUDE.md requires the two copies to stay identical.
LABEL_COPIES = [("py-sci-jupyter-torch-latex", "py-sci-psy")]

FROM_OWN = re.compile(r"^FROM\s+" + re.escape(REGISTRY) + r"([\w.-]+):", re.M)
LABEL = re.compile(r"^LABEL devcontainer\.metadata='(.*)'\s*$", re.M)

problems = []


def problem(where, message, line=None):
    problems.append((str(where), line, message))


def load(path):
    data = yaml.safe_load(path.read_text())
    # PyYAML follows YAML 1.1, where a bare `on` key parses as boolean True.
    if True in data:
        data["on"] = data.pop(True)
    return data


def image_of(workflow_name):
    return workflow_name[len("build-"):-len(".yml")]


def check_workflow(image, path, wf):
    text = path.read_text()

    # A workflow must build on changes to its own file, or a broken workflow
    # merges without ever running.
    for event in ("push", "pull_request"):
        paths = ((wf.get("on") or {}).get(event) or {}).get("paths") or []
        for wanted in (f"{image}/**", str(path)):
            if wanted not in paths:
                problem(path, f"on.{event}.paths does not include {wanted!r}")

    env_image = (wf.get("env") or {}).get("IMAGE")
    if env_image != REGISTRY + image:
        problem(path, f"env.IMAGE is {env_image!r}, expected {REGISTRY + image!r}")

    for job_name, job in wf["jobs"].items():
        for step in job.get("steps") or []:
            context = (step.get("with") or {}).get("context")
            if context is not None and context != image:
                problem(path, f"job {job_name!r} builds context {context!r}, not {image!r}")

    if f"$GITHUB_WORKSPACE/{image}/smoke-test.sh" not in text:
        problem(path, f"does not run {image}/smoke-test.sh")

    if image in SINGLE_ARCH:
        return

    # A scope naming another image shares that image's cache: the two evict each
    # other's layers on every build, and nothing reports it.
    scopes = re.findall(r"scope=(\S+)", text)
    if not scopes:
        problem(path, "has no GHA cache scope")
    for scope in scopes:
        if not scope.startswith(image + "-"):
            problem(path, f"cache scope {scope!r} does not start with {image + '-'!r}")

    include = (((wf["jobs"].get("build") or {}).get("strategy") or {}).get("matrix") or {}).get("include") or []
    found = {entry.get("platform"): entry.get("runner") for entry in include}
    if found != RUNNERS:
        problem(path, f"build matrix is {found}, expected {RUNNERS}: each architecture on its own native runner")


def check_cascade(images, workflows, parsed):
    children = {}
    for image, wf in parsed.items():
        job = wf["jobs"].get("trigger-children")
        if not job:
            continue
        # Hanging children off the build job lets a child start before the
        # parent's new tag exists, so it builds on the previous parent.
        if job.get("needs") != "merge":
            problem(workflows[image], f"trigger-children needs {job.get('needs')!r}; it must need 'merge'")
        children[image] = set(job["strategy"]["matrix"]["workflow"])

    for image in images:
        for parent in FROM_OWN.findall(pathlib.Path(image, "Dockerfile").read_text()):
            wanted = f"build-{image}.yml"
            if parent not in images:
                problem(f"{image}/Dockerfile", f"FROM {REGISTRY}{parent}, which is not an image in this repository")
            elif wanted not in children.get(parent, set()):
                problem(workflows.get(parent, f"build-{parent}.yml"),
                        f"trigger-children does not list {wanted}, so {image} (FROM {parent}) never rebuilds when {parent} changes")

    for parent, kids in children.items():
        for kid in sorted(kids):
            child = image_of(kid)
            dockerfile = pathlib.Path(child, "Dockerfile")
            if not dockerfile.is_file() or parent not in FROM_OWN.findall(dockerfile.read_text()):
                problem(workflows[parent], f"trigger-children lists {kid}, but {child} is not built FROM {parent}")


def label(image):
    found = LABEL.findall(pathlib.Path(image, "Dockerfile").read_text())
    if len(found) != 1:
        return None
    try:
        return json.loads(found[0])
    except json.JSONDecodeError:
        return None


def check_label_copies():
    for original, copy in LABEL_COPIES:
        a, b = label(original), label(copy)
        if a is None or b is None:
            problem(f"{copy}/Dockerfile", f"expected one valid JSON devcontainer.metadata label in both {original} and {copy}")
        elif a != b:
            problem(f"{copy}/Dockerfile", f"devcontainer.metadata label differs from {original}'s, which it must copy exactly")


def check_apt_lists():
    for path in sorted(pathlib.Path(".").glob("*/apt-packages.txt")):
        for number, text in enumerate(path.read_text().splitlines(), 1):
            if "#" in text:
                problem(path, "'#' in apt-packages.txt: the Dockerfiles hand this file to apt-get unfiltered, "
                              "so a comment becomes package names", line=number)


def main():
    images = sorted(p.parent.name for p in pathlib.Path(".").glob("*/Dockerfile"))
    workflows = {image_of(p.name): p for p in sorted(WORKFLOWS.glob("build-*.yml"))}

    for image in images:
        if image not in workflows:
            problem(f"{image}/Dockerfile", f"no .github/workflows/build-{image}.yml builds this image")
        if not pathlib.Path(image, "smoke-test.sh").is_file():
            problem(f"{image}/Dockerfile", "no smoke-test.sh beside it; every image is run before it is published")
    for image, path in workflows.items():
        if image not in images:
            problem(path, f"there is no {image}/Dockerfile for this workflow to build")

    parsed = {image: load(path) for image, path in workflows.items()}
    for image, wf in parsed.items():
        if image in images:
            check_workflow(image, workflows[image], wf)
    check_cascade(images, workflows, parsed)
    check_label_copies()
    check_apt_lists()

    in_actions = os.environ.get("GITHUB_ACTIONS") == "true"
    for where, line, message in problems:
        if in_actions:
            location = f"file={where}" + (f",line={line}" if line else "")
            print(f"::error {location}::{message}")
        else:
            print(f"FAIL {where}{':' + str(line) if line else ''}: {message}")
    if problems:
        print(f"{len(problems)} problem(s)")
        return 1
    print(f"ok: {len(images)} images, {len(workflows)} build workflows, cascade and label copies consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
