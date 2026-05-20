#!/usr/bin/env bash
# ──────────────────────────────────────────────
# regen-og-card.sh
# 用 Chrome headless 把 _og-card-source.html 截成
# images/og-card.png（1200×630），給 og:image / twitter:image 用。
#
# 用法：
#   ./regen-og-card.sh            生圖、不 commit
#   ./regen-og-card.sh --push     生圖、git commit、git push
#   ./regen-og-card.sh --open     生圖、然後用預設圖片檢視器打開
# ──────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")"

SRC="_og-card-source.html"
OUT="images/og-card.png"
SIZE="1200,630"

# ── 1. 找 Chrome / Edge ──
CHROME=""
for candidate in \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "$(command -v chromium 2>/dev/null || true)" \
  "$(command -v chrome 2>/dev/null || true)" \
  "$(command -v google-chrome 2>/dev/null || true)"; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    CHROME="$candidate"
    break
  fi
done

if [[ -z "$CHROME" ]]; then
  echo "❌ 找不到 Chrome / Edge。請手動指定 CHROME 環境變數。"
  exit 1
fi
echo "✓ Chrome：$CHROME"

# ── 2. 檢查來源檔 ──
if [[ ! -f "$SRC" ]]; then
  echo "❌ 找不到 $SRC"
  exit 1
fi

# ── 3. 計算 URL-encoded file:// URL（避開中文路徑問題）──
SRC_URL=$(python -c "import urllib.parse, os; p = os.path.abspath('$SRC').replace(chr(92), '/'); print('file:///' + urllib.parse.quote(p, safe='/:'))")
echo "✓ 來源 URL（縮）：…$(echo "$SRC_URL" | tail -c 60)"

# ── 4. 計算輸出 Windows 路徑（chrome 需要絕對 Windows 路徑）──
if command -v cygpath >/dev/null 2>&1; then
  OUT_WIN=$(cygpath -w "$(pwd)/$OUT")
else
  OUT_WIN="$(pwd)/$OUT"
fi
echo "✓ 輸出：$OUT_WIN"

# ── 5. 截圖 ──
echo "→ Chrome headless 截圖中（10 秒虛擬時間、等字型載入）..."
"$CHROME" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --hide-scrollbars \
  --window-size="$SIZE" \
  --virtual-time-budget=10000 \
  --screenshot="$OUT_WIN" \
  "$SRC_URL" 2>&1 | tail -3 || true

if [[ ! -f "$OUT" ]]; then
  echo "❌ 截圖失敗、$OUT 不存在"
  exit 1
fi

FILE_SIZE=$(wc -c < "$OUT" | tr -d ' ')
echo "✓ 完成：$OUT（${FILE_SIZE} bytes）"

# ── 6. 旗標：--open ──
if [[ " $* " == *" --open "* ]]; then
  echo "→ 打開圖片..."
  if command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe "$(cygpath -w "$(pwd)/$OUT")" || true
  elif command -v open >/dev/null 2>&1; then
    open "$OUT"
  else
    xdg-open "$OUT" 2>/dev/null || true
  fi
fi

# ── 7. 旗標：--push ──
if [[ " $* " == *" --push "* ]]; then
  echo ""
  echo "→ git add + commit + push..."
  git add "$OUT" "$SRC"
  if git diff --cached --quiet; then
    echo "  （無變更可 commit、跳過）"
  else
    git commit -m "chore: 更新 OG card

    重生 og-card.png（1200×630）。"
    git push origin HEAD
    echo "✓ 已 push、Pages 約 1-2 分鐘內重新部署"
    echo ""
    echo "★ FB 重抓快取："
    echo "   https://developers.facebook.com/tools/debug/sharing/"
    echo ""
    echo "★ 線上圖片："
    echo "   https://imnivek.github.io/404table-ea-vol01/images/og-card.png"
  fi
fi

echo ""
echo "Done."
