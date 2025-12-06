#!/bin/zsh
# ----------------------------------------
# File: python-functions.sh
# Description: Python project and environment management functions using uv.
# ----------------------------------------
#
# USAGE:
#   Add the following to your .zshrc or .bashrc:
#     source /path/to/this/repo/python-functions.sh
#
#   Ensure you have 'uv' and 'git' installed.

# --- Configuration ---
# Edit these variables to match your preference, or override them in your .zshrc before sourcing this file.

# Directory where new projects will be created
: ${DEV_DIR:="$HOME/developer"}

# Template Source (Using the GitHub repository)
: ${PYTHON_TEMPLATE_REPO:="gh:jwa91/python-template"}

# GitHub Username (Defaults to jwa91, change this to your username)
: ${PYTHON_TEMPLATE_GITHUB_USER:="jwa91"}

# --- Environment prerequisites ---

if (( ! $+commands[uv] )); then
    echo "Warning: 'uv' is not installed. Please install it: https://docs.astral.sh/uv/" >&2
fi

if (( ! $+commands[git] )); then
    echo "Warning: 'git' is not installed." >&2
fi

# --- Core Functions ---

# --- Quick Project Creation ---
# Purpose: Creates a new Python project using the standard uv template.
function mkpyproject() {
    local name="${1:?Usage: mkpyproject <project-name>}"

    # Validate kebab-case naming
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo "Error: Use kebab-case (e.g., my-cool-project)" >&2
        return 1
    fi

    local project_path="$DEV_DIR/$name"

    if [[ -e "$project_path" ]]; then
        echo "Error: $project_path already exists" >&2
        return 1
    fi

    # Ensure we're in a valid directory before running copier
    cd "$HOME" || return 1

    # Configure Defaults (Bypass Interactive Prompts)
    # Auto-detect from Git config
    local author_name=$(git config user.name)
    local author_email=$(git config user.email)
    # Hardcode your GitHub username here to skip the prompt (or override via env var)
    local github_user="${GITHUB_USER:-$PYTHON_TEMPLATE_GITHUB_USER}"
    # Compute project slug (kebab-case -> snake_case)
    local project_slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr '-' '_')

    echo "Creating project '$name' at $project_path..."

    # Create project from template
    if ! uvx copier copy "$PYTHON_TEMPLATE_REPO" "$project_path" \
        --trust \
        --quiet \
        --data "project_name=$name" \
        --data "_project_slug=$project_slug" \
        --data "author_name=$author_name" \
        --data "author_email=$author_email" \
        --data "github_username=$github_user"; then
        echo "Error: Copier failed" >&2
        [[ -d "$project_path" ]] && rm -rf "$project_path" && echo "Cleaned up failed project directory" >&2
        return 1
    fi

    cd "$project_path" || {
        echo "Error: Failed to cd to $project_path" >&2
        rm -rf "$project_path" && echo "Cleaned up failed project directory" >&2
        return 1
    }

    # Setup environment and git
    echo "Initializing environment..."
    if ! uv sync; then
        echo "Error: Failed to sync environment" >&2
        cd "$HOME" && rm -rf "$project_path" && echo "Cleaned up failed project directory" >&2
        return 1
    fi

    if ! git init -b main; then
        echo "Error: Failed to initialize git" >&2
        cd "$HOME" && rm -rf "$project_path" && echo "Cleaned up failed project directory" >&2
        return 1
    fi

    if ! uv run pre-commit install; then
        echo "Error: Failed to install pre-commit hooks" >&2
        cd "$HOME" && rm -rf "$project_path" && echo "Cleaned up failed project directory" >&2
        return 1
    fi

    # Run pre-commit on all files (allow failure for auto-fixes)
    echo "Running initial checks..."
    git add -A
    uv run pre-commit run --all-files || true

    # Re-add any files modified by pre-commit fixes
    git add -A
    git commit -m "Initial commit"

    echo "\n✓ Project ready: $project_path"
    echo "  Run tests:  uv run pytest"
    echo "  Start dev:  cursor . (or code .)"
}

# Purpose: Changes directory to a project in DEV_DIR or lists available projects.
function workon() {
    local project_name="$1"

    if [[ -z "$project_name" ]]; then
        echo "Available projects in '$DEV_DIR':"
        local projects_found=0
        while IFS= read -r project_path_found; do
            if [[ -d "$project_path_found" ]]; then
                echo "  $(basename "$project_path_found")"
                projects_found=1
            fi
        done < <(find "$DEV_DIR" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort)
        
        if [[ "$projects_found" -eq 0 ]]; then echo "  (No project directories found)"; fi
        return 0
    fi

    local project_path="$DEV_DIR/$project_name"

    if [[ ! -d "$project_path" ]]; then 
        echo "Error: Project directory '$project_path' not found." >&2
        workon
        return 1
    fi

    cd "$project_path" || { echo "Error: Failed to change directory." >&2; return 1; }

    echo "Changed directory to '$project_path'"

    if [[ -d ".venv" ]]; then
        echo "Found '.venv' directory."
        echo "=> Recommended: Use 'uv run <command>'"
        echo "=> Optional: Activate manually via 'source .venv/bin/activate'"
        # Optional: automatically activate
        # source .venv/bin/activate
    elif [[ -f "pyproject.toml" ]]; then
        local pinned_version=""
        if [[ -f ".python-version" ]]; then 
            pinned_version=$(<".python-version")
            echo "Found 'pyproject.toml' and '.python-version' (Python $pinned_version), but no '.venv'."
        else 
            echo "Found 'pyproject.toml' but no '.venv' directory."
        fi
        echo "=> Run 'uv sync' or 'uv add <package>' to create the virtual environment."
    else
        echo "No uv project files (.venv, pyproject.toml) found."
    fi

    return 0
}

# Purpose: Removes a project directory from DEV_DIR after confirmation.
function rmproject() {
    local project_name="$1"

    if [[ -z "$project_name" ]]; then echo "Usage: rmproject <project_name>" >&2; return 1; fi

    local project_path="$DEV_DIR/$project_name"

    if [[ ! -d "$project_path" ]]; then 
        echo "Error: Project directory '$project_path' not found." >&2
        workon
        return 1
    fi

    if [[ "$PWD" == "$project_path" ]] || [[ "$PWD"/ == "$project_path"/ ]]; then
        echo "Warning: You are currently inside '$project_name'. Changing to '$DEV_DIR'."
        cd "$DEV_DIR" || { echo "Error: Could not cd out. Aborting." >&2; return 1; }
    fi

    echo "WARNING: This will permanently delete: '$project_path'" >&2
    read -q "response?Are you absolutely sure? (y/N) "; echo
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if rm -rf "$project_path"; then 
            echo "Project '$project_name' removed successfully."
            return 0
        else 
            echo "Error: Failed to remove project directory." >&2
            return 1
        fi
    else 
        echo "Operation cancelled."
        return 1
    fi
}

# Purpose: Finds and optionally removes all .venv directories within projects in DEV_DIR.
function cleanup_venvs() {
    local dry_run=0

    if [[ "$1" == "--dry-run" ]]; then 
        dry_run=1
        echo "Dry run: Finding project .venv directories..."
    else 
        echo "Finding project .venv directories to remove..."
    fi

    local find_cmd=("find" "$DEV_DIR" "-maxdepth" "2" "-type" "d" "-name" ".venv" "-print0")
    echo "Found potential .venv director(y/ies) to remove:"

    local found_count=0
    while IFS= read -r -d $'\0' venv_path; do
        printf '  %s\n' "$venv_path"
        ((found_count++))
    done < <("${find_cmd[@]}")

    if [[ "$found_count" -eq 0 ]]; then
        echo "No .venv directories found within projects in '$DEV_DIR'."
        return 0
    fi

    echo "Found $found_count director(y/ies) listed above."

    if [[ "$dry_run" -eq 1 ]]; then
        echo "Dry run complete. No directories removed."
        return 0
    fi

    echo "\nWARNING: This will permanently delete the listed virtual environments." >&2
    read -q "response?Proceed with deletion? (y/N) "; echo

    if [[ "$response" =~ ^[Yy]$ ]]; then
        if "${find_cmd[@]}" | xargs -0 -r -- rm -rf; then
            echo "\nCleanup complete. Attempted removal of listed directories."
            return 0
        else
            echo "\nCleanup failed. Some directories might not have been removed." >&2
            return 1
        fi
    else 
        echo "Operation cancelled."
        return 1
    fi
}

# --- Completions ---
# Purpose: Helper function for Zsh completion to list project directories.
function _list_projects_in_dev_dir() {
    local project_dirs
    project_dirs=( $(find "$DEV_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null) )
    compadd -a project_dirs
}

compdef _list_projects_in_dev_dir workon
compdef _list_projects_in_dev_dir rmproject

# Aliases
alias lspy="ls -1 $DEV_DIR"

