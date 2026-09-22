; ==============================================================================
; Script Inno Setup Compiler 6.x - Estética Lupatini
; Empacota o build Windows Release em um instalador autônomo .exe
; ==============================================================================

#define MyAppName "Estética Lupatini"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Estética Lupatini"
#define MyAppURL "https://esteticalupatini.com"
#define MyAppExeName "estetica_lupatini.exe"
#define MyBuildSourceDir "..\frontend\build\windows\x64\runner\Release"

[Setup]
; Identificador GUID único do produto
AppId={{B58E9A34-9A4E-45E9-99E7-7D012B588157}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\EsteticaLupatini
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Local onde será gerado o instalador final
OutputDir=..\dist
OutputBaseFilename=Estetica_Lupatini_Setup
SetupIconFile=..\frontend\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Todos os arquivos binários e assets compilados pelo Flutter Windows Release
Source: "{#MyBuildSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall skipifsilent
