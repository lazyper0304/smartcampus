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

; 应用内置 WebView（flutter_inappwebview）依赖 Microsoft Edge WebView2 Runtime，
; 系统缺失时 App 打开 WebView 会 native 崩溃闪退。此处检测注册表，缺失时
; 自动下载官方 bootstrapper 并静默安装（Evergreen 模式，自动跟随更新）。
[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; Flags: runascurrentuser skipifdoesntexist; Check: not IsWebView2Installed

[Code]
function IsWebView2Installed: Boolean;
var
  v: string;
begin
  Result := RegQueryStringValue(
      HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', v)
    or RegQueryStringValue(
      HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', v);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  DownloadedFile: String;
begin
  Result := '';
  if not IsWebView2Installed then
  begin
    if not DownloadTemporaryFile(
        'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
        'MicrosoftEdgeWebview2Setup.exe', '', DownloadedFile) then
      Result := '下载 WebView2 运行时失败。请安装 Microsoft Edge WebView2 后重新启动应用：' +
        'https://developer.microsoft.com/microsoft-edge/webview2/';
  end;
end;

