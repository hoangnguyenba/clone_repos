#!/usr/bin/env bash

# GitHub Repository Cloner Script
# Usage: ./clone_repos.sh [config_file]
# Default config file: repos.txt

set -e  # Exit on any error

# Default configuration file
CONFIG_FILE="${1:-repos.txt}"

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

# Function to clone a single repository
clone_repo() {
    local repo_url=$1
    local target_path=$2
    local branch=$3
    
    print_status $BLUE "📦 Cloning: $repo_url"
    print_status $BLUE "   Path: $target_path"
    print_status $BLUE "   Branch: $branch"
    
    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "$target_path")"
    
    # Check if directory already exists
    if [ -d "$target_path" ]; then
        print_status $YELLOW "⚠️  Directory already exists: $target_path"
        read -p "Do you want to remove it and re-clone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$target_path"
            print_status $GREEN "✅ Removed existing directory"
        else
            print_status $YELLOW "⏭️  Skipping: $target_path"
            return 0
        fi
    fi
    
    # Clone the repository
    if git clone --branch "$branch" --single-branch "$repo_url" "$target_path"; then
        print_status $GREEN "✅ Successfully cloned: $(basename "$repo_url")"
    else
        print_status $RED "❌ Failed to clone: $repo_url"
        return 1
    fi
    
    echo
}

# Function to validate repository URL
validate_repo_url() {
    local url=$1
    if [[ $url =~ ^https://github\.com/[^/]+/[^/]+\.git$ ]] || [[ $url =~ ^git@github\.com:[^/]+/[^/]+\.git$ ]] || [[ $url =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to normalize GitHub URL
normalize_github_url() {
    local url=$1
    # Keep SSH URLs as-is, only add .git if missing for HTTPS
    if [[ $url =~ ^git@github\.com: ]]; then
        # SSH URL - keep as-is, just ensure .git suffix
        if [[ ! $url =~ \.git$ ]]; then
            url="${url}.git"
        fi
    else
        # HTTPS URL - add .git if missing
        if [[ ! $url =~ \.git$ ]]; then
            url="${url}.git"
        fi
    fi
    echo "$url"
}

# Main function
main() {
    print_status $BLUE "🚀 GitHub Repository Cloner"
    echo
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_status $RED "❌ Configuration file not found: $CONFIG_FILE"
        echo
        print_status $YELLOW "Creating example configuration file..."
        cat > "$CONFIG_FILE" << 'EOF'
# GitHub Repository Configuration
# Format: REPO_URL|TARGET_PATH|BRANCH
# Lines starting with # are comments
# Example entries:

https://github.com/torvalds/linux|./projects/linux|master
https://github.com/microsoft/vscode|./projects/vscode|main
git@github.com:facebook/react.git|./projects/react|main
https://github.com/nodejs/node|./projects/nodejs|v18.x
EOF
        print_status $GREEN "✅ Created example config file: $CONFIG_FILE"
        print_status $YELLOW "Please edit the file and run the script again."
        exit 0
    fi
    
    print_status $GREEN "📋 Using configuration file: $CONFIG_FILE"
    echo
    
    # Read and process configuration file
    local line_number=0
    local success_count=0
    local error_count=0
    
    while IFS='|' read -r repo_url target_path branch || [ -n "$repo_url" ]; do
        line_number=$((line_number + 1))
        
        # Skip empty lines and comments
        if [[ -z "$repo_url" ]] || [[ "$repo_url" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Trim whitespace
        repo_url=$(echo "$repo_url" | xargs)
        target_path=$(echo "$target_path" | xargs)
        branch=$(echo "$branch" | xargs)
        
        # Expand tilde (~) and environment variables in target_path
        target_path=$(eval echo "$target_path")
        
        # Validate required fields
        if [[ -z "$repo_url" ]] || [[ -z "$target_path" ]] || [[ -z "$branch" ]]; then
            print_status $RED "❌ Line $line_number: Missing required fields (repo_url|target_path|branch)"
            error_count=$((error_count + 1))
            continue
        fi
        
        # Normalize and validate repository URL
        repo_url=$(normalize_github_url "$repo_url")
        if ! validate_repo_url "$repo_url"; then
            print_status $RED "❌ Line $line_number: Invalid GitHub repository URL: $repo_url"
            error_count=$((error_count + 1))
            continue
        fi
        
        # Clone the repository
        if clone_repo "$repo_url" "$target_path" "$branch"; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        
    done < "$CONFIG_FILE"
    
    # Summary
    echo "================================"
    print_status $GREEN "✅ Successfully cloned: $success_count repositories"
    if [ $error_count -gt 0 ]; then
        print_status $RED "❌ Failed to clone: $error_count repositories"
    fi
    print_status $BLUE "🏁 Cloning process completed!"
}

# Run main function
main "$@"