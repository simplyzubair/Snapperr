#define AppName "Snapperr"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6E2B7C1A-4F3D-4E8B-9A51-2C7D0B8F5A13}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Zubair
AppPublisherURL=https://github.com/simplyzubair/Snapperr
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Snapperr-Setup-{#AppVersion}
UninstallDisplayIcon={app}\Snapperr.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no
LicenseFile=..\LICENSE

[Files]
Source: "..\build\Snapperr.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\{#AppName}"; Filename: "{app}\Snapperr.exe"
Name: "{userprograms}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\Snapperr.exe"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\Snapperr.exe"; Flags: nowait

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM Snapperr.exe"; Flags: runhidden; RunOnceId: "StopSnapperr"
