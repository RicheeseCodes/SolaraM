#!/bin/bash
set -euo pipefail
clear

bash <(curl -fsSL "https://raw.githubusercontent.com/RicheeseCodes/SolaraM/refs/heads/main/opiumware-install.sh")

REPO="RicheeseCodes/SolaraM"
TAG="Releases"

echo "🚀 Solara Installer"
echo "===================="

OS_VERSION=$(sw_vers -productVersion | cut -d. -f1,2)
ARCH=$(uname -m)

# Catalina detection (10.15)
if [[ "$OS_VERSION" == "10.15" ]]; then
  ASSET_NAME="Solara-catalina.zip"
  echo "Detected: macOS Catalina ($OS_VERSION)"
else
  case "$ARCH" in
    arm64|aarch64)
      ASSET_NAME="Solara-arm64.zip"
      echo "Detected: Apple Silicon ($ARCH)"
      ;;
    x86_64|amd64)
      ASSET_NAME="Solara-x86_64.zip"
      echo "Detected: Intel ($ARCH)"
      ;;
    *)
      echo "❌ Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
fi

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET_NAME"

TMP_ZIP="/tmp/$ASSET_NAME"
TMP_DIR=$(mktemp -d)

echo "🔗 Downloading: $DOWNLOAD_URL"
curl -fL "$DOWNLOAD_URL" -o "$TMP_ZIP" || {
  echo "❌ Download failed."
  exit 1
}

echo "📦 Extracting ZIP..."
unzip -q "$TMP_ZIP" -d "$TMP_DIR"

APP_SRC=$(find "$TMP_DIR" -maxdepth 2 -name "Solara.app" -type d | head -n 1)

if [ -z "$APP_SRC" ]; then
  echo "❌ Solara.app not found in ZIP"
  exit 1
fi

if [ -d "/Applications/Solara.app" ]; then
  echo "♻️ Removing existing installation..."
  rm -rf /Applications/Solara.app
fi

echo "💾 Installing..."
if [ -w /Applications ]; then
  cp -R "$APP_SRC" /Applications/
else
  sudo cp -R "$APP_SRC" /Applications/
fi

echo "🛡️ Removing quarantine flags..."
xattr -rd com.apple.quarantine /Applications/Solara.app 2>/dev/null || true

echo "🔐 Setting up Solara key system..."
SOLARA_APP="/Applications/Solara.app"
SOLARA_INFO_PLIST="$SOLARA_APP/Contents/Info.plist"
SOLARA_EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$SOLARA_INFO_PLIST")
SOLARA_EXEC_PATH="$SOLARA_APP/Contents/MacOS/$SOLARA_EXEC_NAME"
SOLARA_REAL_EXEC="$SOLARA_APP/Contents/MacOS/${SOLARA_EXEC_NAME}.real"

if [ ! -f "$SOLARA_REAL_EXEC" ]; then
  mv "$SOLARA_EXEC_PATH" "$SOLARA_REAL_EXEC"
fi

cat > "$SOLARA_EXEC_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail

APP_NAME="Solara"
KEYSERVER_URL="https://spryzen-keyserver-production.up.railway.app"
GET_KEY_URL="${KEYSERVER_URL}/get-key"
KEY_TTL_SECONDS=21600
KEY_MESSAGE="Enter your Solara key."

KEY_STORE_DIR="$HOME/Library/Application Support/Solara"
KEY_STORE_FILE="$KEY_STORE_DIR/key.txt"

EXEC_DIR="$(dirname "$0")"
EXEC_NAME="$(basename "$0")"
REAL_EXEC="$EXEC_DIR/${EXEC_NAME}.real"

now_ts() {
  date +%s
}

show_alert() {
  /usr/bin/osascript -e 'display dialog "'"$1"'" buttons {"OK"} default button "OK"'
}

verify_key_remote() {
  local key="$1"
  local resp
  resp=$(/usr/bin/curl -fsS "${KEYSERVER_URL}/api/verify?key=${key}" 2>/dev/null || true)
  case "$resp" in
    OK) return 0 ;;
    EXPIRED) show_alert "Key expired. Get a new key."; return 1 ;;
    DISABLED) show_alert "Key system disabled. Try again later."; return 1 ;;
    "") show_alert "Unable to reach key server."; return 1 ;;
    *) show_alert "Incorrect key."; return 1 ;;
  esac
}

load_saved_key() {
  if [ -f "$KEY_STORE_FILE" ]; then
    IFS='|' read -r SAVED_KEY SAVED_TS < "$KEY_STORE_FILE" || true
  fi
}

save_key() {
  local key="$1"
  local ts="$2"
  mkdir -p "$KEY_STORE_DIR"
  printf "%s|%s" "$key" "$ts" > "$KEY_STORE_FILE"
  chmod 600 "$KEY_STORE_FILE" 2>/dev/null || true
}

schedule_quit() {
  local remaining="$1"
  if [ "$remaining" -gt 0 ] 2>/dev/null; then
    (sleep "$remaining"; /usr/bin/osascript -e 'tell application "'"$APP_NAME"'" to quit' >/dev/null 2>&1) &
  fi
}

prompt_for_key() {
  while true; do
    response=$(/usr/bin/osascript -e 'set dlg to display dialog "'"$KEY_MESSAGE"'" default answer "" buttons {"Get Key","Submit","Cancel"} default button "Submit" cancel button "Cancel"
set btn to button returned of dlg
set txt to text returned of dlg
return btn & "||" & txt')
    btn="${response%%||*}"
    text="${response#*||}"
    case "$btn" in
      "Get Key")
        /usr/bin/open "$GET_KEY_URL"
        continue
        ;;
      "Cancel")
        exit 1
        ;;
      "Submit")
        if [ -z "$text" ]; then
          show_alert "Enter a key."
          continue
        fi
        if verify_key_remote "$text"; then
          now="$(now_ts)"
          save_key "$text" "$now"
          schedule_quit "$KEY_TTL_SECONDS"
          break
        fi
        ;;
      *)
        exit 1
        ;;
    esac
  done
}

SAVED_KEY=""
SAVED_TS=""
load_saved_key
now="$(now_ts)"
if [ -n "$SAVED_KEY" ] && [ -n "$SAVED_TS" ]; then
  age=$((now - SAVED_TS))
  if [ "$age" -lt "$KEY_TTL_SECONDS" ]; then
    if verify_key_remote "$SAVED_KEY"; then
      remaining=$((KEY_TTL_SECONDS - age))
      schedule_quit "$remaining"
      exec "$REAL_EXEC" "$@"
    else
      rm -f "$KEY_STORE_FILE" 2>/dev/null || true
    fi
  else
    rm -f "$KEY_STORE_FILE" 2>/dev/null || true
  fi
fi

prompt_for_key
exec "$REAL_EXEC" "$@"
EOF

chmod +x "$SOLARA_EXEC_PATH"
codesign --force --deep --sign - "$SOLARA_APP" >/dev/null 2>&1 || true

echo "🧹 Cleaning up..."
rm -rf "$TMP_DIR" "$TMP_ZIP"

echo ""
echo "✅ Solara installed successfully!"
open -a /Applications/Solara.app

RESET="\033[0m"
ART_COLOR="\033[35m"
COLORS=( "\033[31m" "\033[32m" "\033[33m" "\033[34m" "\033[35m" "\033[36m" "\033[37m" )

print_color() {
  local color="$1"
  shift
  printf "%b%s%b\n" "$color" "$*" "$RESET"
}

ART_LINES=(
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@**********@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@***@**@@@****--        --------***@@@@@@**@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@**-----------------*****************---*@@@@@***@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@****--        --**@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*---@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@**---       -***@@@@@@@@@@@@@@@@************@@@@@@*-*--@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@**-    --****************----        -----*@@@@@@@@----*@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@*--- --**@@@@@**-              -----------*@@@@@@@@*----*@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@*-----**@@@@@@@@@@**--      ------*********@@@@@@@@*-----*@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@*-----*@@@@@@@@@@@@@@*--     -**@@@@@@@@@@@@@@@@***--   -**@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@*-----@@@@@@@@@@@@@@@* --    -*@*@@@@@***@@@@@@**-      -**@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@-----@@@@@@@@@@@@@@@*- ----------  ----*@@@@@@*-      --*@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@*-@@@@----*@@@@@@@@@@@@@@*- ---------------*@@@@**-    ------**@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@-**@@@*----@@@@@@@@@@@@@**  -----******@@**@**------**********@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@---**@@@*****@@@@@@@@@@@*- ------*@@@@@@**-----***@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@------*****--****@@@@@@* ------*@***----****@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@*--           ----**@* ----**-@******@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@***---      ----**@----***-@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@**********@@@@* -******@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ -*****@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@--***@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@* **@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
)

for line in "${ART_LINES[@]}"; do
  print_color "$ART_COLOR" "$line"
done

echo ""

POEM_LINES=(
"Freedom"
""
"Freedom will not wait"
"For a kinder tomorrow."
""
"It grows in quiet hearts"
"That refuse to bow to fear."
""
"I stand on this same ground,"
"Under this same sky."
"My breath, my voice, my life"
"Are not less than yours."
""
"Life teaches only one truth:"
"The day you rise and speak"
"Is the day you begin to live."
""
"Freedom is not given."
"It is lived."
""
"— Ryu ✦"
)

color_index=0
for line in "${POEM_LINES[@]}"; do
  if [ -z "$line" ]; then
    echo ""
    continue
  fi
  color="${COLORS[$((color_index % ${#COLORS[@]}))]}"
  print_color "$color" "$line"
  color_index=$((color_index + 1))
done
