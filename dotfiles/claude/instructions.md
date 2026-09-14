# Tmux Window Management

When running inside a tmux session, automatically manage the window name:

- Always use "claude-" prefix followed by 2-3 words separated by dashes
- Update the window name ONLY when the topic changes significantly:
  - After `/clear` command is used
  - When starting a new task or issue
  - When making significant progress on a task
  - When switching between different work contexts
- Use the command: `tmux rename-window "name-here"`
- Do it silently without announcing the rename to the user
- Keep names concise and descriptive of the current work

Initial name: "claude-code"
