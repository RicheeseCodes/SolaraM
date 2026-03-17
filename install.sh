#!/bin/bash
set -euo pipefail
clear

SOLARA_ICON_PRIMARY="fs.png"
SOLARA_ICON_FALLBACK="fs.png"
SOLARA_ICON_BUNDLE="fs"

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

apply_app_icon() {
  local app_path="$1"
  local icon_name="$2"
  local icon_fallback="$3"
  local bundle_name="$4"

  local icon_png
  icon_png="$(find_local_icon "$icon_name")"
  if [ -z "$icon_png" ] && [ -n "$icon_fallback" ]; then
    icon_png="$(find_local_icon "$icon_fallback")"
  fi

  if [ -z "$icon_png" ]; then
    echo "⚠️  Icon not found; keeping default app icon."
    return 0
  fi

  local info_plist="$app_path/Contents/Info.plist"
  local icon_tmp
  icon_tmp="$(mktemp -d)"
  local iconset="$icon_tmp/${bundle_name}.iconset"
  local icns="$icon_tmp/${bundle_name}.icns"

  mkdir -p "$iconset"
  sips -z 16 16 "$icon_png" --out "$iconset/icon_16x16.png" >/dev/null
  sips -z 32 32 "$icon_png" --out "$iconset/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$icon_png" --out "$iconset/icon_32x32.png" >/dev/null
  sips -z 64 64 "$icon_png" --out "$iconset/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$icon_png" --out "$iconset/icon_128x128.png" >/dev/null
  sips -z 256 256 "$icon_png" --out "$iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$icon_png" --out "$iconset/icon_256x256.png" >/dev/null
  sips -z 512 512 "$icon_png" --out "$iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$icon_png" --out "$iconset/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$icon_png" --out "$iconset/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset" -o "$icns"
  cp "$icns" "$app_path/Contents/Resources/${bundle_name}.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ${bundle_name}" "$info_plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ${bundle_name}" "$info_plist"

  codesign --force --deep --sign - "$app_path" >/dev/null 2>&1 || true
  rm -rf "$icon_tmp"
}

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

echo "🎨 Applying Solara icon..."
apply_app_icon "/Applications/Solara.app" "$SOLARA_ICON_PRIMARY" "$SOLARA_ICON_FALLBACK" "$SOLARA_ICON_BUNDLE"

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

needs_wrapper=1
if [ -f "$SOLARA_EXEC_PATH" ]; then
  if /usr/bin/grep -q "KEYSERVER_URL=\"https://spryzen-keyserver-production.up.railway.app\"" "$SOLARA_EXEC_PATH" 2>/dev/null; then
    needs_wrapper=0
  fi
fi

if [ "$needs_wrapper" -ne 0 ]; then
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
fi

chmod +x "$SOLARA_EXEC_PATH"
codesign --force --deep --sign - "$SOLARA_APP" >/dev/null 2>&1 || true
touch "$SOLARA_APP"

echo "🧹 Cleaning up..."
rm -rf "$TMP_DIR" "$TMP_ZIP"

echo ""
echo "✅ Solara installed successfully!"
open -a /Applications/Solara.app

RESET="\033[0m"
ART_COLOR="\033[90m"
COLORS=( "\033[31m" "\033[32m" "\033[33m" "\033[34m" "\033[35m" "\033[36m" "\033[37m" )

print_color() {
  local color="$1"
  shift
  printf "%b%s%b\n" "$color" "$*" "$RESET"
}

print_art_block() {
  local line
  while IFS= read -r line; do
    print_color "$ART_COLOR" "$line"
  done
}

print_art_block <<'EOF'
                .IIMM MMI...,                                                    
        .}}HHI..IIHHMMHIH H}..                                                  
        }}HMHHHHHMMMMMMMMHMHI}},                                                
        IHHHMHMHMHHHMMMMMMMMHH}}.,}             Y'ALL HAVE A GOOD NEW YEAR NOW, HEAR?
        MMMMMMMMMHMMMMMMHMMMMMMMMMI}                                            
        MMMMMMMMMMHHMMHMMMMMMMMMMM,}                                            
        MMMMMMMMMMMMMMMMMMMMMMMMMMM,              HAPPY HOLIDAYS FROM ...       
        MHMMMMMMMMMMMHMMMMHHMMMMMM}..                                           
        MMMMMMHHMMMMMMHHMMMMMMMMMMMMM          THE SUGI SIG/M RBBS  301-963-5249             
        MMMMMMMMMHMMHHHI@  @}}I HMMMMMI                                         
        MMMHMMMMMMMMMMHHI, @   HIHMMMMMM,                                       
        MMMMMMMMMMMMMMIII,     @@}IHMMMM                                        
        MMMMMMMMMHMMMMMMH}      ... XXXM}                                       
        MMMMMMMMMMMMMNMHMH        IMM MH,                                       
        MMMMMMMMMMMMMMMMMI,   ...IMMMMMM                                        
        MMMMMMMMMMMMMMMMMX      }MIMMI.,                                        
        MMMMMMMHHMMMMMMMY IMML..  IMMIHH}.                                      
        MMMMMMMHHHHHMMMMIMMH}}}... @IHI}...                                     
        MMMMMMMMMMMMMM@H}MHIII}...}  @},},                                      
        MHMMMHHMMHHMHI ..MMMII}@}}I}I.  }I}}                                    
        MMMMMMMMMHM....}@@@@@}}.}}I,.} MII}                                     
        MMMMMMMMM}},}}@@@   @@}}}IM}IM}} IM,                                    
        MMMMMMMMMMII}@@ @    @@}}I}}  }MMMM,                                    
        MMMMMMMMMMII}.        @}I}.,MMMMM@}                                     
        MMMMMMMMMHHHII}.     .}}I}ILMMM@}}}                                     
        MMMMMMMMMMMMII}}.. .}II} @}}II}@@..}@@@@}}..,                           
        MMMMMMMMMMMMIEIHMI}}}.}I}}.. ..  ,.}@@ ,.}@@@}},  @},                   
        MMMMMMMMMMMHII}}@II}}....@ .}@                   }}.,                   
        IHIMMMMMMMMMMMMMHI}}....}}}}} }@        }}            @,                
         @@}HMMMMMMMMMMMMMHHI}..}}}}II}}@ .}}}}}}III},.           @,            
              @IHMMHHHHHHIHIIIIMHMH}    .@@ }},  .}}..         @,               
                 @MMMMHHMHIIMMHHHHHII} .}}}    }}}}}}}}......    ....},         
                  MMHHHHHMHIMIIHHIIII  @,..@@@@   @@@H}IIMII...    ...@.        
                 ,MMHHHMHHHHHHIIIIII@}@ .....    .}}}}}II,  @HHH}..    .. ,     
                ,MMMMMHHHHII}}@@@  @@       ..     .....}HI},  II}..  ...}}     
              ,MHMMMMMMH}.@@      ...            ..   ...}}H},  @I}},    ,}     
             ,IMHMMMHI}@@     ..}. I       ..    ..    ...}}II,  @II....   }}.. 
             IMHIMMI}@@         . }                      ,,..}}H}  I}} .    ... 
             MMHIMMI}.@@    ..}    ...}            ...      ....II,@I}....    . 
            @MMHIMM}@@}.    .         .. .     .. ,}           ,.IIHI}}}.       
            IMIHMMI}}}@@           .     ,                  ,,,  ..}}IMIII...   
            IMIHMMM.......                .                         ,.}}HH}..   
            MMIHMMMH}.       .                                    ...}}}IIHHI.  
            IHIMMM}}...                                              @@@}}}}}}} 
            }MMHMM}... .       ...       III..... .                      @@@}}} 
            ,MIHMMI}...       }}},.    .     I. }}}}}.. ...}}....  ..        @@ 
             MMMMMM}...  ..         .}.....}.III}}}.........}}}}........   ..   
             HMIMMI}...         ..}}}}}}}}}III}H}IIHII}}}}}...}}}}.........     
             IMHIMM}.....         ....}}}}}III}IIIMMMMHHH@III}....}..........   
             @MHHMM}...           ....}}}}}IIIIMMI}@}}}IMHMHIII}}}}}........... 
              IMIMM}}}...            ...}}}}}III@ }....}}}}IHHMHIIII,}}.}...... 
              ,MMIMM}...             ....}}I}.@  @      @@@@}}IIIMMH,@}}}}}}}}} 
               IMMMMI}}}....       ,    ..}}}}}}..    .. ...   ..}}IHMM}, @@}}} 
                MMMMNN,.....}  .         ..}}}}}}..               }}}}MMMM}     
                IMIMMHH}...}...     ..  ...}}}}}...   ..  ...     ..}}}MMMMM,   
                 MMHMMHI}... ..}.       ....}}}}}}}..}.    ...   ...}}}}IMMMMI  
                 ,MMHHMMI}..}}...     ....}}}}II}}.}}.... ..}      ...}}IHMMMM} 
                  IMMHH}}.}}}... .      ......}}III}..}}.}}}}}         .IIHMMH  
                  ,MMMHI}}}..}}.        .....}IIIHIHII}}IHHHHHHHHHH}..}HHHHI}@  
                   MIMHHHII}}....    .. ..}}}}}}.}HHHHIMMMMHMHHMMMMMMMMMHMI}@   
                   ,MMHHHHII}}. ...        ..}.}}HHHHHHHMMHMMM@MMMMMMMMMI}@     
                    IMHHHIII}}}...       .....IHHIIHHIIIHHHHMH}}IMMMMII}@       
                    ,MMMMMIII}..}..   ..  ...}HI}...}}}IIHHHMH@IMI__@           
                     IMHHHII}}}}...       ..IHI..  ..}HHHIHMHH                  
                     ,MHHII}}}....       ...III}...  .IHNHHMMH                  
                      IMHHHIII}}...    .. ..IHH..  ..}}}IMHMHH                  
                      ,MHHHIIIII}... .    ....II}....}}}IHMMHI                  
                       MMHIIII}}}}}.        ...}}}..}}}.HHHHH@                  
                       @MMHI}}}}.......       ..}}}}}.IHHHIHH                   
                        MMIII}}}}.......    ....}}}}}}HIIHHM@                   
                        @MMHHHHII}}...         ...}}}}}MHHMH                    
                         MHMMMHHIIM}}.           ,}}}}HIMMH@                    
                         HMMMMHMHHIM}}..       ....}}}HHHMI                     
                         IMMHHMMMIIII}.    ..   ..}}}}IMMM                      
                         IMMHHMMMMMMMI}}.    ..  ..}}MMMMH                      
                         IMHHHMMMHIII}}....   ......}}HMHI                      
                         HMMMMHMHIII}}@@@ @   @@@@@}}MHMM@                      
                        IMMHHHIII}}@@@            @}}MMMM                       
                      ,MMMHHII}}@@@@         @@@@}}MMMMM                        
                     IMMHHHMM}@@   @@        @@@}IHMMMMI                        
                    ,HMMMMMII}},            @@..}}MMMMM@                        
                   ,HMMHII}}@@          @@@@@}HHHIHMMMM                         
                  ,HMHHI}},              @@}}IIIMMHHMMM                         
                ,IHMMM}}@@               ..@@IMIIMMMMMH                         
               ,HMMMI}@@              ,,,   .IIIHIMHMHH                         
              ,HMMI}@          ,        ,..   }}H MMHMI                         
             }HMMI}@           ..   ... ....}}}. MMMMH@                         
            IHMHHHI}    .          ...  ....}}}}}MMMIY                          
          ,IHMMMMMII}}.             .....  ....}}}}MY@                          
         ,MMMMHHMII}},                     ....}}}MH@                           
         HMHHHHHHII}}}.       .......     ...}}}..IM@                           
         MMMMMMMIII}},             ....}}..   ..}}}M@                           
        }MMHHMMIII}}@                ....}}  }}}.}IM@                           
        MMHHHHHIII}}@                ....}}}}.}}IHM@                            
       ,MIMHHHHHMII.  ,                   }}}. .}III                            
       IMIHMMHMMMMII                     @@}}}}}}II},                           
       HMIMMMMHMHHM}},                 @@ }}}IIM}},},                           
       MMHHHHMMMII}}@                    @@}}}}}}II}},                          
       MMMMMMMMMHHI}@           ..       ..}   }}}}}...                         
       IMMMHHHHMMM}}..                  ...}}}}}..}II}},                        
       MMHHHHHHMMM}}}}.          ....    ....}}}}.}}I}}..                       
        IMMIHHHMHHMMMII}}.              ....}}}}}}...}}}}},                     
        @MMMMMMHHMMHMHII}},           ...    ........}}}}}},                    
         MMMMHMHHMHMMMIIII}},        ....}}}.   ....}}}}..}..                   
         @HMMMHMMHHMMMMHIII}}}.,       ,,}          ...}}..},.                  
           IMHMMMMMMHHHMIIII}}}}...      ,..}.     ..  ...}}}},                 
           MIMMMMMHHMMHHHHMMMHMI}}...                   ......}}                
           MMMIHHMMMHHHHHHMMIIIII}}},..     ...}             ...}               
           MMMMIMMMMMMMHMMMHMMMMHMIIII}}}...}}            .....}},              
           MMMMMIHMMMMMHMMMHHHMMMMM}}.I}..          ...      ....},             
           MMMIMMIMMMMMMHMHMMMHHHMMMMHH}},   ...         ....  ..}},            
           MMMMMHMIMHHMMHHHHMHMMMHMHHHMIII}}}..,         ....  ...}},           
           MMMMMIMHMIMMMMMMMHMHHMMHMMHHHHMII}}}}.}@              }}}}.          
          }MMMMMIIHMHIMHHMMMMMMMMHHHHHHMHIIII}}}},@@          ....}}}},         
          IMMMMMMIIIMMIIMMMMMMMHHHHHHMHIMMMMMII}}.         ....  ...}}}.        
          IMMMHMHIMIIIIIIIMMMMMHMMMMHHHHIIIII}}}.,                ....}}}       
          IMMHHMMMI}}IIIMMIMHMMMHHHHMMMII}}}}}}.....  .              ...}}      
          }MMMMMMIII}}IMMMMMIMMMMMMMHHHHII}}}}}..   ..    ,      ...   ..}}     
          IMMHHHMII}@ @@ @}MMMIMMMMMMMMMMII}}}..}}@@     ,             ..}}}    
          HMMMMMII}}@    }}},MMHHIHMMMMHHMHII}}@@   ..     ..         ....}}}   
          MMMHHMH...    ....}}MHHMHMMIMMMMHIII}}}@@..   ...            ....}}.  
          HMMHMII}@@    @@@@}}IMMMMMMMMMIHHMMHMDD,  ....  .  .    ..    ...}}}. 
          MMHHMI}}@    .. ... IMMHMMMMM  @IHMMHII}}...... ....            ..}}} 
          MMMHHH}}       @@}}}HHMHMHMM@    @HHMHI}}}}}}.... .               ..} 
          MMMIHI}} }       },}.MHMMMMM       @HHHH}}}}..,,......             .} 
          MMMMHIIH}.         ..HHMMMM@        @MMMMMMI}},,,,..          ...     
         ,MMMHHH}}.    ..   ...}HHMM@          @MMMMMMI}}}....  ...         ..  
         IMMMMHHM}}.     ....}}}MMMI              IMMMMMHH}}}......  ..         
       ,MMMMMHMM}}...   ..  ..}MMM       ....}}II.IIMMMMMHMM}}}}.......         
      MMMMMMMMMMHH}}..  ..HHMMM   ,}IIIHIIII}IIIHHMMMMMMMMHHH}}}.. .            
      MMMMMMMHMHHIII}}.  .}MMMYII}IIIIH}@@@@}@@}@@}}}}HMMMMHHHM}}........       
      MMMMMMMMMIII}}@@IMMMIIIIIMMMI}@@             @@}}}.IMMMMMMMMMM}}.....     
      MMMHMMHIIMIIMHHIII}}}}@@@@@@                   @@}}}IMMMMMHMMMMI}}}...    
      IHII@@HHHMIII}@}}...   ..                      ..,,  ,MMMMMHMMMMMHI}}..   
      MHMMIII}@@@@@}...     .              .....    }}}} .IIMMHHHMHMHMHIMMM}..  
      II}@@}}}..         .         ....}}}}}}} .}}}}}}IIMMIIIMMMHIIIMMMMMMMMII  
      ..   .           .          ......}}}}}}}}@@IIMMMMMMMMMMMMMMMMMMHMMMMMMM  
           .....       ........}}}}}}}}}}III}}IIMMMMHHMMHHMMMMMMMMMMMMMMMMMMMM  
      .....       ..}  ..}   ......}}}}}IIMMMMMMMIIIIIHMMMMMMMMMMMMMMMMMHII}}@  
      }}.    ........}}}}}}}}}}IIIHMHHHMMMMMMMMMMMMHHHMMMMMMMMMMMMMMII}}@@@     
      }}}}}}}IIIMMMMMMMHHHMMMMMMMMMMMMMMMMMMMHHHHHIIII}}@@@@@@@                 
      IHIHIIMMMMMMMMMMHHIII}}}}}}}}}}}}}@@@@@@@@@                               
      MMHHHHHHHMMMHHMMM   @@@@@@@                                               
EOF

echo ""

print_art_block <<'EOF'
CLOHE


                          ,.--..
                       ,:'.   .,'V:.::..  .
                     ,::.,..  . . 'VI:I'.,:-.,.
                    :I:I:.. .   .    MHMHIHI:MHHI:I:,.:.
                   :I:I:.. .   .    MHMHIHI:MHHI:I:,.:.
                   A:I::. ...  .   .MMHHIIHIHI:IHHII:.:,
                  .M:I::... ..   . AMMMMMHI::IHII::II.::.
                  IMA'::.:.. .    .MMMMMHHII:IMHIHIA:::',       
                  ,MV.:.:.. .     AMMMMHMHI:I:HIHHIIIA;.
                   P.:.:.. .  .  .MMMMMMMHHIIMHHHIIHIIH.
                   :..:.. . .    AMMMMMMMHHI:AMIVHI:HIII:
                  ,:. :.. .  .    MMMMMMMMMH:IHHI:HHI:HIIH.
                  :..:...  .    .MMMHP:'',,,:HHIH:HHH:HIII
                 ;.:..:.. .     AMH:'. , , ,,':HII:HHH:HII:
                 ::..:.. . .   .H:,.. .     ,'.:VA:I:H::HI:
                ;.:.:... ..    A:.,...     .   ,:HA:IHI::I:
               ,::..:. . .    .M::. .    .      ,:HA:HH:II:.
               ;.::... ..     AML;,,,       .    .:VHI:HI:I:;
              ,:.:.:. . .    .H. 'PA,           .:IHH:HHII::.
             ,:.::... ..     A:I:::';, .   .  ,ILIIIH:HI:I:I;
            ,;:.:.:.. . .   .H:TP'VB,)..   .,;T;,,::I:HI:I:::
           ,::.:.:.. . .    AI:.':IAAT:.  .(,:BB,);V::IH:I:I;
         ,::.:.:.. . .    .H:. , . . ..  .':;AITP;I:IIH:I::;,
        ,::.::.:. . . .   A::.   . ..:.  .  . ..:AI:IHII:I::;.
         ;:.::.:.. .  .   AM:I:.   ..:.   .: . .::HIIIHIIHII::.
        ,:::.:.:..  .    .MM:I:..  .:,    .:.  .::HHIIIHIHII::;
       ,::.:..:.. .   .  AMM:I:.  . .,'-'',,. ..::HIHI:HI:III:
       ;:.::..:.. . .   AMMM::. . ,,,, ,..   ,.::IMHIHIHIIHI::;
      ,:::.:..:. .   .  MMMM:I:.  ,:::;;;::;, .::AMHIHIHHIHHI:'
      ;::.:.:.. . .   .:VMMV:A:. .  ,:;,,.'  .::AMMMIHIHHIHHII
     ;::.:.:.. ..  .  .::VM:IHA:. .,,   , . ..:AMMMMHIHHHIHHII:
     ;:::.:.. .  .. . .::P::IHHAA.. .   .. .:AMMMMMMMIIHHIHHI::
     ;::.:.. .  . .  ..:.:VIHHHIHHA::,,,,,:AMMMMMMMMMHIIHHHHII;
     ;.::.. .    . .  ..:.;VHHIHI:IHIHHIHI:MMMMMMMMMMHIHHIHHII:
     ::.:.. .     ..  ...:.::VHI:IIVIHIHII:MMMMMMMMMMMIHHIHHII:,
     ;:..:. .    ..  . ..:.::::VAII:IIIIII:MMMMMMMMMMMIHHIIHIIHI
     ,;:.. .        . .. ..:...:.VII::III:.VMMMMMMMMMHIHHHIHI::I,
      ;:. . .    , . .. ... . .::.::V::II:..VMMMMMMMMHIHHHIHI::I;
      ;:.. . .     . .. ..:..  .::...:VIITPL:VMMMMMMMVIHHHIH:. :;
      ;:. .  .    . .. ... .   ..:.:.. .:IIIA:.MMMMMVI:HIHIH:. .:
      I:. . .   . .. . .. . . . . ..:.. ..::IIA.VMMMVIHIIHIV:. .,
      I:..    . . .. .... .  .   . .. ... .:.:IA:.VMVIMHIHIH:..:
      I.. .  .  . ..... .       .  . .. . .. .:IIAV:HIMHHIHII:.;
      :. ..   . . .:.. .          .  .. ... ..::.:CVI:MHHIHHI...
      :..  . . .. ..:.               . . ... .:.:::VHA.VIHHMI:..
      :. .. .  . ..:..        . .     . .  ..  .. ...:VIIHIHI: .
      ,:.. .  . .::. .       .::,.      .    .  . .  ...V:IHII..
       ;:.. .. .:I:.        ..:T'::.     .  . .  .  . .  .VIIH:.
       ;:.:.. .:I:..        .::V:::.         . . . .  .    VIII..
       ;:.. ..::::. .        ..::. .      .  . .. . .  .    VIII.
       I:.:.. .:I:.           ..:.,        . . .. :. .  .    'VI:.
       I::......::.  .                    . .. .:.:.:. .       'I:
       II::.. ..::. .       .    .     . .. .. .::::.. .      .:.
       II::.:. ..::. .  . .   .    .     .:. . .:I:::. .       .::HD
       ,I:::.. .: . .. ..  .. . .    .  .::. . .:I:. .         .:V:
        I:. .. .  . . ... ..  .. . .    .. ..  ..::.             .:.
        I:.. .. .  ..:.. .. .. ..  . .      .   .                . :
        ;:.... . ..:::I:.. ..:.. ... .::. . ... . ..              .I.
        ::.:....::.::I:III:I::::I:II:I::.. .:.. . .:. .     .  . .AI:
        ,::.:...:..::::::III::II::::::.. ...::. .  .::. . .. .  .AMMI.
          :::.:.:. ..::::III:II:I:::.:. .. ..::.. ..  ..::,.  ..::HMMI:
         ,:::.:.. ...::I:::I:I:::.:.. :. . ..::.. . . . .,PTIHI:IIHHI:.
          ::I::.:...:::II:I::.:....:.:. . ...::. .  . .  .AI:IHI,,:,  ,.
          ,:::.:... ..I::I::.:....:. .: .. ...::. .  .   III:II:.  ,
           ,I:::..:...:.::I::.:..:. .: .. . ..:... .  .  III.I,
            VI:::.::.::...:II::...:...:. . . .:::. . .   :,,
            ,HI:I::.::.::..:II::.:..:.... . .:.:I:.. .   :
             VI:I:I::.::.:...:I:::I:::.... ..:.:I::...   :
             ,II:I::II:I:::.:.:I:III:I:... ....::::... .  :
              VII::I::I::.::..:.::II::.:.. . .:.::::. .   .
               VI:.:..::II:::..:..::.... .   ..::I::...  . .
               ,I::.. ..::II::..:.::.... . ...::I:::.   .  .
                V::.:.. .:I:II::.:..::.. .. ...:::I::..  . . .
                I:::.:....::III:::.:..:.:.. .:.:II:::. .  . . .
                I::.:::...:::II::.:.:.:... ...:II::.. . . . .  .
                I::..:...:.:::.:.:.:.:..:.. .:II:. .. .    . .   .
               .::.:.:....:.:::.:.:.:.:.: . .:I:... . . . . .  .  .
               :.:.:...:.:.:::.::.:.::.... .:::.. .. .  . .  . .
              .:. ..:.:.:::.:..::.::.:.. . .::.. .. . . .  . . .   :
             .:. .:....::..:.:.:.:.:... .. .NI:.. . .. . . .  . .  :.
            .:. . . ..:.:.::.::.::.::.::.. . :.:.. .. .. . . . . . .)O
           .:.. ... .. ..:.::.::.:::.:..:.. . ..:.. .. .. . .. . . ,()
           ::.:. ...:.. ..:..::..::.:.:.:.:. .:.:... .. .. .:.. ..0OO.
          /:::.:...:.:..:..:..::.::.::.:..:..:.:..:.... ..:.:..:.()',
        (0):::.::...:..:..:...::::I:.:I:.:.:.::.::..:.:...:..::O0O... .
         : ::.:..:.:..:.:..:.:I:.::I:::I::.:I::.I:.::..:.:.::.:/0O/.. .
        .:: ::I:.:..::.::.::.::I:::I::.:I::.::I::.:::.::.I::( ):.:..  .
        '.:: ::I:.:..::.::.::.::I:::I::.:I::.::I::.:::.::.:I::( ):.:.. .
        ::I:::,(,,)OO::.:.::.::III:::III::III::I:::::.:I:'V0O:., .   .
       .:::I::I::-:000::..:::.::::III:I::I::II::I:::IIII( ),) .    . . .
       .:.::I::II:I(,)(  )00):.::.::II:I:II:I:I:::III0OO'.M:M.   . . .
       .. .:.::.:I:I:IIHHI000 ,)OO:II:O:II:III::OO(')00//XXVM . .. . . .
       . .. ..:.::.::II:II:III,(0O0'')!0:III:(0OO)..AMV AXXXXI .. .. . .
       . :.. . .::I:IIIHHII:IHIHH(0),,0OOO( )M00AMMHMM,,XXXXXX.. . .  .
      .:.:.:.. . ..:IHHHII::::.,.MMIIIMMXIMMMMMMMMMMV AXXXV:MI. .. .  .
      ::.:.:.:.:.. . ,,., .. ..:.MMIII:MMIMMMMMMMMMMMM, .X::M.MI.. . . .
     .::.::..::.:.:.:. .  .. .::AMMXXXIAMHMMIHMMMMMMV ...::M.MM ... . ..
     ::.::.::.::.::.:.:.. . .:::MMXXXXI:.:VMMHMPMHVMI ..:I:H-,',,.:. . .
    ::.::..:.:.:..:.:.::.:. . .:MMXXX:IXX:MMMMMLMMAM, ..I:M.  :  ,:.. .
   .::.:..:...:...::.:.::I::...IMM:XXX:XX:LMMMMMI:MV  ..I:V   .   :... .
   :.:.:..:.:.:..:..:::II:II:'..M'.VMXX:XXMMMMMMMI.I ...IVI   .  .::. ..
  :.:.:.:.:.:.::...:.::IHI, - . .'VIMHX:XIIMMV/IMLMI ...HV     .  ::.. .
 .::.:.:.:.:..:.. ..::IHI:-.  . .  ',IX:XXIVMI XMMV I...HI    .   :::...
.::.:.:.:.:.:.. ...:.:IHHHI:., .    .XXX:XX.MMAXMHA I..AMI    .    ::...
::.::.::.:.:.... .:.:IHHIHI'. ..    :XXX:XX:MHHIMMMAI,AHHI     .  :::...
:::.:.:.:.:.:.. .:.::IHHHHI:  ..   ,:XXX:XX:MV''.I,V:,:HHI.    .   :::..
::.::.:.:..:.. ...::IIHHHHI:   .   :.XXX:XXXI:.,.    '-VH:    .    ::.:.
:::.::..:..:.. ..:.:IHHHHHI,   .    ::XX:XXXI:.A. .  'VHH      .   :::..
::.::.::.:... ...:::IIHHHIH   ..    :IAX:XXXIHHH:  .  .:MI    .   .:::..
:::.::.:..... ..:.::IIHHIHH   .     ::XX:IXXIHHV .     'V. . . .  :I:::.
:.::.:.:... ...:.::IIIHHHIH    .    I:XX:XXVHMMI .      I.. .:. . .I::.:
::.:::.:.... ..:.::IIIHIHHH.  .     :'XX:XXXVIVI  . .   ::..:. . .I::::.
EOF

echo ""

print_art_block <<'EOF'
                                                            #L                  
                               .                          +#MM                  
                               #+                        #MMMM                  
                          YMM$+++MM.                   #MMMMMMM                 
                           MMMMD+IMMM$.              #MM..   .M.                
                           MMMM     MMMM$.IMQ$....  ,  ..+--    .-.             
                           MMMML        <<<<IMMMMML.F.,     <      ,            
                          .MMMMM   .$NFIII,,EMMMMMMM    .QMM$     .             
                      .FT.   ,TI     ..#MMA.MMMMMMMF    .  .CCC$..              
                    #T          TTAA///I    /A      V.   .L   IMA               
                  #T             AF $NL    A.         L.   I.    .              
                .I                 #M     II           L     A    .             
               /                  AN     F              L    F     L            
                                  /     /                I          L           
             /                          /                V.          I          
                                                          V          L    F     L            
                                  /     /                I          L           
             /                          /                V.          I          
                                                          V        
                                  #     /      +                    /   I       
       /                         #M  I  Y              I                Q       
                                #MI  V  I      I      IL                P       
      /                        .MMQ   L VI     H      IM               #        
                               MMMMQ  VL W     I      #M     I   /     F I      
                              #MMMMM.     V     .     M     #   #I    /   $     
                             .MMMMMMAM     Y    #          /M  #I    /P         
    .                        #MMMH          ..     //    //# #CM/   .#     I    
           .                .MMF.                             .?   LMD     I    
   /      /                 #M/                                 HHMMM           
         /.                 /M/                                 IMMMF           
  /      /                 #M                                    HHH        I   
        /              .   IM                                    HHH            
 #      L             .     M                                    HHML $     I   
 M     LI             .      $     ....                          ,MMI$M     I   
#M     M              I       I   .   .D$.                 .$$MMM MM#W          
MC.   #M             /L                  .FMM$          AMM.     .MMMM      I   
MC.  #MI             CC           .T$$HMMMM::.        .::$MMMMM. #HHH           
MLL  MM             /CM       .     .    MMM$:..     .+:   MMMMFHHMM            
MML#MT     /        CHH       ..      .::MMF  ...   .     +FFF. HHMM    /       
HVXLMM    .        CCMV       ..     ..                         .MMM   //   I   
 VMMMM    !       CCCJ        ..                .                HHH   I.       
    HML   I      II,          ...                               .MM    I        
    YNUL  U/    /I          /::...                             LMK     I    L   
     .MML NL    /.        #M::::...         .                  LMK     P    .   
      .HMMNNL   #        .MM::::.....       :.        /       .MML    /         
          HMML   L       #MMMM///....         ,++-..+.        #MML         J    
           HMML  ..       HMMP /......                       #MMFM   .     I    
            ,WNNNYL          +.....      P++..   ....  /  . #MMP PL..           
                  WHMHIIIL..+I....         ...+FMMMMMF,   L                /    
                              ...            ...     .    I               /     
                             .MA..              .....   -MLI   I          /     
                            #M.MA..                    .MF VQ   L       .I      
                          .#MML.IMM$.                  MF   ,TA  TL   C,        
                         #MMMMM.LCMMMMM$.             F.       ,,CCC..          
                        .MMMMMML.LCCMMMMMA.        .-.         .+ILL            
                        #MMMMMMM..IICMMMMMMMMAA=--,          ....+IPL           
                        MMMMMMMMMGGILCMMMI-,,             , H...++IIP.          
                        VMMMHHHFNL.-ICM,               . . ....++IIIIA          
                        ,NMMMMFMMM..-+              . . .......++IIIIP.         
                         NMMMMMCCFII/+             . . ..........++IIII         
                         MMMMFNCLTII#P+              . . . .......+IIII         
                         IMMNCCCCLTIMP+.                . .. .....+IIIP         
                         IFFCCCCCCLIMPI+.                 . ......++IIP.        
                         JFGCCCCCCIIMNI+..                . ........+IIP        
                        #FCCCCCCCCIIMMMI+.,                 . ......+IIP        
                       #FCCIICCCCCLIMMNI+.,                   . .....+IP.       
                      #FCCIIIICCCCCIMMPI+.,                    . ....+IPL       
                    .ETCI++.IICCCCCIMMPCI.,,                    . ....++P.      
                  #PIPI+...IICCCICIMMPCI...                       .....++C      
                 .EIPI.....IIICCIIIJMNNNC...                      .....  +      
               JFFPI....    QICCIGG#MNNNPI...                      ..     +     
             .FIII...       #CCCI..MMINNNPI..                                   
            #PTI...        .EFCI.. MPINNNPLI..              .              .    
          .PIII..          FCCI..  HFPVNNNCI..             ..                   
         .FII..          .FCCI..   MPPPVNNPCC..           ...              I    
        #TII.           AFC...     MPPPCNNPCC...         ...        .           
       #III.          .#T..        MPPCCVNNPCC..       ...+        V/           
      #III,          .MLI..        MPCCIVNNPLL....   ...++        .V            
     #MLI.          JFI..          MPCCIINNNPC.........+++        V             
    MMMII.         #TI..           MPCIIIMNNPC.......++++.       .V        /    
    MMMI...       #OT..            NPCII.NNNPPC.....+III.        Q              
     N0II....    LFT               NPIIIINNNWPCC...IIII..        P   .    /     
     .MULI...../PI                 NPI++,VNNNNPPCIIIII..        +P  ..   .      
      WWULI+....PI                 MPI+...NNNNNPCLLII..        .PP ...          
       WWMLII+.PI                  MP+....VNNNNNCCLII.        .+P....  ..       
        .MMWLIIC,...               NP+.....+VNNNLLTI.         .+P .. ...E       
          .MMMC/++++,+             MP+....  +VCCCII           +PP.. ...MPL      
            ,NN++MM#+.I            MC+...   +ITTTT.          .+N.....+.M+J      
              C++MMM+.I            MC+...    ...             +PN....++.MPCA     
              VC+PP,-.            .MC++...   .              .+V....++. MP C.    
              +CC+++,             .MC++...                  ++N..++CC. MN  T    
               V+. .             ..NCC++...                ++NP.+CCC.  MMP  L   
                C+. .           ...NCC++...              ..+AN.+CC+.   ,MP. I.  
                 C-..  .       .....NCC+++...           ...+AF+++++     WN+  A. 
                  +C+... . ........NNCC+++...        .... +NA.++...      MP+ .N<                                       
                   ,VI+............NNCCIIII..        ...   AM....        .MP  +N                                       
                      ,VI++.......+NNCCIIII..       ...   +MP..           WP+ +CM                                      
                          ,,=+...++VNCCCIII..       ..   +PM              .M+  +CA .                                   
                            MMMMMMM.NCCCCII..           +APM              .MC+  ++FA..                                 
                            ,MMMMMMM+NCCCTI+           .APMM              .WNP+   +TMMMN$$.                            
                             MMMMMMM+CWCII+.           .APMM            . ..MPCQ    +NMNNPPCCA.                        
                             .MMMMMMM+CCLI.           .PPNP              ...MNP+      WNNPPPCCC$.                      
                              CCMMMMMACII..           ..+CM.           . ...WMPQ.      ,NNPCCII+++$.                   
                               CCMMMMMII..            ..+MV          .  .....MM+.          ---+++++PP$                 
                                CCMMMMI .            ...CM..       .. . ...+.WM++.             ---++PNN.               
                                 CCMMMJ+.           /..CMV.. . . . . . ...++. WM+..                  --+N$             
                                  VMMM+.           CNCCCM...  . . . . ....++.  NM+.. .                   -N$.          
                                   ,M/           $MI    $$+... . . .....+++.    NM++.. . .     .            N.        
                                    .           /M     .+J++..........++++.     .WM+++.. . .     .            N.       
           .+MMMMC$..               /           MM       C+++.......+++++.      .+WMMC++...  .   ..            N.      
         .MPPCCTTIIIPFPPP$$..      .            .V    ,+ICA++++...+++++.       .++.CPPC++++.   . ..+            N.     
        #MCCIII+... .+IIIICCFMM$=..I              C. ..+ICC++++++++..        ..++..CCCCC+++...    .++            M.    
       #PCII+.. .      ....++IIPMMMI              CC.     M++++....         . ...  IICCC+.....    .C++            A    
     .MPPII. .           ...++IIPMM                C...   .++..            . . .  .+ +++.......    CCC.           +.   
    .MIIII. .              ...++IPM.                ....   $.                .    +++ .......       CC.            A   
    #MIII                    ....+P..                ...   A                    .+    ......        +C.            +.  
    MNP.QQ. .                 .....I.                  .  +N                   . .       ..        .+..             .  
    WNPPI++.  .                  ..I..                   .+N                  .....               .....             N. 
    .NPPPI++. .                  ..V..                   .CN                 ........            ......             N$ 
     VPPPPII.. .                   V+.                   +CN                ...  +M+...        .......             .++ 
      NNPPPII+.. ..                IV+                   +LN                      MH+.....   .........             .+N 
       MNPII++...  .                VP.                 .ICN                       +++..............+.             .+W 
       ,NNPPPII+++..  .             VN.                 .IPN                          ...........+++.             .+NV 
         NNPPPII++... . .           VN+                 +IPN                              ....++++++              .INV 
         VMMPPPPII++..   . ..       .N+                 .+ICN                                  ..+Q+..           ..NN/ 
          WNNPPPPPII++...  .  .      IN+               .+ICP                                       NP..         ..NNN  
           HHNPPPPPII+++... ..  .    ,NN.              +IICP                                        .P..       ..INNV  
            NNNPPPPPIII++....  .  . . VN.             .+IICP                                         .P+.    ...INNV   
             WNNPPPPPIII+++......  . .VN+             .+ICCP.                                         ,P+.......INN,   
              WMNPPPPPPIII+++........ .NN.            .+CCP..                                          VP++..+IINN,    
               WMNPPPPPPPIII+++........VN.           ..+ICCP...                                         MPII+++NN.     
                ,NNNNPPPPPPIII++++.....IN+           ..+CCCC.....                                       WMPIIPNP,      
                  ,NHNNPPPPPPIII+++++...N+.          ..+CCCC....                                        .MMPPFF        
                    VNNNNPPPPPPPIII+++++N+.          ..ICCCI..                                         ..MMMF          
                     ,NNNNPPPPPPPPII++++VN+          ..ICCCI.                                          ..MP.           
                       ,NNNNNPPPPPPIII+++N+          ..ICCC..                                         ...              
                         ,NHHHNNPPPPPPIIIN+.         .+ICCC...                                       ...               
                            .MMNNNNPPPPPINN.         .+ICCC+....                                    ..+I               
                              .MHHNNNNPPPVN.        ..+ICCC++.......                               ..+P                
                                ,,WMMMMMMIN..       ..ICCCPPP+........                            ..+C.                
                                   .WMMMMW+.        ..+ICCCPPCC++.........                    .....+C.                 
                                       .MMN+.       ..+ICCVNPPCC+++.............          ......++CP,                  
                                          VN.       ..+ICCIMNPPPCCC++++......................+++ICP,                   
                                          IN..      ..IICCIMMMMPPPCC+++++..................+++ICCP                     
                                           N..      ..IICC.MMMMMMPPPCCIII++++++++.......++++ICCP.                      
                                           N..      ..IICC.MMMMMMMMMPPPPPPPCCCCCCIII++++ICCCCP.                        
                                           N+.      ..IICCPPPMMMMMMMMMMMMMMPPPCCCCCCCCCCCC''                           
                                           V+..     .+IICCI  ..MMMMMMMMMMMMNNNNNCCCCCC..                               
                                           IN..    ..+IICCA       ..WNMMMMMMMNNNP.                                     
                                            N...   ..+IICCN               ''''  
                                            N+..   ..+IICCN                     
                                            MMM.. ..+ICCCC.                     
                                            NNPI+++==PPPPPIA                    
                                           /MP++.        ,,+I.                  
                                          .#PI+.             +.                 
                                         #PPI+...             +.                
                                        #PCI+++...             +.               
                                       IMP++++++...                .            
                                       IMI+.+++++...                 .          
                                       ,MI+...+++...                            
                                        M+P ...+++....                    .     
                                        VP  . +V++....       .                  
                                        IP.   + V++.....      ..         +.    .                                       
                                         W.   +  VC++.....     ++.    .-   +.   
                                          M.  +.   .CC+.....    ++..    -.   +..  ,                                    
                                          ,M.  ,.     ,C+.....   VN+.     ...  ..   .                                  
                                            VM,VN       ,,C....   ,NN+..    ..   .   .                                 
                                             .  M          ,,CC    ,  ,VA.   +.   . ...                                
                                              ..I             ,V.   .    N.   +.   - ...                               
                                                                V.   .    V.   ..   -                                  
                                                                 ,.   .    +.  . +...-.                                
                                                                  ,.   .    +..-.  +.  .                               
                                                                   V. .-.     .  ,    -                                
                                                                    .N   <     -                                       
                                                                      .-        
EOF

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
