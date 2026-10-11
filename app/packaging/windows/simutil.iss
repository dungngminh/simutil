; Inno Setup script for the SimUtil desktop app.
; Build: flutter build windows --release, then from the repository root:
;   iscc /DAppVersion=0.1.0 app\packaging\windows\simutil.iss
; Output: app\build\installer\SimUtil-windows-x64-setup.exe

#define AppName "SimUtil"
#define AppExe "simutil_app.exe"
#define Winget "{localappdata}\Microsoft\WindowsApps\winget.exe"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change AppId: upgrades and winget match installs by it.
AppId={{61B029AD-0D07-48F5-AF2B-BD7A168FF879}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=dungngminh
AppPublisherURL=https://github.com/dungngminh/simutil
AppSupportURL=https://github.com/dungngminh/simutil/issues
; Per-user install into %LOCALAPPDATA%\Programs; no UAC prompt.
DefaultDirName={autopf}\{#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\installer
OutputBaseFilename=SimUtil-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
LicenseFile=..\..\..\LICENSE

[Tasks]
Name: "tools"; Description: "Install adb (Android platform-tools) and FFmpeg with winget"; GroupDescription: "Tools SimUtil uses:"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Interactive installs only: under `winget install` the manifest's
; Dependencies cover this, and a nested winget call would wait on the outer
; one forever. winget skips packages that are already installed.
Filename: "{#Winget}"; Parameters: "install --id Google.PlatformTools --exact --silent --accept-package-agreements --accept-source-agreements"; StatusMsg: "Installing adb..."; Flags: runhidden skipifsilent; Tasks: tools; Check: FileExists(ExpandConstant('{#Winget}'))
Filename: "{#Winget}"; Parameters: "install --id Gyan.FFmpeg --exact --silent --accept-package-agreements --accept-source-agreements"; StatusMsg: "Installing FFmpeg..."; Flags: runhidden skipifsilent; Tasks: tools; Check: FileExists(ExpandConstant('{#Winget}'))
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
