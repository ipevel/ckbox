# 用自签 Authenticode 证书给 Windows 产物签名。
#
# 凭据来自 GitHub Secrets：
#   CKBOX_WIN_SIGN_PFX_BASE64  → 由 workflow 解码后放入 WIN_SIGN_PFX_PATH
#   CKBOX_WIN_SIGN_PFX_PASSWORD→ 放入 WIN_SIGN_PFX_PASSWORD
#
# 用法：./sign-windows.ps1 <文件或目录> [...]
# 目录会展开为其下的 *.exe（不递归）。
param(
  [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]] $Targets
)

$ErrorActionPreference = 'Stop'

function Find-SignTool {
  $roots = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
    "$env:ProgramFiles\Windows Kits\10\bin"
  ) | Where-Object { Test-Path $_ }

  foreach ($root in $roots) {
    foreach ($sub in @('x64', 'arm64')) {
      $found = Get-ChildItem -Path $root -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName (Join-Path $sub 'signtool.exe') } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
      if ($found) { return $found }
    }
  }
  throw 'signtool.exe 未找到：runner 上缺少 Windows SDK。'
}

$pfxPath = $env:WIN_SIGN_PFX_PATH
$pfxPassword = $env:WIN_SIGN_PFX_PASSWORD
if ([string]::IsNullOrWhiteSpace($pfxPath) -or -not (Test-Path $pfxPath)) {
  throw "签名证书不存在：WIN_SIGN_PFX_PATH=$pfxPath"
}
if ([string]::IsNullOrWhiteSpace($pfxPassword)) {
  throw '签名证书密码为空：WIN_SIGN_PFX_PASSWORD 未注入。'
}

$signTool = Find-SignTool
Write-Host "signtool: $signTool"

$files = @()
foreach ($target in $Targets) {
  if (-not (Test-Path $target)) { throw "待签名路径不存在：$target" }
  if ((Get-Item $target).PSIsContainer) {
    $files += Get-ChildItem -Path $target -Filter *.exe -File | ForEach-Object { $_.FullName }
  } else {
    $files += (Get-Item $target).FullName
  }
}
if ($files.Count -eq 0) { throw '没有可签名的文件。' }

foreach ($file in $files) {
  Write-Host "--- 签名 $file"
  & $signTool sign /f $pfxPath /p $pfxPassword /fd SHA256 /a $file
  if ($LASTEXITCODE -ne 0) { throw "签名失败：$file (exit $LASTEXITCODE)" }

  # 自签根不在 runner 信任库，链校验必然不通过，因此这里只审计不判定失败。
  $sig = Get-AuthenticodeSignature -FilePath $file
  Write-Host "    状态=$($sig.Status) 主体=$($sig.SignerCertificate.Subject)"
  if (-not $sig.SignerCertificate) { throw "签名未写入：$file" }
}

Write-Host "已完成 $($files.Count) 个文件的签名。"
