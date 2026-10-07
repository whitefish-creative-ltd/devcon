# Changelog

## 1.0.0 — 2026-10-07

- `devcon init` writes a project's `.devcontainer/devcontainer.json`: Claude Code installed, the sign-in kept in a per-account Docker volume (`-a` picks the account).
- `setup.sh install` links `devcon` into `~/.local/bin`, adds it to PATH if needed and installs DevPod (`--without-devpod` skips it); `setup.sh uninstall` removes it all again.
