# ──────────────────────────────────────────────
# regen-og-card.ps1
# 用 Chrome headless 把 _og-card-source.html 截成
# images/og-card.png（1200×630），給 og:image / twitter:image 用。
#
# 用法（在這個資料夾開 PowerShell）：
#   .\regen-og-card.ps1            生圖、不 commit
#   .\regen-og-card.ps1 -Push      生圖、git commit、git push
#   .\regen-og-card.ps1 -Open      生圖、然後用預設圖片檢視器打開
# ──────────────────────────────────────────────
param(
  [switch]$Push,
  [switch]$Open
)

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

$Src = '_og-card-source.html'
$Out = 'images\og-card.png'
$Size = '1200,630'

# ── 1. 找 Chrome / Edge ──
$candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)
$Chrome = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Chrome) {
  Write-Host '❌ 找不到 Chrome / Edge。請手動編輯 $Chrome 變數。' -ForegroundColor Red
  exit 1
}
Write-Host "✓ Chrome：$Chrome" -ForegroundColor Green

# ── 2. 檢查來源檔 ──
if (-not (Test-Path $Src)) {
  Write-Host "❌ 找不到 $Src" -ForegroundColor Red
  exit 1
}

# ── 3. file:// URL ──
Add-Type -AssemblyName System.Web
$SrcAbs = (Resolve-Path $Src).Path
$SrcUrl = 'file:///' + [System.Web.HttpUtility]::UrlPathEncode($SrcAbs.Replace('\','/'))
Write-Host ("✓ 來源 URL：…" + $SrcUrl.Substring([Math]::Max(0, $SrcUrl.Length - 60))) -ForegroundColor Green

# ── 4. 輸出絕對路徑 ──
$OutAbs = Join-Path (Get-Location) $Out
$OutDir = Split-Path $OutAbs -Parent
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
Write-Host "✓ 輸出：$OutAbs" -ForegroundColor Green

# ── 5. 截圖 ──
Write-Host '→ Chrome headless 截圖中（10 秒虛擬時間、等字型載入）...' -ForegroundColor Cyan
& $Chrome `
  --headless=new `
  --disable-gpu `
  --no-sandbox `
  --hide-scrollbars `
  --window-size=$Size `
  --virtual-time-budget=10000 `
  "--screenshot=$OutAbs" `
  $SrcUrl 2>&1 | Select-Object -Last 3

if (-not (Test-Path $Out)) {
  Write-Host "❌ 截圖失敗、$Out 不存在" -ForegroundColor Red
  exit 1
}
$FileSize = (Get-Item $Out).Length
Write-Host "✓ 完成：$Out（$FileSize bytes）" -ForegroundColor Green

# ── 6. -Open ──
if ($Open) {
  Write-Host '→ 打開圖片...' -ForegroundColor Cyan
  Start-Process $OutAbs
}

# ── 7. -Push ──
if ($Push) {
  Write-Host ''
  Write-Host '→ git add + commit + push...' -ForegroundColor Cyan
  git add $Out $Src
  git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) {
    Write-Host '  （無變更可 commit、跳過）'
  } else {
    git commit -m @'
chore: 更新 OG card

重生 og-card.png（1200×630）。
'@
    git push origin HEAD
    Write-Host '✓ 已 push、Pages 約 1-2 分鐘內重新部署' -ForegroundColor Green
    Write-Host ''
    Write-Host '★ FB 重抓快取：' -ForegroundColor Yellow
    Write-Host '   https://developers.facebook.com/tools/debug/sharing/'
    Write-Host ''
    Write-Host '★ 線上圖片：' -ForegroundColor Yellow
    Write-Host '   https://imnivek.github.io/404table-ea-vol01/images/og-card.png'
  }
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
