; RoutaMi for Windows (x64). Built by .github/workflows/release.yml:
;   iscc /DAppVersion=0.4.0 /DSourceDir=<flutter Release dir> /DOutputName=<name> routami.iss
; Installs per machine into Program Files: the TUN helper service runs as
; LocalSystem and refuses any directory a user can write to.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputName
  #define OutputName "RoutaMi-windows-x64-setup"
#endif

[Setup]
AppId={{8C1E6B52-6A0D-4E0B-9C51-7E3F4A2D9B61}
AppName=RoutaMi
AppVersion={#AppVersion}
AppPublisher=RoutaTerm
AppPublisherURL=https://github.com/Ametas/routa-mi
DefaultDirName={autopf}\RoutaMi
DefaultGroupName=RoutaMi
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\..\dist
OutputBaseFilename={#OutputName}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\RoutaMi.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\RoutaMi"; Filename: "{app}\RoutaMi.exe"
Name: "{autodesktop}\RoutaMi"; Filename: "{app}\RoutaMi.exe"; Tasks: desktopicon

[Run]
; An existing helper is re-registered so it runs the new binary and core.
Filename: "{app}\RoutaMiHelperService.exe"; Parameters: "install"; Flags: runhidden waituntilterminated; Check: HelperWasInstalled
Filename: "{app}\RoutaMi.exe"; Description: "{cm:LaunchProgram,RoutaMi}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Lite mode's tray keeps the core and its own files open.
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM RoutaMiTray.exe"; Flags: runhidden waituntilterminated; RunOnceId: "StopLiteTray"
Filename: "{app}\RoutaMiHelperService.exe"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveHelper"

[Code]
var
  HelperInstalled: Boolean;

function HelperWasInstalled: Boolean;
begin
  Result := HelperInstalled;
end;

// The helper service and the core it runs lock files in {app}: stop them
// before the files are replaced.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  HelperInstalled := Exec(ExpandConstant('{sys}\sc.exe'), 'query RoutaMiHelperService', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  if HelperInstalled then
  begin
    Exec(ExpandConstant('{sys}\sc.exe'), 'stop RoutaMiHelperService', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode);
    Sleep(1500);
  end;
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM RoutaMi.exe', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM RoutaMiTray.exe', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM RoutaMiCore.exe', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  Result := '';
end;
