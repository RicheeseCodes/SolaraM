#!/bin/bash
set -euo pipefail

SOLARA_APP="/Applications/Solara.app"
if [ ! -d "$SOLARA_APP" ]; then
  echo "❌ Solara.app not found at /Applications/Solara.app"
  exit 1
fi

SOLARA_INFO_PLIST="$SOLARA_APP/Contents/Info.plist"
SOLARA_EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$SOLARA_INFO_PLIST")
if [ -z "$SOLARA_EXEC_NAME" ]; then
  echo "❌ CFBundleExecutable not found in Info.plist"
  exit 1
fi

SOLARA_EXEC_PATH="$SOLARA_APP/Contents/MacOS/$SOLARA_EXEC_NAME"
SOLARA_REAL_EXEC="$SOLARA_APP/Contents/MacOS/${SOLARA_EXEC_NAME}.real"

if [ ! -f "$SOLARA_REAL_EXEC" ]; then
  if [ ! -f "$SOLARA_EXEC_PATH" ]; then
    echo "❌ Solara executable not found at $SOLARA_EXEC_PATH"
    exit 1
  fi
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
xattr -rd com.apple.quarantine "$SOLARA_APP" 2>/dev/null || true
codesign --force --deep --sign - "$SOLARA_APP" >/dev/null 2>&1 || true
touch "$SOLARA_APP"

echo "✅ Solara key system fixed. Quit Solara and open it again."
