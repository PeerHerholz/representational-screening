"""Tests the container recipes this repository ships.

No image is published. The recipes are what users build from, so the
way they go wrong is in a user's hands rather than in a build log here.

``%runscript`` is the one that matters for the documented invocation.
neurodocker's startup script runs ``"$@"`` when it is given arguments
and drops to a shell when it is not, so a ``%runscript`` that names
the entrypoint without forwarding arguments turns
``apptainer run IMAGE repscreen --help`` into an interactive shell with the
command discarded.
"""

import pathlib

import pytest

_ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_the_singularity_runscript_forwards_arguments():
    """``apptainer run IMAGE repscreen ...`` must reach the CLI.

    Docker needs no equivalent: the runtime appends arguments to an
    exec-form ``ENTRYPOINT``.
    """
    definition = _ROOT / "Singularity.def"
    if not definition.is_file():
        pytest.skip("no Singularity.def in this checkout")

    _, _, runscript = definition.read_text().partition("%runscript")
    assert runscript, "Singularity.def declares no %runscript"

    body = runscript.split("%")[0]

    assert '"$@"' in body, (
        "%runscript names the entrypoint without forwarding arguments, "
        "so `apptainer run IMAGE repscreen ...` drops the command: "
        f"{body.strip()!r}"
    )


def test_the_recipes_a_user_builds_from_are_present():
    """The repository ships what it documents building."""
    missing = [
        name
        for name in ("Dockerfile", "Singularity.def", "generate_images.sh")
        if not (_ROOT / name).is_file()
    ]

    assert not missing, f"documented as buildable but absent: {missing}"


def test_no_workflow_publishes_an_image():
    """Publishing made this project the redistributor of everything
    inside an image. The recipes are shared instead, so what goes in is
    the builder's choice."""
    workflows = _ROOT / ".github" / "workflows"
    if not workflows.is_dir():
        pytest.skip("no workflows in this checkout")

    publishing = sorted(
        path.name
        for path in workflows.glob("*.yml")
        if "docker/build-push-action" in path.read_text()
        or "docker push" in path.read_text()
    )

    assert not publishing, f"these push an image: {publishing}"
