#!/bin/bash

# Script: generate_images.sh
# Purpose: Generate Docker and/or Singularity container definition files for a given project
# Description: This script generates reproducible container definitions
#              that include the OS and all dependencies, using uv for
#              fast Python package management.

# Exit immediately if any command fails
# This ensures the script stops at the first error rather than continuing with potentially broken state
set -e

# Function to generate Dockerfile using neurodocker
# Uses uv for Python package management instead of conda
generate_docker() {
  # Use neurodocker container to generate Dockerfile
  # We run neurodocker itself in a Docker container to avoid local installation requirements
  docker run --rm repronim/neurodocker:2.1.1 generate docker \
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

# Function to generate Singularity definition file using neurodocker
# Uses uv for Python package management instead of conda
generate_singularity() {

  # Use neurodocker container to generate Singularity definition file
  # Most parameters are identical to Docker version for consistency
  docker run --rm repronim/neurodocker:2.1.1 generate singularity \
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


# Function to build Docker image from generated Dockerfile
# This function builds the actual Docker image that can be run locally
build_docker() {
    echo "  → Starting Docker image build process..."
    echo "    This may take several minutes as it downloads base images and installs all dependencies..."

    # Build Docker image using current directory as build context
    # The -t flag tags the image with a name for easy reference
    # The . specifies current directory as build context (where Dockerfile is located)
    docker build -t repscreen:local .

    echo "  → Docker image build completed"
    echo "    You can now run: docker run -p 8888:8888 repscreen:local"
}

# Function to build Singularity image from generated definition file
# This function builds the actual Singularity image (.sif file) that can be run locally
build_singularity() {
    echo "  → Starting Singularity image build process..."
    echo "    This may take several minutes and might require sudo privileges..."
    echo "    Note: Building Singularity images often requires root access or fakeroot"

    # Build Singularity Image Format (.sif) file from definition
    # The resulting .sif file is a single executable container image
    # Singularity build process may require sudo depending on system configuration
    singularity build repscreen.sif Singularity.def

    echo "  → Singularity image build completed"
    echo "    You can now run: singularity run repscreen.sif"
}

# Function to display comprehensive usage instructions
# This helps users understand all available options and use cases
show_usage() {
    echo "Usage: $0 [docker|singularity|both] [local]"
    echo ""
    echo "DESCRIPTION:"
    echo "  This script generates container definition files and optionally builds container images"
    echo "  for the repscreen project using neurodocker for reproducible container generation."
    echo "  It creates containers with a uv-managed virtual environment and all project dependencies."
    echo ""
    echo "ARGUMENTS:"
    echo "  docker       Generate Dockerfile only"
    echo "  singularity  Generate Singularity definition file only"
    echo "  both         Generate both Docker and Singularity files (default if no args)"
    echo "  local        Also build the image(s) locally after generating definition files"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Generate both definition files, don't build images"
    echo "  $0 docker            # Generate Dockerfile only, don't build"
    echo "  $0 singularity       # Generate Singularity.def only, don't build"
    echo "  $0 both local        # Generate both files and build both images"
    echo "  $0 docker local      # Generate Dockerfile and build Docker image"
    echo "  $0 singularity local # Generate Singularity.def and build Singularity image"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - Docker must be installed and running (for generating files and building Docker images)"
    echo "  - Singularity must be installed (only for building Singularity images)"
    echo "  - repronim/neurodocker Docker image will be pulled automatically if not present"
    echo ""
    echo "OUTPUT FILES:"
    echo "  - Dockerfile: Docker container definition (if docker option used)"
    echo "  - Singularity.def: Singularity container definition (if singularity option used)"
    echo "  - repscreen:local: Docker image (if docker + local options used)"
    echo "  - repscreen.sif: Singularity image file (if singularity + local options used)"
    echo ""
    echo "NOTES:"
    echo "  - Both container types will have identical environments and functionality"
    echo "  - Building images locally requires significant time and disk space"
    echo "  - Singularity builds may require sudo privileges depending on system configuration"
}

echo "=== repscreen Container Generation Script ==="
echo ""

# Initialize control flags based on command line arguments
# These boolean variables determine what actions the script will take
GENERATE_DOCKER=false      # Whether to generate Dockerfile
GENERATE_SINGULARITY=false # Whether to generate Singularity.def
BUILD_LOCAL=false          # Whether to build images locally after generation

echo "Parsing command line arguments..."

# Default behavior: if no arguments provided, generate both definition files
# This maintains backward compatibility with the original script behavior
# Users can still run the script without arguments and get sensible defaults
if [ $# -eq 0 ]; then
    echo "  → No arguments provided, using default behavior (generate both definition files)"
    GENERATE_DOCKER=true
    GENERATE_SINGULARITY=true
fi

# Parse all command line arguments in a loop
# This approach allows arguments to be provided in any order
# Multiple arguments are supported (e.g., "docker local" or "both local")
for arg in "$@"; do
    echo "  → Processing argument: $arg"
    case $arg in
        docker)
            # User specifically requested Docker support
            echo "    ✓ Will generate Dockerfile"
            GENERATE_DOCKER=true
            ;;
        singularity)
            # User specifically requested Singularity support
            echo "    ✓ Will generate Singularity definition file"
            GENERATE_SINGULARITY=true
            ;;
        both)
            # User explicitly requested both container types
            echo "    ✓ Will generate both Docker and Singularity definition files"
            GENERATE_DOCKER=true
            GENERATE_SINGULARITY=true
            ;;
        local)
            # User wants to build images locally after generating definitions
            echo "    ✓ Will build container images locally after generation"
            BUILD_LOCAL=true
            ;;
        help|--help|-h)
            # User requested help information
            echo "    → Displaying help information"
            echo ""
            show_usage
            exit 0
            ;;
        *)
            # Unknown/invalid argument provided
            echo "    ✗ Error: Unknown argument '$arg'"
            echo ""
            echo "Valid arguments are: docker, singularity, both, local, help"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

echo ""
echo "Configuration summary:"
echo "  - Generate Dockerfile: $GENERATE_DOCKER"
echo "  - Generate Singularity.def: $GENERATE_SINGULARITY"
echo "  - Build images locally: $BUILD_LOCAL"
echo ""

# Validation: ensure at least one generation option is selected
# This prevents the script from running without doing anything useful
if [ "$GENERATE_DOCKER" = false ] && [ "$GENERATE_SINGULARITY" = false ]; then
    echo "Error: No generation options selected. At least one of 'docker' or 'singularity' must be specified."
    echo ""
    show_usage
    exit 1
fi

echo "=== GENERATION PHASE ==="
echo ""

# Generate container definition files based on user selection
# This section calls the appropriate generation functions and creates the definition files
# Each generation function uses neurodocker to create the container specifications

if [ "$GENERATE_DOCKER" = true ]; then
    echo "Step 1: Generating Dockerfile..."
    echo "  This will create a Dockerfile that can be used to build a Docker image"

    # Call the generate_docker function and redirect output to Dockerfile
    # The neurodocker tool outputs the complete Dockerfile content to stdout
    # We capture this output and write it to the Dockerfile in the current directory
    generate_docker > Dockerfile

    echo "✓ Dockerfile generated successfully and saved to './Dockerfile'"
    echo "  File size: $(wc -c < Dockerfile) bytes, $(wc -l < Dockerfile) lines"
    echo ""
fi

if [ "$GENERATE_SINGULARITY" = true ]; then
    echo "Step 2: Generating Singularity definition file..."
    echo "  This will create a Singularity.def file that can be used to build a Singularity image"

    # Call the generate_singularity function and redirect output to Singularity.def
    # The neurodocker tool outputs the complete Singularity definition to stdout
    # We capture this output and write it to the Singularity.def file in the current directory
    generate_singularity > Singularity.def

    echo "✓ Singularity.def generated successfully and saved to './Singularity.def'"
    echo "  File size: $(wc -c < Singularity.def) bytes, $(wc -l < Singularity.def) lines"
    echo ""
fi

# Build container images locally if requested by user
# This section only executes if the 'local' argument was provided
# Building images can take significant time and requires the respective container runtimes
if [ "$BUILD_LOCAL" = true ]; then
    echo "=== BUILD PHASE ==="
    echo ""
    echo "Building container images locally..."
    echo "Warning: This process can take 10-30 minutes and requires significant disk space"
    echo ""

    # Build Docker image if Dockerfile was generated
    if [ "$GENERATE_DOCKER" = true ]; then
        echo "Step 3: Building Docker image..."
        echo "  This will create a Docker image tagged as 'repscreen:local'"
        build_docker
        echo ""

        # Display information about the built image
        echo "Docker image information:"
        docker images repscreen:local --format "  Size: {{.Size}}, Created: {{.CreatedSince}}"
        echo ""
    fi

    # Build Singularity image if definition file was generated
    if [ "$GENERATE_SINGULARITY" = true ]; then
        echo "Step 4: Building Singularity image..."
        echo "  This will create a Singularity image file 'repscreen.sif'"
        build_singularity
        echo ""

        # Display information about the built image file
        if [ -f "repscreen.sif" ]; then
            echo "Singularity image information:"
            echo "  Size: $(du -h repscreen.sif | cut -f1)"
            echo "  Location: $(pwd)/repscreen.sif"
        fi
        echo ""
    fi
else
    # Inform user that no images were built, but provide guidance
    echo "=== GENERATION COMPLETE ==="
    echo ""
    echo "✓ Container definition files have been generated successfully"
    echo "  Images were NOT built locally (no 'local' argument provided)"
    echo ""
    echo "To build images later, you can:"
    if [ "$GENERATE_DOCKER" = true ]; then
        echo "  - Build Docker image: docker build -t repscreen:local ."
    fi
    if [ "$GENERATE_SINGULARITY" = true ]; then
        echo "  - Build Singularity image: singularity build repscreen.sif Singularity.def"
    fi
    echo "  - Or run this script again with the 'local' argument"
    echo ""
fi

echo "=== SUMMARY ==="
echo ""
echo "✓ All requested tasks completed successfully!"
echo ""

# Display final summary of what was accomplished
echo "Generated files:"
if [ "$GENERATE_DOCKER" = true ]; then
    echo "  ✓ Dockerfile ($(wc -l < Dockerfile) lines)"
fi
if [ "$GENERATE_SINGULARITY" = true ]; then
    echo "  ✓ Singularity.def ($(wc -l < Singularity.def) lines)"
fi

if [ "$BUILD_LOCAL" = true ]; then
    echo ""
    echo "Built images:"
    if [ "$GENERATE_DOCKER" = true ]; then
        echo "  ✓ Docker image: repscreen:local"
    fi
    if [ "$GENERATE_SINGULARITY" = true ] && [ -f "repscreen.sif" ]; then
        echo "  ✓ Singularity image: repscreen.sif"
    fi
fi

echo ""
echo "Next steps:"
echo "  - Review the generated definition files before building/using"
echo "  - Test the containers to ensure they work as expected"
echo "  - Share the definition files with your team for reproducible environments"
echo ""
echo "Script execution completed at $(date)"
echo ""
