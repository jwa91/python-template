"""Full checks: typecheck and import-linter before commits.

Blocking: returns permission deny on failure to prevent bad commits.
"""

import json
import os
import re
import subprocess
import sys


def main() -> None:
    """Run comprehensive checks before git commits.

    Reads hook input from stdin (Cursor format), extracts the command, and
    runs pyright and import-linter if the command is a git commit. Returns
    permission deny on failure to block the commit, allow on success.
    """
    # Read JSON from stdin
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # If we can't parse input, allow the command
        print(json.dumps({"permission": "allow"}))
        sys.exit(0)

    # Extract command from Cursor's input format
    command = data.get("command", "")

    # Only run on git commit commands
    if not command or not re.match(r"^git\s+commit", command):
        print(json.dumps({"permission": "allow"}))
        sys.exit(0)

    # Get project directory from workspace_roots (Cursor format)
    workspace_roots = data.get("workspace_roots", [])
    if not workspace_roots:
        print(json.dumps({"permission": "allow"}))
        sys.exit(0)

    # Use first workspace root as project directory
    project_dir = workspace_roots[0]
    os.chdir(project_dir)

    errors = False
    error_messages = []

    # Run pyright
    result = subprocess.run(
        ["uv", "run", "pyright"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        errors = True
        if result.stderr:
            error_messages.append("Pyright errors found. See output above.")

    # Run import-linter
    result = subprocess.run(
        ["uv", "run", "lint-imports"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        errors = True
        if result.stderr:
            error_messages.append("Import linter errors found. See output above.")

    # Return permission deny to block the commit if any checks failed
    if errors:
        user_message = "Pre-commit checks failed. Fix errors above before committing."
        if error_messages:
            user_message += " " + " ".join(error_messages)

        # Output JSON response for Cursor
        response = {
            "permission": "deny",
            "user_message": user_message,
        }
        print(json.dumps(response))
        sys.exit(0)

    # All checks passed, allow the commit
    print(json.dumps({"permission": "allow"}))
    sys.exit(0)


if __name__ == "__main__":
    main()

