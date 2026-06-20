#!/bin/bash

# ██████╗ ██╗  ██╗ █████╗ ██╗
# ██╔══██╗╚██╗██╔╝██╔══██╗██║
# ██████╔╝ ╚███╔╝ ███████║██║
# ██╔══██╗ ██╔██╗ ██╔══██║██║
# ██║  ██║██╔╝ ██╗██║  ██║███████╗
# ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
# R36S X11 Application Launcher
# by qewer33
#
# a script to launch X11 GUI apps from the EmulationStation UI on the R36S

# Setup launcher home dir
RXAL_HOME="/roms/ports/RXAL"
mkdir -p "$RXAL_HOME"

# Setup logging
clear > /dev/tty1
exec > >(tee "$RXAL_HOME/debug.log" > /dev/tty1) 2>&1

# Install deps if they aren't installed
for dep in xinit xinput openbox qjoypad onboard; do
  command -v "$dep" &>/dev/null || MISSING="$MISSING $dep"
done
if [ -n "$MISSING" ]; then
    echo "[RXAL_LOG] Installing dependencies on first run..."
    sudo apt update
    sudo apt install -y $MISSING
fi

# Install the default qjoypad layout
QJOYPAD_DIR="/root/.qjoypad3"
sudo mkdir -p "$QJOYPAD_DIR"
sudo cp -n "$RXAL_HOME/Default.lyt" "$QJOYPAD_DIR/"

# Script params
APP="$1"
SHOW_KEYBOARD=false
LAYOUT="${RXAL_LAYOUT:-Default}"

BOTTOM_MARGIN=0

if [[ "$*" == *"--keyboard"* ]]; then
  SHOW_KEYBOARD=true
  BOTTOM_MARGIN=160
fi

# Initial launch setup
sudo killall -9 retroarch 2>/dev/null
export DISPLAY=:0
export FRAMEBUFFER=/dev/fb0
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Install app if not found
PACKAGE="${RXAL_PACKAGE:-$APP}"
if ! command -v "$APP" &>/dev/null; then
    echo "[RXAL_LOG] Installing app package..."
    sudo apt update
    sudo apt install -y "$PACKAGE"
fi

# Setup openbox config rc
cat << EOF > "$RXAL_HOME/openbox_rc.xml"
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <!-- desktop margins -->
  <margins>
    <top>0</top>
    <bottom>${BOTTOM_MARGIN}</bottom>
    <left>0</left>
    <right>0</right>
  </margins>
  <applications>
    <!-- global rule -->
    <application class="*">
      <decor>no</decor>
      <maximized>yes</maximized>
    </application>
    <!-- qjoypad rule -->
    <application class="qjoypad" name="qjoypad">
      <fullscreen>no</fullscreen>
      <maximized>no</maximized>
      <layer>below</layer>
      <focus>no</focus>
    </application>
    <!-- onboard rule -->
    <application class="*nboard*" name="*nboard*">
      <fullscreen>no</fullscreen>
      <maximized>no</maximized>
      <layer>above</layer>
      <position force="yes">
        <x>center</x>
        <y>bottom</y>
      </position>
      <focus>no</focus>
    </application>
  </applications>
</openbox_config>
EOF

# Execute launch script with xinit
echo "[RXAL_LOG] Starting xinit..."
sudo xinit /bin/bash -c "
  # Start openbox
  openbox --config-file \"$RXAL_HOME/openbox_rc.xml\" &

  # Start qjoypad
  qjoypad --notray \"$LAYOUT\" &

  # Start the app
  $APP &

  # Start onboard
  if [ $SHOW_KEYBOARD = true ]; then
    onboard -x 0 -y 320 -s 640x160 -t Blackboard &
  fi

  # Setup ESC as exit condition
  xinput test \"Virtual core XTEST keyboard\" | grep -m 1 -E \"key press[[:space:]]+9([[:space:]]|$)\"
  killall -9 $APP

" -- :0 -nolisten tcp -keeptty

# Cleanup after exit
echo "[RXAL_LOG] Exiting..."
sudo killall openbox 2>/dev/null
sudo killall qjoypad 2>/dev/null
sudo killall onboard 2>/dev/null
clear > /dev/tty1
