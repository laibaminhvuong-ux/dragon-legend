; Windows installer for the Godot build (Inno Setup 6). CI runs: iscc /DVERSION=0.0.3 tools\installer.iss
; Installs per user (no admin), adds Start menu + desktop shortcuts, and keeps saves (%APPDATA%\DragonLegend) on uninstall.
#ifndef VERSION
  #define VERSION "0.0.0"
#endif
[Setup]
AppId={{6E3C1D52-9A0F-4B7E-9C51-3D7A1E0F2B64}
AppName=The Dragon Legend
AppVersion={#VERSION}
AppPublisher=laibaminhvuong
DefaultDirName={localappdata}\Programs\The Dragon Legend
DefaultGroupName=The Dragon Legend
PrivilegesRequired=lowest
OutputDir=..\build\installer
OutputBaseFilename=Dragon-Legend-Setup
SetupIconFile=..\godot\icon.ico
UninstallDisplayIcon={app}\The Dragon Legend.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes

[Files]
Source: "..\build\windows\The Dragon Legend.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\The Dragon Legend"; Filename: "{app}\The Dragon Legend.exe"
Name: "{autodesktop}\The Dragon Legend"; Filename: "{app}\The Dragon Legend.exe"

[Run]
Filename: "{app}\The Dragon Legend.exe"; Description: "Play The Dragon Legend"; Flags: nowait postinstall skipifsilent
