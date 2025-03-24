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

# Find the NDK directory
find_ndk_dir() {
    # Finally check the default SDK location on macOS
    local default_sdk="$HOME/Library/Android/sdk"
    if [ -d "$default_sdk/ndk/26.3.11579264" ]; then
        echo "$default_sdk/ndk/26.3.11579264"
        return
    fi

    echo "ERROR: Android NDK not found at $default_sdk/ndk/26.3.11579264" >&2
    exit 1
}

# Set the NDK directory
NDK_DIR=$(find_ndk_dir) || exit 1
echo "Using NDK from: $NDK_DIR"

# Set the toolchain directory
TOOLCHAIN_DIR="$NDK_DIR/toolchains/llvm/prebuilt/darwin-x86_64"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    echo "ERROR: Android NDK toolchain not found at $TOOLCHAIN_DIR"
    exit 1
fi

# Set the objcopy path
OBJCOPY="$TOOLCHAIN_DIR/bin/llvm-objcopy"
if [ ! -f "$OBJCOPY" ]; then
    echo "ERROR: llvm-objcopy not found at $OBJCOPY"
    exit 1
fi

echo "Using objcopy from: $OBJCOPY"

# Set the build directory based on build type
if [ "$BUILD_TYPE" = "debug" ]; then
    BUILD_DIR="build/app/intermediates/merged_native_libs/debug/out/lib"
else
    BUILD_DIR="build/app/intermediates/merged_native_libs/release/out/lib"
fi

echo "Looking for native libraries in: $BUILD_DIR"

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Build directory not found at $BUILD_DIR"
    echo "Did you run 'flutter build apk' or 'flutter build appbundle' first?"
    exit 1
fi

# Create output directory
OUTPUT_DIR="build/symbols"
mkdir -p "$OUTPUT_DIR"

# Function to process a directory
process_directory() {
    local dir=$1
    local arch=$2
    
    echo "Processing architecture directory: $dir"
    
    # Create architecture-specific directory
    mkdir -p "$OUTPUT_DIR/$arch"
    
    # Process all .so files
    for so_file in "$dir"/*.so; do
        if [ -f "$so_file" ]; then
            echo "Processing $so_file..."
            "$OBJCOPY" --only-keep-debug "$so_file" "$OUTPUT_DIR/$arch/$(basename "$so_file").debug"
            echo "Successfully extracted debug symbols from $(basename "$so_file")"
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