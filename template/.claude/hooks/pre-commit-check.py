"""Full checks: typecheck and import-linter before commits.

Blocking: exits 2 on failure to prevent bad commits.
"""

import json
import os
import re
import subprocess
import sys


def main() -> None:
    """Run comprehensive checks before git commits.

    Reads hook input from stdin, extracts the command, and runs pyright and
    import-linter if the command is a git commit. Exits 2 on failure to block
    the commit, 0 on success.
    """
    # Read JSON from stdin
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Extract command from tool_input
    tool_input = data.get("tool_input", {})
    command = tool_input.get("command", "")

    # Only run on git commit commands
    if not command or not re.match(r"^git\s+commit", command):
        sys.exit(0)

    # Get project directory
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        sys.exit(0)

    os.chdir(project_dir)

    errors = False

    # Run pyright
    result = subprocess.run(
        ["uv", "run", "pyright"],
        capture_output=False,
    )
    if result.returncode != 0:
        errors = True

    # Run import-linter
    result = subprocess.run(
        ["uv", "run", "lint-imports"],
        capture_output=False,
    )
    if result.returncode != 0:
        errors = True

    # Exit 2 to block the commit if any checks failed
    if errors:
        print(
            "Pre-commit checks failed. Fix errors above before committing.",
            file=sys.stderr,
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
