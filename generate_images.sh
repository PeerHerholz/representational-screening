#!/bin/bash

# Script: generate_images.sh
# Purpose: Generate the Docker and Apptainer/Singularity container
#          definitions for repscreen, and optionally build the
#          Apptainer image.
# Description: neurodocker is run through uvx, so generating the
#              definitions needs no container runtime at all.  The
#              Apptainer image builds locally with --fakeroot, which
#              pulls the base image over its own OCI client rather
#              than through a Docker daemon.  The Docker image is
#              built and published by the container workflow in CI.

# Exit immediately if any command fails
set -e

# neurodocker is pinned so that regenerating the committed
# definitions produces the same output rather than drifting with
# whatever version happens to be current.
NEURODOCKER_VERSION=2.1.2

# Function to generate the Dockerfile with neurodocker
generate_docker() {
  uvx --from "neurodocker==${NEURODOCKER_VERSION}" neurodocker \
             generate docker \
             --base-image python:3.11-slim-bookworm \
             --pkg-manager apt \
             --install git gcc g++ curl build-essential nano \
             --copy . /home/repscreen \
             --run "curl -LsSf https://astral.sh/uv/install.sh | sh && /root/.local/bin/uv venv /opt/repscreen" \
             --env VIRTUAL_ENV="/opt/repscreen" \
             --env PATH="/opt/repscreen/bin:/root/.local/bin:\$PATH" \
             --env SETUPTOOLS_SCM_PRETEND_VERSION_FOR_REPSCREEN=0.1.0+docker \
             --run "cd /home/repscreen && uv pip install -e ." \
             --env IS_DOCKER=1 \
             --user repscreen \
             --user root \
             --run 'chown -R repscreen /home/repscreen' \
             --user repscreen \
             --workdir '/home/repscreen'
}

# Function to generate the Apptainer/Singularity definition file
generate_singularity() {
  uvx --from "neurodocker==${NEURODOCKER_VERSION}" neurodocker \
             generate singularity \
             --base-image python:3.11-slim-bookworm \
             --pkg-manager apt \
             --install git gcc g++ curl build-essential nano \
             --copy . /home/repscreen \
             --run "curl -LsSf https://astral.sh/uv/install.sh | sh && /root/.local/bin/uv venv /opt/repscreen" \
             --env VIRTUAL_ENV="/opt/repscreen" \
             --env PATH="/opt/repscreen/bin:/root/.local/bin:\$PATH" \
             --env SETUPTOOLS_SCM_PRETEND_VERSION_FOR_REPSCREEN=0.1.0+singularity \
             --run "cd /home/repscreen && uv pip install -e ." \
             --env IS_SINGULARITY=1 \
             --user repscreen \
             --user root \
             --run 'chown -R repscreen /home/repscreen' \
             --user repscreen \
             --workdir '/home/repscreen'
}

# Function to build the Apptainer image from the definition file
#
# --fakeroot gives the build the appearance of root without needing
# it, which requires an /etc/subuid and /etc/subgid entry for the
# invoking user.  "apptainer build --help" documents the alternatives
# if that entry is missing.
build_apptainer() {
    echo "  -> Starting Apptainer image build..."
    echo "    This may take several minutes while the base image is"
    echo "    pulled and the dependencies are installed."

    apptainer build --fakeroot --force repscreen.sif Singularity.def

    echo "  -> Apptainer image build completed"
    echo "    You can now run: apptainer run repscreen.sif"
}

# Function to display usage instructions
show_usage() {
    echo "Usage: $0 [docker|singularity|both] [local]"
    echo ""
    echo "DESCRIPTION:"
    echo "  Generates the container definitions for repscreen with"
    echo "  neurodocker, run through uvx so that no container runtime"
    echo "  is needed to generate them."
    echo ""
    echo "  The Docker image itself is built and published by the"
    echo "  container workflow in CI, not here.  'local' builds the"
    echo "  Apptainer image, which needs no Docker daemon."
    echo ""
    echo "ARGUMENTS:"
    echo "  docker       Generate Dockerfile only"
    echo "  singularity  Generate Singularity.def only"
    echo "  both         Generate both files (default if no args)"
    echo "  local        Also build the Apptainer image afterwards"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Generate both definition files"
    echo "  $0 docker             # Generate Dockerfile only"
    echo "  $0 singularity        # Generate Singularity.def only"
    echo "  $0 both local         # Generate both, build the .sif"
    echo "  $0 singularity local  # Generate Singularity.def, build it"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - uv, for uvx to fetch neurodocker ${NEURODOCKER_VERSION}"
    echo "  - apptainer, only for the 'local' build"
    echo "  - an /etc/subuid entry for your user, for --fakeroot"
    echo ""
    echo "OUTPUT FILES:"
    echo "  - Dockerfile: consumed by the CI container workflow"
    echo "  - Singularity.def: Apptainer/Singularity definition"
    echo "  - repscreen.sif: Apptainer image (with 'local')"
}

echo "=== repscreen Container Generation Script ==="
echo ""

GENERATE_DOCKER=false
GENERATE_SINGULARITY=false
BUILD_LOCAL=false

echo "Parsing command line arguments..."

# Default behaviour: generate both definition files
if [ $# -eq 0 ]; then
    echo "  -> No arguments provided, generating both definitions"
    GENERATE_DOCKER=true
    GENERATE_SINGULARITY=true
fi

for arg in "$@"; do
    echo "  -> Processing argument: $arg"
    case $arg in
        docker)
            echo "    Will generate Dockerfile"
            GENERATE_DOCKER=true
            ;;
        singularity)
            echo "    Will generate Singularity.def"
            GENERATE_SINGULARITY=true
            ;;
        both)
            echo "    Will generate both definition files"
            GENERATE_DOCKER=true
            GENERATE_SINGULARITY=true
            ;;
        local)
            echo "    Will build the Apptainer image after generating"
            BUILD_LOCAL=true
            ;;
        help|--help|-h)
            echo ""
            show_usage
            exit 0
            ;;
        *)
            echo "    Error: Unknown argument '$arg'"
            echo ""
            echo "Valid arguments: docker, singularity, both, local, help"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# 'local' on its own has nothing to build from
if [ "$BUILD_LOCAL" = true ] && [ "$GENERATE_SINGULARITY" = false ]; then
    echo ""
    echo "Error: 'local' builds the Apptainer image and therefore"
    echo "needs 'singularity' or 'both' as well."
    echo ""
    show_usage
    exit 1
fi

echo ""
echo "Configuration summary:"
echo "  - Generate Dockerfile: $GENERATE_DOCKER"
echo "  - Generate Singularity.def: $GENERATE_SINGULARITY"
echo "  - Build the Apptainer image: $BUILD_LOCAL"
echo ""

if [ "$GENERATE_DOCKER" = false ] && [ "$GENERATE_SINGULARITY" = false ]; then
    echo "Error: No generation options selected."
    echo ""
    show_usage
    exit 1
fi

echo "=== GENERATION PHASE ==="
echo ""

if [ "$GENERATE_DOCKER" = true ]; then
    echo "Generating Dockerfile..."
    generate_docker > Dockerfile
    echo "Dockerfile written ($(wc -l < Dockerfile) lines)"
    echo ""
fi

if [ "$GENERATE_SINGULARITY" = true ]; then
    echo "Generating Singularity.def..."
    generate_singularity > Singularity.def
    echo "Singularity.def written ($(wc -l < Singularity.def) lines)"
    echo ""
fi

if [ "$BUILD_LOCAL" = true ]; then
    echo "=== BUILD PHASE ==="
    echo ""
    build_apptainer
    echo ""
    if [ -f "repscreen.sif" ]; then
        echo "Apptainer image information:"
        echo "  Size: $(du -h repscreen.sif | cut -f1)"
        echo "  Location: $(pwd)/repscreen.sif"
    fi
    echo ""
else
    echo "=== GENERATION COMPLETE ==="
    echo ""
    echo "Definition files generated; no image was built."
    echo ""
    echo "To build the Apptainer image:"
    echo "  - apptainer build --fakeroot repscreen.sif Singularity.def"
    echo "  - or run this script again with 'local'"
    echo ""
    echo "The Docker image is built and published by CI from the"
    echo "generated Dockerfile."
    echo ""
fi

echo "=== SUMMARY ==="
echo ""
echo "Generated files:"
if [ "$GENERATE_DOCKER" = true ]; then
    echo "  Dockerfile ($(wc -l < Dockerfile) lines)"
fi
if [ "$GENERATE_SINGULARITY" = true ]; then
    echo "  Singularity.def ($(wc -l < Singularity.def) lines)"
fi
if [ "$BUILD_LOCAL" = true ] && [ -f "repscreen.sif" ]; then
    echo "  repscreen.sif"
fi
echo ""
echo "Script execution completed at $(date)"
echo ""
