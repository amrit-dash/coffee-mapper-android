#!/bin/bash

# Coffee Mapper Android GitHub Operations Script
# This script handles various GitHub operations including commits, pushes, and releases

# Function to display usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  commit <message>                    Create a commit with the given message"
    echo "  push <message> [mode]              Push changes with commit message and optional mode"
    echo "    modes:"
    echo "      --skip-ci                      Push without triggering CI"
    echo "      --debug                        Push and trigger debug build"
    echo "      --release <version>            Push and create a release with version"
    echo ""
    echo "Examples:"
    echo "  $0 commit \"feat: add new feature\""
    echo "  $0 push \"feat: add new feature\" --skip-ci"
    echo "  $0 push \"feat: add new feature\" --debug"
    echo "  $0 push \"feat: new release\" --release v1.1.0"
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

# Function to push changes
push_changes() {
    local message="$1"
    local mode="$2"
    local version="$3"
    
    # Create commit first
    create_commit "$message"
    
    case "$mode" in
        "--skip-ci")
            # Push with [skip ci] tag to skip GitHub Actions
            git push -o ci.skip
            ;;
        "--debug")
            # Push normally to trigger debug workflow
            git push
            ;;
        "--release")
            if [ -z "$version" ]; then
                echo "Error: Version number is required for release mode"
                usage
            fi
            
            # Create and push tag
            git tag -a "$version" -m "Release $version"
            git push origin "$version"
            
            # Create GitHub release
            gh release create "$version" \
                --title "Release $version" \
                --notes "Release $version - $message" \
                --target main
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
        push_changes "$message" "$mode" "$version"
        ;;
    *)
        usage
        ;;
esac 