# Python UV Template

Opinionated Python project template.

## Features

- **uv** — Fast package manager
- **ruff** — Linting & formatting with Google-style docstrings enforced
- **pyright** — Strict type checking
- **import-linter** — Layered architecture enforcement
- **pytest** — Testing with coverage support
- **pre-commit** — Git hooks for all checks (local execution via uv)

## Setup & Usage

To use this template you only need the `python-functions.sh` script. The script uses copier to fetch the template directly from GitHub when you create a project. If needed, you could modify the template and point the script to either a local path or your own repository.

### 1. Configure your Shell

Download the script and add the following to your `.zshrc` (or `.bashrc`):

```bash
# --- Python Project Management ---

# Where new projects will be created
export DEV_DIR="$HOME/developer"

# Download python-functions.sh to a location of your choice, then source it:
source "$HOME/.config/python-functions.sh"

# Optional: Use your own fork or a local template path
# export PYTHON_TEMPLATE_REPO="/path/to/local/template"
# export PYTHON_TEMPLATE_REPO="gh:your-username/python-template"
```

**Requirements:** `uv` and `git` must be installed.

### 2. Workflow Commands

Once configured, you have access to the following commands:

- `mkpyproject <name>`: Create a new project using this template.
  - Automatically fills author details from your git config.
  - Initializes git, installs dependencies, and sets up pre-commit hooks.
- `workon [name]`: Switch to an existing project.
  - If no name is provided, lists available projects.
  - Checks for and can activate the `.venv`.
- `rmproject <name>`: Safely remove a project directory.
- `lspy`: List all python projects in your `DEV_DIR`.
- `cleanup_venvs [--dry-run]`: Batch remove `.venv` folders to save space.

### 3. Usage Examples

**Create a new project:**

```bash
mkpyproject my-new-service
```

This single command will:

1.  **Generate** the project structure from this template.
2.  **Initialize** a new git repository (branch `main`).
3.  **Install** dependencies (creating a `.venv`).
4.  **Setup** pre-commit hooks for code quality.
5.  **Format** the code and create the **initial commit**.
6.  **Navigate** you into the project directory so you can start coding immediately.
7.  **Activate** the virtual environment.

> **Why auto-activate?** Even though `uv run` handles environments automatically, we activate the `.venv` as a safety measure. This prevents accidentally running `pip install` against your system Python and shows the correct Python version in your prompt.

**Switch to a project:**

```bash
workon my-new-service
# cd's to ~/developer/my-new-service
```

```bash
workon
# lists projects in ~/developer/
```

## Manual Usage

If you prefer not to use the helper script, you can run copier directly. You will be prompted for values:

```bash
uvx copier copy gh:jwa91/python-template path/to/destination
```

## What's Included

| File                      | Purpose                                    |
| ------------------------- | ------------------------------------------ |
| `pyproject.toml`          | Project config, dependencies, uv settings  |
| `ruff.toml`               | Linting rules with docstring enforcement   |
| `pyrightconfig.json`      | Strict type checking config                |
| `.importlinter`           | Import layering rules (main -> utils)      |
| `.pre-commit-config.yaml` | Git hooks for ruff, pyright, import-linter |
| `AGENTS.md`               | AI assistant instructions and architecture |
| `py.typed`                | PEP 561 marker for typed package           |

## Architecture

Enforces a strict layered architecture:

```
┌─────────────────────────────┐
│  my_project.main            │  ← Top layer (entry point)
└─────────────┬───────────────┘
              │ can import from ↓
┌─────────────▼───────────────┐
│  my_project.utils           │  ← Bottom layer (foundational)
└─────────────────────────────┘
```

## Development Commands

```bash
# Run tests
uv run pytest

# Lint and format
uv run ruff check .
uv run ruff format .

# Type check
uv run pyright

# Check import layering
uv run lint-imports
```
