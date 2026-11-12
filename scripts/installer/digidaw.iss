; Inno Setup script for the Windows installer. build_windows.ps1 compiles it with ISCC after the
; release bundle is built:
;
;   ISCC.exe /DAppVersion=<version> /DBundleDir=<bundle> /DOutputDir=<dist> scripts\installer\digidaw.iss
;
; It installs the whole bundle (karbeat.exe, its DLLs including the Visual C++ runtime, and the
; data folder) into one folder, Program Files\DigiDAW by default, adds Start menu and optional
; desktop shortcuts, and registers an uninstaller. Settings and crash recovery data live in the
; user's AppData and are kept on uninstall.

#ifndef AppVersion
  #error AppVersion must be defined, e.g. /DAppVersion=0.8.2
#endif
#ifndef BundleDir
  #error BundleDir must be defined: the flutter build windows Release folder
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

#define AppName "DigiDAW"
#define AppExe "karbeat.exe"

[Setup]
; Identifies the installation for upgrades and uninstall. Never change it.
AppId={{B3895FEA-7651-47A2-9F55-BAD84AC1486E}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
AppPublisherURL=https://github.com/nazhifhaidarputra/digidaw
AppSupportURL=https://github.com/nazhifhaidarputra/digidaw/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE.txt
OutputDir={#OutputDir}
OutputBaseFilename=digidaw-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; 64-bit only, installed into Program Files rather than Program Files (x86).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; Program Files needs administrator rights.
PrivilegesRequired=admin
; Stop a running DigiDAW before replacing its files.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; An upgrade replaces the bundle as a whole, so files a newer version dropped do not linger.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
