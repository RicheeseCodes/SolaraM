#!/bin/bash
set -euo pipefail

APP_NAME="Solara Management"
KEY_MESSAGE="Dont uninstall it and no need to open it just tap cancel and enjoy using the executor just use solara"
KEY_REQUIRED="key/0001"

APP_PATH=""
if [ -d "/Applications/${APP_NAME}.app" ]; then
  APP_PATH="/Applications/${APP_NAME}.app"
elif [ -d "$HOME/Applications/${APP_NAME}.app" ]; then
  APP_PATH="$HOME/Applications/${APP_NAME}.app"
fi

if [ -z "$APP_PATH" ]; then
  echo "❌ ${APP_NAME}.app not found in /Applications or ~/Applications"
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
EXEC_PATH="$APP_PATH/Contents/MacOS/$EXEC_NAME"
REAL_EXEC="$APP_PATH/Contents/MacOS/${EXEC_NAME}.real"

if [ ! -f "$REAL_EXEC" ]; then
  if [ ! -f "$EXEC_PATH" ]; then
    echo "❌ Executable not found at $EXEC_PATH"
    exit 1
  fi
  mv "$EXEC_PATH" "$REAL_EXEC"
fi

cat > "$EXEC_PATH" <<EOF
#!/bin/bash
set -euo pipefail

KEY_REQUIRED="${KEY_REQUIRED}"
KEY_MESSAGE="${KEY_MESSAGE}"

EXEC_DIR="\$(dirname "\$0")"
EXEC_NAME="\$(basename "\$0")"
REAL_EXEC="\$EXEC_DIR/\${EXEC_NAME}.real"

if ! input=\$(/usr/bin/osascript -e 'text returned of (display dialog "'"$KEY_MESSAGE"'" default answer "" buttons {"Submit","Cancel"} default button "Submit" cancel button "Cancel")'); then
  exit 1
fi

if [ "\$input" != "\$KEY_REQUIRED" ]; then
  /usr/bin/osascript -e 'display dialog "Incorrect key." buttons {"OK"} default button "OK"'
  exit 1
fi

exec "\$REAL_EXEC" "\$@"
EOF

chmod +x "$EXEC_PATH"
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true
touch "$APP_PATH"

:
