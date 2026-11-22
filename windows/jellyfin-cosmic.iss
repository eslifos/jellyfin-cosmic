#ifndef AppVersion
  #error Falta AppVersion
#endif

[Setup]
AppId={{7E3F6C54-9A1B-4D2E-8C37-2B5A91D0C4E6}
AppName=Jellyfin Cosmic
AppVersion={#AppVersion}
AppPublisher=Jellyfin Cosmic
AppPublisherURL=https://github.com/eslifos/jellyfin-cosmic
DefaultDirName={autopf}\Jellyfin Cosmic
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=jellyfin-cosmic-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
UninstallDisplayName=Jellyfin Cosmic

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
spanish.OpenCosmic=Abrir Jellyfin Cosmic
english.OpenCosmic=Open Jellyfin Cosmic

[InstallDelete]
Type: filesandordirs; Name: "{app}\server"
Type: filesandordirs; Name: "{app}\web"
Type: filesandordirs; Name: "{app}\ffmpeg"

[Files]
Source: "payload\server\*"; DestDir: "{app}\server"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\web\*"; DestDir: "{app}\web"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\ffmpeg\*"; DestDir: "{app}\ffmpeg"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\winsw\JellyfinCosmicService.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\winsw\JellyfinCosmicService.xml"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\NOTICE.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Jellyfin Cosmic"; Filename: "http://localhost:8096"

[Run]
Filename: "{app}\JellyfinCosmicService.exe"; Parameters: "install"; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Jellyfin Cosmic"" dir=in action=allow program=""{app}\server\jellyfin.exe"" enable=yes profile=private,domain"; Flags: runhidden waituntilterminated
Filename: "{app}\JellyfinCosmicService.exe"; Parameters: "start"; Flags: runhidden waituntilterminated
Filename: "http://localhost:8096"; Description: "{cm:OpenCosmic}"; Flags: postinstall shellexec nowait skipifsilent

[UninstallRun]
Filename: "{app}\JellyfinCosmicService.exe"; Parameters: "stop"; Flags: runhidden waituntilterminated; RunOnceId: "StopService"
Filename: "{app}\JellyfinCosmicService.exe"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveService"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Jellyfin Cosmic"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveFirewall"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Service: String;
  Code: Integer;
begin
  Result := '';
  Service := ExpandConstant('{app}\JellyfinCosmicService.exe');
  if FileExists(Service) then
  begin
    Exec(Service, 'stop', '', SW_HIDE, ewWaitUntilTerminated, Code);
    Exec(Service, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, Code);
    Exec(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall delete rule name="Jellyfin Cosmic"', '', SW_HIDE, ewWaitUntilTerminated, Code);
  end;
end;
