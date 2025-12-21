"""Fast checks: format and lint Python files after edits.

Non-blocking: always exits 0 to allow auto-fixes.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def main() -> None:
    """Run fast formatting and linting checks on edited Python files.

    Reads hook input from stdin, extracts the file path, and runs ruff format
    and ruff check --fix on Python files. Always exits 0 (non-blocking) to
    allow auto-fixes without interrupting the workflow.
    """
    # Read JSON from stdin
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Extract file_path from tool_input
    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    # Only process Python files
    if not file_path or not file_path.endswith(".py"):
        sys.exit(0)

    # Get project directory
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        sys.exit(0)

    # Make path absolute if relative
    if not os.path.isabs(file_path):
        file_path = os.path.join(project_dir, file_path)

    # Check file exists
    if not Path(file_path).exists():
        sys.exit(0)

    # Run ruff format and check --fix (non-blocking, ignore errors)
    os.chdir(project_dir)

    subprocess.run(
        ["uv", "run", "ruff", "format", file_path],
        capture_output=True,
    )
    subprocess.run(
        ["uv", "run", "ruff", "check", "--fix", file_path],
        capture_output=True,
    )

    # Always exit 0 - these are auto-fixes, not blockers
    sys.exit(0)


if __name__ == "__main__":
    main()
