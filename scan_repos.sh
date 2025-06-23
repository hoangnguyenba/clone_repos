#!/usr/bin/env bash

# Repository Scanner Script
# Scans directories for Git repositories and generates a repos.txt configuration file
# Usage: ./scan_repos.sh [base_path] [output_file]

set -e  # Exit on any error

# Default values
BASE_PATH="${1:-$(pwd)}"
OUTPUT_FILE="${2:-repos_generated.txt}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to get the remote URL of a git repository
get_remote_url() {
    local repo_path=$1
    cd "$repo_path"
    
    # Try to get the origin remote URL
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [[ -z "$remote_url" ]]; then
        # If no origin, try the first remote
        remote_url=$(git remote -v | head -n1 | awk '{print $2}' 2>/dev/null || echo "")
    fi
    
    echo "$remote_url"
}

# Function to get the current branch of a git repository
get_current_branch() {
    local repo_path=$1
    cd "$repo_path"
    
    # Try multiple methods to get current branch
    local branch
    branch=$(git branch --show-current 2>/dev/null || \
             git symbolic-ref --short HEAD 2>/dev/null || \
             git rev-parse --abbrev-ref HEAD 2>/dev/null || \
             echo "main")
    
    echo "$branch"
}

# Function to check if a directory is a git repository
is_git_repo() {
    local dir=$1
    [[ -d "$dir/.git" ]] || git -C "$dir" rev-parse --git-dir >/dev/null 2>&1
}

# Function to convert absolute path to relative path from home directory
to_relative_path() {
    local abs_path=$1
    local home_path="$HOME"
    
    # If path starts with home directory, replace with ~
    if [[ "$abs_path" == "$home_path"* ]]; then
        echo "~${abs_path#$home_path}"
    else
        echo "$abs_path"
    fi
}

# Function to scan repositories recursively
scan_repositories() {
    local base_path=$1
    local repos_found=0
    
    print_status $BLUE "🔍 Scanning for Git repositories in: $base_path"
    echo
    
    # Create temporary file for results
    local temp_file=$(mktemp)
    
    # Find all directories that contain .git
    while IFS= read -r -d '' repo_path; do
        repo_path=$(dirname "$repo_path")
        
        # Skip if it's a .git directory itself
        if [[ "$repo_path" == */.git ]]; then
            continue
        fi
        
        # Skip if it's inside another git repository (submodule case)
        local parent_dir=$(dirname "$repo_path")
        if [[ "$parent_dir" != "$repo_path" ]] && is_git_repo "$parent_dir" 2>/dev/null; then
            continue
        fi
        
        print_status $YELLOW "📁 Found repository: $repo_path"
        
        # Get repository information
        local remote_url
        local current_branch
        local relative_path
        
        remote_url=$(get_remote_url "$repo_path" 2>/dev/null || echo "")
        current_branch=$(get_current_branch "$repo_path" 2>/dev/null || echo "main")
        relative_path=$(to_relative_path "$repo_path")
        
        if [[ -n "$remote_url" ]]; then
            # Filter only GitHub repositories
            if [[ "$remote_url" =~ github\.com ]]; then
                echo "$remote_url|$relative_path|$current_branch" >> "$temp_file"
                print_status $GREEN "   ✅ GitHub repo: $(basename "$remote_url" .git)"
                print_status $GREEN "   🌿 Branch: $current_branch"
                repos_found=$((repos_found + 1))
            else
                print_status $YELLOW "   ⚠️  Non-GitHub repo: $remote_url"
            fi
        else
            print_status $RED "   ❌ No remote URL found"
        fi
        
        echo
        
    done < <(find "$base_path" -name ".git" -type d -print0 2>/dev/null)
    
    # Sort the results and write to output file
    if [[ -s "$temp_file" ]]; then
        {
            echo "# GitHub Repository Configuration"
            echo "# Generated on $(date)"
            echo "# Format: REPO_URL|TARGET_PATH|BRANCH"
            echo "# Base path scanned: $base_path"
            echo ""
            sort "$temp_file"
        } > "$OUTPUT_FILE"
        
        print_status $GREEN "✅ Found $repos_found GitHub repositories"
        print_status $GREEN "📝 Configuration saved to: $OUTPUT_FILE"
    else
        print_status $RED "❌ No GitHub repositories found in: $base_path"
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    return 0
}

# Function to display repository summary
show_summary() {
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo
        print_status $BLUE "📋 Generated Configuration:"
        echo "================================"
        # Show the content excluding comments
        grep -v "^#" "$OUTPUT_FILE" | grep -v "^$" | while IFS='|' read -r url path branch; do
            print_status $GREEN "📦 $(basename "$url" .git)"
            echo "   URL: $url"
            echo "   Path: $path"
            echo "   Branch: $branch"
            echo
        done
    fi
}

# Main function
main() {
    print_status $BLUE "🚀 Repository Scanner"
    echo
    
    # Resolve absolute path
    BASE_PATH=$(realpath "$BASE_PATH")
    
    # Check if base path exists
    if [[ ! -d "$BASE_PATH" ]]; then
        print_status $RED "❌ Directory not found: $BASE_PATH"
        exit 1
    fi
    
    print_status $GREEN "📂 Base path: $BASE_PATH"
    print_status $GREEN "📄 Output file: $OUTPUT_FILE"
    echo
    
    # Scan repositories
    scan_repositories "$BASE_PATH"
    
    # Show summary
    show_summary
    
    echo "================================"
    print_status $GREEN "🏁 Scan completed!"
    print_status $YELLOW "💡 You can now use '$OUTPUT_FILE' with the clone script"
}

# Run main function
main "$@"