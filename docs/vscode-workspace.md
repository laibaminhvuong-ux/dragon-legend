# Live shared project in Windows VS Code

Both agents' work is already combined in `/home/laptop_usd/dragon-ball`. This is the live source project, not the separate Downloads snapshot.

The root `dragon ball project.code-workspace` now uses the ordinary Windows filesystem path:

```text
\\wsl.localhost\Ubuntu\home\laptop_usd\dragon-ball
```

It uses `path`, not a `vscode-remote` URI, so viewing the source does not depend on VS Code's WSL filesystem provider. Ubuntu must be running and the UNC path accessible from Windows. Windows verification tasks invoke `wsl.exe -d Ubuntu --cd /home/laptop_usd/dragon-ball` directly.

To put the prepared workspace in Downloads and open it, run in Windows PowerShell:

```powershell
Copy-Item -LiteralPath '\\wsl.localhost\Ubuntu\home\laptop_usd\dragon-ball\dragon ball project.code-workspace' -Destination "$env:USERPROFILE\Downloads\dragon ball project.code-workspace" -Force
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe" --new-window "$env:USERPROFILE\Downloads\dragon ball project.code-workspace"
```

VS Code will show the shared repository in Explorer. Codex's rules/data/network work is in `godot/rules/`, `godot/data/` and `godot/network/`; Claude's characters/animation/UI/scenes are in `godot/characters/`, `godot/ui/` and `godot/scenes/`. `COLLABORATION.md` records ownership and current handoffs. These are separate source modules in one project; they should not be pasted into one code file.

Use File > Open Folder with the same UNC path as an alternative. The source ZIP previously prepared in the Linux home folder is a separate snapshot and contains its own folder-relative workspace for local extraction.

This Codex session cannot write Windows Downloads or launch VS Code because the Windows mount/launcher are restricted. The workspace JSON and source paths are verified here; opening the native Windows editor must be done from Windows or Claude's unrestricted session. No extensions or account settings were changed.
