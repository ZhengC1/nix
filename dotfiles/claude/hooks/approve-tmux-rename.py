#!/usr/bin/env python3
"""PreToolUse(Bash) hook: auto-approve `tmux rename-window` so Claude can keep
the tmux window name in sync with the current task without a permission prompt.

Every other command falls through to the normal permission flow.
"""
import json
import sys


def main():
    try:
        hook_input = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        print("{}")
        return

    if hook_input.get("tool_name") == "Bash":
        command = (hook_input.get("tool_input") or {}).get("command", "").strip()

        if command.startswith("tmux rename-window"):
            print(json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "permissionDecisionReason": "tmux rename-window auto-approved",
                }
            }))
            return

    # No decision -- normal permission flow.
    print("{}")


if __name__ == "__main__":
    main()
