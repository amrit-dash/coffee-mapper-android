#!/bin/bash

# Coffee Mapper Android GitHub Operations Script
# This script handles various GitHub operations including commits, pushes, and releases
# Version: 2.0.0

# Function to display usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  commit <message>                    Create a commit with the given message"
    echo "  push <message> [options]           Push changes with commit message and options"
    echo "    options:"
    echo "      --skip-ci                      Push without triggering CI"
    echo "      --debug                        Push and trigger debug build"
    echo "      --release <version> <build>    Push and create a release with version and build number"
    echo ""
    echo "Examples:"
    echo "  $0 commit \"feat: add new feature\""
    echo "  $0 push \"feat: add new feature\" --skip-ci"
    echo "  $0 push \"feat: add new feature\" --debug"
    echo "  $0 push \"feat: new release\" --release 1.1.2 2"
    exit 1
}

# Function to validate git repository
validate_repo() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Error: Not a git repository"
        exit 1
    fi
}

# Function to create a commit
create_commit() {
    local message="$1"
    if [ -z "$message" ]; then
        echo "Error: Commit message is required"
        usage
    fi
    
    # Stage all changes
    git add .
    
    # Create commit
    git commit -m "$message"
}

# Function to handle debug build
handle_debug_build() {
    local message="$1"
    
    # Create commit first
    create_commit "$message"
    
    # Push to trigger debug workflow
    git push
    
    echo "Debug build triggered. The workflow will:"
    echo "1. Build debug APK"
    echo "2. Update latest-debug tag"
    echo "3. Create/Update debug release"
}

# Function to handle release build
handle_release_build() {
    local message="$1"
    local version="$2"
    local build="$3"
    
    if [ -z "$version" ] || [ -z "$build" ]; then
        echo "Error: Version number and build number are required for release mode"
        usage
    fi
    
    # Create commit first
    create_commit "$message"
    
    # Push changes
    git push
    
    # Trigger release workflow
    gh workflow run release.yml -f version="$version" -f build_number="$build"
    
    echo "Release build triggered. The workflow will:"
    echo "1. Clean up old version tags"
    echo "2. Build release APK v$version (build $build)"
    echo "3. Create version tag v$version"
    echo "4. Update latest-release tag"
    echo "5. Create/Update release"
}

# Function to push changes
push_changes() {
    local message="$1"
    local mode="$2"
    local version="$3"
    local build="$4"
    
    case "$mode" in
        "--skip-ci")
            # Create commit first
            create_commit "$message"
            # Push with [skip ci] tag to skip GitHub Actions
            git push -o ci.skip
            ;;
        "--debug")
            handle_debug_build "$message"
            ;;
        "--release")
            handle_release_build "$message" "$version" "$build"
            ;;
        *)
            echo "Error: Invalid mode"
            usage
            ;;
    esac
}

# Main script logic
validate_repo

command="$1"
shift

case "$command" in
    "commit")
        create_commit "$1"
        ;;
    "push")
        message="$1"
        mode="$2"
        version="$3"
        build="$4"
        push_changes "$message" "$mode" "$version" "$build"
        ;;
    *)
        usage
        ;;
esac 