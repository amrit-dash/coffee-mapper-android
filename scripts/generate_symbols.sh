#!/bin/bash

# Exit on error
set -e

# Function to print usage
usage() {
    echo "Usage: $0 [debug|release]"
    echo "  debug   - Generate symbols for debug build"
    echo "  release - Generate symbols for release build"
    exit 1
}

# Check if argument is provided
if [ $# -ne 1 ]; then
    usage
fi

# Set build type
BUILD_TYPE=$1

# Validate build type
if [ "$BUILD_TYPE" != "debug" ] && [ "$BUILD_TYPE" != "release" ]; then
    usage
fi

# Check and install required tools
check_and_install_tools() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is required. Please install it from https://brew.sh/"
            exit 1
        fi
        
        if ! command -v /opt/homebrew/opt/binutils/bin/gobjcopy &> /dev/null; then
            echo "Installing binutils using Homebrew..."
            brew install binutils
        fi
        
        # Set the OBJCOPY variable based on architecture and OS
        OBJCOPY="/opt/homebrew/opt/binutils/bin/gobjcopy"
    else
        # Linux (Ubuntu in GitHub Actions)
        if ! command -v objcopy &> /dev/null; then
            echo "Installing binutils..."
            sudo apt-get update
            sudo apt-get install -y binutils
        fi
        OBJCOPY="objcopy"
    fi
}

# Install required tools
check_and_install_tools

# Set the build directory based on build type
if [ "$BUILD_TYPE" = "debug" ]; then
    BUILD_DIR="build/app/intermediates/merged_native_libs/debug/out/lib"
else
    BUILD_DIR="build/app/intermediates/merged_native_libs/release/out/lib"
fi

# Create output directory
OUTPUT_DIR="build/symbols"
mkdir -p "$OUTPUT_DIR"

# Function to process a directory
process_directory() {
    local dir=$1
    local arch=$2
    
    # Create architecture-specific directory
    mkdir -p "$OUTPUT_DIR/$arch"
    
    # Process all .so files
    for so_file in "$dir"/*.so; do
        if [ -f "$so_file" ]; then
            echo "Processing $so_file..."
            "$OBJCOPY" --only-keep-debug "$so_file" "$OUTPUT_DIR/$arch/$(basename "$so_file").debug"
        fi
    done
}

# Process each architecture
for arch_dir in "$BUILD_DIR"/*; do
    if [ -d "$arch_dir" ]; then
        arch=$(basename "$arch_dir")
        echo "Processing architecture: $arch"
        process_directory "$arch_dir" "$arch"
    fi
done

# Create zip file
echo "Creating symbols zip file..."
cd "$OUTPUT_DIR"
zip -r "../symbols_${BUILD_TYPE}.zip" .

echo "Symbols generated successfully at build/symbols_${BUILD_TYPE}.zip" 