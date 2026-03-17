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
APP_NAME="Solara Management"
KEY_REQUIRED="key/0001"
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

        ICON_PNG="$TEMP/spryma.png"
        ICONSET="$TEMP/spryma.iconset"
        ICON_ICNS="$TEMP/spryma.icns"
        curl -# -L "$ICON_URL" -o "$ICON_PNG"
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
        cp "$ICON_ICNS" "$APP_PATH/Contents/Resources/spryma.icns"
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile spryma" "$INFO_PLIST" 2>/dev/null || \
          /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string spryma" "$INFO_PLIST"

        EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
        EXEC_PATH="$APP_PATH/Contents/MacOS/$EXEC_NAME"
        REAL_EXEC="$APP_PATH/Contents/MacOS/${EXEC_NAME}.real"
        mv "$EXEC_PATH" "$REAL_EXEC"
        cat > "$EXEC_PATH" <<EOF
#!/bin/bash
KEY_REQUIRED="${KEY_REQUIRED}"
KEY_MESSAGE="${KEY_MESSAGE}"
if ! input=\$(osascript -e 'display dialog "'"$KEY_MESSAGE"'" default answer "" buttons {"Cancel","Submit"} default button "Submit" cancel button "Cancel"'); then
  exit 1
fi
if [ "\$input" != "\$KEY_REQUIRED" ]; then
  osascript -e 'display dialog "Invalid key." buttons {"OK"} default button "OK"'
  exit 1
fi
exec "$REAL_EXEC" "\$@"
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
