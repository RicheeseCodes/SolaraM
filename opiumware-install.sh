#!/usr/bin/env bash

# Solara Management (Opiumware v2.2.3)

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CHECK="${GREEN}✔${NC}"
CROSS="${RED}✖${NC}"
INFO="${CYAN}➜${NC}"
WARN="${YELLOW}⚠${NC}"

DYLIB_URL="https://4kpb6zyvp2.ufs.sh/f/k0lH9HKBea5pG1wHDhoZK6vS0HFBCqAN34Y9bE75rM1oxZnR"
MODULES_URL="https://4kpb6zyvp2.ufs.sh/f/k0lH9HKBea5pLAf9ylOwcabo4zMiSK9Q7Y5VP63NfeUyF0kD"
VERSION="$(sw_vers -productVersion | awk -F. '{print $1}')"
UI_URL="https://4kpb6zyvp2.ufs.sh/f/k0lH9HKBea5phbZL8Y9bt6cMeUB75RNzpOTsgFXor2lwaZQK"
ICON_URL="https://raw.githubusercontent.com/RicheeseCodes/SolaraM/refs/heads/main/spryma.png"
ICON_PRIMARY_NAME="Solara.png"
ICON_FALLBACK_NAME="spryma.png"
ICON_BUNDLE_NAME="Solara"
APP_NAME="Solara Management"
KEYSERVER_URL="https://spryzen-keyserver-production.up.railway.app"
GET_KEY_URL="${KEYSERVER_URL}/get-key"
KEY_TTL_SECONDS=21600
KEY_MESSAGE="Dont uninstall it and no need to open it just tap cancel and enjoy using the executor just tap solara"

if [ "$VERSION" -lt 11 ]; then
    echo "Use the legacy installer"
    exit 1
fi

if [ -w "/Applications" ]; then
    APP_DIR="/Applications"
    echo -e "${INFO} Installing Roblox to /Applications"
else
    APP_DIR="$HOME/Applications"
    mkdir -p "$APP_DIR"
    echo -e "${WARN} No write access to /Applications; using $APP_DIR instead."
fi

TEMP="$(mktemp -d)"

spinner() {
    local msg="$1"
    local pid="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    # while kill -0 "$pid" 2>/dev/null; do
    #     printf "\r\033[K${CYAN}[${spin:i++%${#spin}:1}]${NC} %s" "$msg "
    #     sleep 0.1
    # done

    wait "$pid"
    printf "\r\033[K"
    printf "${GREEN}${CHECK} %s - Completed${NC}\n" "$msg"
    return 0
}

find_local_icon() {
    local name="$1"
    local path=""

    if command -v mdfind >/dev/null 2>&1; then
        path=$(mdfind "kMDItemFSName == '$name'" | head -n 1 || true)
    fi

    if [ -z "$path" ]; then
        for dir in "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents" "$HOME/Pictures" "$HOME"; do
            if [ -f "$dir/$name" ]; then
                path="$dir/$name"
                break
            fi
        done
    fi

    if [ -z "$path" ]; then
        for dir in "/Applications" "/Library" "/System/Library"; do
            if [ -f "$dir/$name" ]; then
                path="$dir/$name"
                break
            fi
        done
    fi

    echo "$path"
}

banner() {
    clear
    echo -e "${BOLD}"
    cat <<'EOF'
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%*=--::=*@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#+-:..........:+@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@@@#+-:..............-+@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@%#=-:...:-=+*#%%%#*-.:=*@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@##*=-:.::=*#@@@@@@@@@@@@+-#@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#+-..:-+%@@@@@@@@@@@@@@@@#*@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%+=:.:=*%@@@@@@@@@@@@@@@@@@@+@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*+-.:=*%@@@@@=%@@@@@@@@@@@@@@#@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*+:.-##@@@@@@@@@@#=@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%*=::+#%@@@@@@@@@@@@@@*:#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%**==*#@@@@@@@@@@@@@@@@@@@*-:@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%#=-*%@@@@@@@@@@@@@@@@@@@@@@%+-+=@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@%#+=*%@@@@@@@@@@@@@@@@@@@@@@@@@++===**#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@%#*=+#@@@@@@@@@@@@@@@@@@@@@@@@@@@=::---=++###%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@##+-*%@@@@@@@@@@@@@@@@@@@%%%##*+=-=------=++===+***+*##%%%%%@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@**-+%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%#*+=-=+++******%%%@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@-+-+%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%#+=+**#*%@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@-=:+%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%***#*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@#.:=*%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%#*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@-:-+%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@*=----@@@@@%##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  
EOF
    echo -e "${NC}"
    echo -e "${BLUE}=[ ${APP_NAME} Installer ]=${NC}"
    echo -e "${CYAN}Developed by @norbyv1${NC}"
}

section() {
    echo
    echo -e "${BOLD}${CYAN}==> $1${NC}"
}

main() {
    banner

    killall -9 RobloxPlayer Opiumware &>/dev/null || true
    for target in "$APP_DIR/Roblox.app" "$APP_DIR/Opiumware.app" "$APP_DIR/${APP_NAME}.app"; do
        if [ -e "$target" ]; then
            if rm -rf "$target" 2>/dev/null; then
                :
            else
                if sudo -n true 2>/dev/null; then
                    echo -e "${INFO} Please enter your password (required to delete Roblox):"
                    sudo rm -rf "$target" 2>/dev/null || {
                        echo -e "${RED}${CROSS} Failed to delete Roblox. Please manually delete it.${NC}"
                    }
                else
                    echo -e "${RED}${CROSS} Failed to delete Roblox. Please manually delete it.${NC}"
                    exit 1
                fi
            fi
        fi
    done

    rm -rf ~/Opiumware/modules/LuauLSP ~/Opiumware/modules/decompiler
    rm -f ~/Opiumware/modules/update.json 2>/dev/null

    section "Fetching client version"
    # json=$(curl -# -L "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer")
    # version=$(echo "$json" | grep -o '"clientVersionUpload":"[^"]*' | cut -d'"' -f4)
    # echo -e "${INFO} Latest version: ${BOLD}$version${NC}"
    local version="version-f18963d432b94bd7"  
    echo -e "${INFO} Version: ${BOLD}$version${NC}"

    section "Downloading Roblox - ($version)"
    (
        curl -# -L "https://setup.rbxcdn.com/mac/$version-RobloxPlayer.zip" -o "$TEMP/RobloxPlayer.zip"
        unzip -oq "$TEMP/RobloxPlayer.zip" -d "$TEMP"
        mv "$TEMP/RobloxPlayer.app" "$APP_DIR/Roblox.app"
        xattr -cr "$APP_DIR/Roblox.app"
    ) & spinner "Downloading" $!

    section "Installing Opiumware modules"
    (
        curl -# -L "$DYLIB_URL" -o "$TEMP/libOpiumware.zip"
        unzip -oq "$TEMP/libOpiumware.zip" -d "$TEMP"
        mv "$TEMP/libOpiumware.dylib" "$APP_DIR/Roblox.app/Contents/Resources/libOpiumware.dylib"

        curl -# -L "$MODULES_URL" -o "$TEMP/modules.zip"
        unzip -oq "$TEMP/modules.zip" -d "$TEMP"
        "$TEMP/Resources/Injector" "$APP_DIR/Roblox.app/Contents/Resources/libOpiumware.dylib" "$APP_DIR/Roblox.app/Contents/MacOS/libmimalloc.3.dylib" --strip-codesig --all-yes >/dev/null 2>&1
        mv "$APP_DIR/Roblox.app/Contents/MacOS/libmimalloc.3.dylib_patched" "$APP_DIR/Roblox.app/Contents/MacOS/libmimalloc.3.dylib"
        codesign --force --deep --sign - "$APP_DIR/Roblox.app"
        rm -rf "$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayerInstaller.app" >/dev/null 2>&1
        tccutil reset Accessibility com.Roblox.RobloxPlayer >/dev/null 2>&1
        curl -# -L "$UI_URL" -o "$TEMP/OpiumwareUI.zip"
        unzip -oq "$TEMP/OpiumwareUI.zip" -d "$TEMP"
        mv -f "$TEMP/Opiumware.app" "$APP_DIR/Opiumware.app"
        mv -f "$APP_DIR/Opiumware.app" "$APP_DIR/${APP_NAME}.app"
        APP_PATH="$APP_DIR/${APP_NAME}.app"
        INFO_PLIST="$APP_PATH/Contents/Info.plist"

        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
          /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"
        /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$INFO_PLIST" 2>/dev/null || \
          /usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"

        ICON_PNG="$(find_local_icon "$ICON_PRIMARY_NAME")"
        if [ -z "$ICON_PNG" ]; then
            ICON_PNG="$(find_local_icon "$ICON_FALLBACK_NAME")"
        fi
        if [ -z "$ICON_PNG" ]; then
            ICON_PNG="$TEMP/$ICON_FALLBACK_NAME"
            curl -# -L "$ICON_URL" -o "$ICON_PNG" || true
        fi

        if [ -f "$ICON_PNG" ]; then
            ICONSET="$TEMP/${ICON_BUNDLE_NAME}.iconset"
            ICON_ICNS="$TEMP/${ICON_BUNDLE_NAME}.icns"
            mkdir -p "$ICONSET"
            sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
            sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
            sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
            sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
            sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
            sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
            sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
            sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
            sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
            sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
            iconutil -c icns "$ICONSET" -o "$ICON_ICNS"
            cp "$ICON_ICNS" "$APP_PATH/Contents/Resources/${ICON_BUNDLE_NAME}.icns"
            /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ${ICON_BUNDLE_NAME}" "$INFO_PLIST" 2>/dev/null || \
              /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ${ICON_BUNDLE_NAME}" "$INFO_PLIST"
        else
            echo -e "${WARN} Icon not found; keeping default app icon."
        fi

        EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
        EXEC_PATH="$APP_PATH/Contents/MacOS/$EXEC_NAME"
        REAL_EXEC="$APP_PATH/Contents/MacOS/${EXEC_NAME}.real"
        mv "$EXEC_PATH" "$REAL_EXEC"
        cat > "$EXEC_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail

APP_NAME="Solara Management"
KEYSERVER_URL="https://spryzen-keyserver-production.up.railway.app"
GET_KEY_URL="${KEYSERVER_URL}/get-key"
KEY_TTL_SECONDS=21600
KEY_MESSAGE="Dont uninstall it and no need to open it just tap cancel and enjoy using the executor just tap solara"

KEY_STORE_DIR="$HOME/Library/Application Support/SolaraManagement"
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
        chmod +x "$EXEC_PATH"

        codesign --force --deep --sign - "$APP_PATH"
        mkdir -p ~/Opiumware/workspace ~/Opiumware/autoexec ~/Opiumware/themes ~/Opiumware/modules ~/Opiumware/modules/decompiler ~/Opiumware/modules/LuauLSP
        mv -f "$TEMP/Resources/decompiler" ~/Opiumware/modules/decompiler/Decompiler
        mv -f "$TEMP/Resources/LuauLSP" ~/Opiumware/modules/LuauLSP/LuauLSP
        tccutil reset ScreenCapture com.norbyv1.opiumware >/dev/null 2>&1
        rm -rf "$TEMP"
    ) & spinner "Installing" $!

    echo
    echo -e "${GREEN}${BOLD}Installation complete.${NC}"
    echo -e "${WARN} Please use an alt account."
    open "$APP_DIR/Roblox.app"
    open "$APP_DIR/${APP_NAME}.app"
}

main
