# Shared VS Code workspace

Open `dragon ball project.code-workspace` from the repository root. It includes the complete, existing game project: both Codex and Claude edit these same files.

From a WSL terminal:

```sh
cd ~/dragon-ball
code "dragon ball project.code-workspace"
```

If opening from Windows, use VS Code's WSL connection for this Linux project so its Bash/Node/Godot tasks run in the correct environment.

- Codex rules/data/network: `godot/rules/`, `godot/data/`, `godot/network/`, `tools/` and their tests.
- Claude characters/animation/UI/scenes: `godot/characters/`, `godot/ui/`, `godot/scenes/` and their tests.
- Shared ownership and handoffs: `COLLABORATION.md`; detailed contracts/designs: `docs/`.
- Godot project: `godot/project.godot`.

Use **Terminal → Run Task** to run the existing headless suite/data check or verify generated data. These tasks do not build installers or publish anything. The workspace hides editor caches and node_modules, while source files remain visible.

This workspace does not install or sign in to AI extensions. The actual source code from both agents is already included through the shared repository folder.
