#!/bin/bash

# Exit on error
set -e

# Function to find the NDK directory
find_ndk_dir() {
    # Check common NDK locations
    local possible_locations=(
        "$ANDROID_HOME/ndk"
        "$ANDROID_SDK_ROOT/ndk"
        "/usr/local/lib/android/sdk/ndk"
        "$HOME/Library/Android/sdk/ndk"
    )

    for base_dir in "${possible_locations[@]}"; do
        if [ -d "$base_dir" ]; then
            # Look for any NDK version, preferring 25.2.9519653 if available
            if [ -d "$base_dir/25.2.9519653" ]; then
                echo "$base_dir/25.2.9519653"
                return 0
            else
                # Get the latest version
                local latest_version=$(ls -1 "$base_dir" 2>/dev/null | sort -V | tail -n 1)
                if [ -n "$latest_version" ]; then
                    echo "$base_dir/$latest_version"
                    return 0
                fi
            fi
        fi
    done
    return 1
}

# Function to display usage
usage() {
    echo "Usage: $0 <build_type>"
    echo "build_type: debug or release"
    exit 1
}

# Check if build type is provided
if [ $# -ne 1 ]; then
    usage
fi

BUILD_TYPE=$1

# Validate build type
if [ "$BUILD_TYPE" != "debug" ] && [ "$BUILD_TYPE" != "release" ]; then
    usage
fi

# Find NDK directory
NDK_DIR=$(find_ndk_dir)
if [ -z "$NDK_DIR" ]; then
    echo "ERROR: Android NDK not found"
    exit 1
fi

echo "Found NDK at: $NDK_DIR"

# Set up paths
TOOLCHAIN_DIR="$NDK_DIR/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    echo "ERROR: Android NDK toolchain not found at $TOOLCHAIN_DIR"
    exit 1
fi

OBJCOPY="$TOOLCHAIN_DIR/bin/llvm-objcopy"
if [ ! -f "$OBJCOPY" ]; then
    echo "ERROR: llvm-objcopy not found at $OBJCOPY"
    exit 1
fi

# Set up build directories
BUILD_DIR="build/app/intermediates/merged_native_libs/$BUILD_TYPE/out/lib"
TEMP_DIR="build/temp_symbols"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Process each architecture
for arch in $(ls "$BUILD_DIR"); do
    echo "Processing architecture: $arch"
    
    # Create output directory for this architecture
    mkdir -p "$TEMP_DIR/$arch"
    
    # Process each .so file
    for lib in $(find "$BUILD_DIR/$arch" -name "*.so"); do
        echo "Processing library: $lib"
        
        # Get the base name of the library
        base_name=$(basename "$lib")
        
        # Copy the original .so file (which includes debug info)
        cp "$lib" "$TEMP_DIR/$arch/$base_name"
    done
done

# Create zip file with the correct structure
cd build/temp_symbols
zip -r -X "../symbols_${BUILD_TYPE}.zip" * -x ".*" "__MACOSX" "*.debug"
cd ../..

# Clean up
rm -rf "$TEMP_DIR"

echo "Debug symbols have been generated at: build/symbols_${BUILD_TYPE}.zip" 