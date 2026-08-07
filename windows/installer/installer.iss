; 宜院宾果 Windows 安装包脚本（Inno Setup 6）
; 编译：ISCC.exe /DAppVersion=1.1.9 windows\installer\installer.iss
; ⚠️ 本文件必须以 UTF-8 with BOM 保存（含中文 AppName）

#ifndef AppVersion
  #define AppVersion "1.1.9"
#endif

#define MyAppName "宜院宾果"
#define MyAppExe "smartcampus.exe"

[Setup]
AppId={{3F7C2B8E-4A1D-4E9B-9C0A-2D5E6F7A8B90}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher=lazy波斯猫
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; 产物文件名保持 ASCII（GitHub Actions upload-artifact 对中文名匹配失败）
OutputDir=..\..\build\installer
OutputBaseFilename=smartcampus-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
WizardStyle=modern
; 每用户安装（免 UAC），目录落到 %LOCALAPPDATA%\Programs\宜院宾果
PrivilegesRequired=lowest

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon
