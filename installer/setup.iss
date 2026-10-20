; Inno Setup betigi - Windows kurulum dosyasi (IPTVPro-Setup.exe) uretir.
; Derleme: iscc installer\setup.iss  (once "flutter build windows --release" calistirilmali)

#define MyAppName "IPTV Pro"
#define MyAppVersion "1.0.0"
#define MyAppExe "iptv_pro.exe"
#define SrcDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B7A1C2D4-5E6F-4A8B-9C0D-1E2F3A4B5C6D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\dist
OutputBaseFilename=IPTVPro-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExe}

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne kısayol oluştur"; GroupDescription: "Ek görevler:"

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "IPTV Pro'yu başlat"; Flags: nowait postinstall skipifsilent
