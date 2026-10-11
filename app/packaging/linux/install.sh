#!/usr/bin/env bash
# Installs the SimUtil desktop app on Linux together with the tools it uses
# (adb, ffmpeg, FUSE for AppImages):
#   curl -fsSL https://raw.githubusercontent.com/dungngminh/simutil/main/app/packaging/linux/install.sh | bash
# Re-run to update. The app lands in ~/.local/bin/simutil-desktop with a
# launcher entry; scrcpy-server ships inside the app.
set -euo pipefail

repo="dungngminh/simutil"
bin="$HOME/.local/bin/simutil-desktop"
desktop="$HOME/.local/share/applications/me.dungngminh.simutil.desktop"
icon="$HOME/.local/share/icons/hicolor/256x256/apps/simutil.png"

if [ "$(uname -m)" != "x86_64" ]; then
  echo "SimUtil desktop is built for x86_64 only." >&2
  exit 1
fi

sudo=""
[ "$(id -u)" -eq 0 ] || sudo="sudo"

echo "Installing adb, ffmpeg and FUSE (sudo may ask for your password)..."
if command -v apt-get >/dev/null; then
  # Ubuntu 24.04+ renamed libfuse2.
  fuse="libfuse2"
  apt-cache show libfuse2t64 >/dev/null 2>&1 && fuse="libfuse2t64"
  $sudo apt-get update -qq
  $sudo apt-get install -y adb ffmpeg "$fuse"
elif command -v dnf >/dev/null; then
  $sudo dnf install -y android-tools ffmpeg-free fuse-libs
elif command -v pacman >/dev/null; then
  $sudo pacman -S --needed --noconfirm android-tools ffmpeg fuse2
elif command -v zypper >/dev/null; then
  $sudo zypper --non-interactive install android-tools ffmpeg libfuse2
else
  echo "Unknown package manager: install adb, ffmpeg and libfuse2 yourself." >&2
fi

# Desktop app releases are tagged app-vX.Y.Z next to the CLI's vX.Y.Z, so
# "latest release" may be the CLI; take the newest app-v tag instead.
tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases" |
  grep -o '"tag_name": *"app-v[^"]*"' | head -n 1 | cut -d '"' -f 4)
if [ -z "$tag" ]; then
  echo "No SimUtil desktop release found." >&2
  exit 1
fi

echo "Downloading SimUtil ${tag#app-v}..."
mkdir -p "$(dirname "$bin")" "$(dirname "$desktop")" "$(dirname "$icon")"
curl -fL --progress-bar -o "$bin.part" \
  "https://github.com/$repo/releases/download/$tag/SimUtil-linux-x86_64.AppImage"
chmod +x "$bin.part"
mv "$bin.part" "$bin"

raw="https://raw.githubusercontent.com/$repo/$tag/app"
curl -fsSL -o "$icon" "$raw/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
curl -fsSL "$raw/packaging/linux/me.dungngminh.simutil.desktop" |
  sed "s|^Exec=.*|Exec=$bin|" >"$desktop"

echo "Installed SimUtil ${tag#app-v}: open it from your app launcher or run $bin"
