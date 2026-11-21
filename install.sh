#!/usr/bin/env bash
set -euo pipefail

REPO="dungngminh/simutil"
INSTALL_DIR="$HOME/.local/lib/simutil"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/simutil"
BINARY_NAME="simutil"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[info]${RESET}  $*" >&2; }
success() { echo -e "${GREEN}[✔]${RESET}    $*" >&2; }
warn()    { echo -e "${YELLOW}[warn]${RESET}  $*" >&2; }
error()   { echo -e "${RED}[✘]${RESET}    $*" >&2; exit 1; }

detect_os() {
  local os
  os="$(uname -s)"
  case "$os" in
    Linux*)           echo "linux" ;;
    Darwin*)          echo "macos" ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *)                error "Unsupported operating system: $os" ;;
  esac
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)     echo "x64" ;;
    aarch64|arm64)    echo "arm64" ;;
    *)                error "Unsupported architecture: $arch" ;;
  esac
}

resolve_version() {
  local version="${1:-latest}"

  if [ "$version" = "latest" ]; then
    info "Resolving latest release..."
    # Desktop app releases (app-vX.Y.Z) share this repo, so "latest release"
    # may be the app; take the newest CLI tag (cli-vX.Y.Z, or legacy vX.Y.Z).
    version=$(curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=100" \
      | grep -oE '"tag_name": *"(cli-)?v[0-9][^"]*"' \
      | head -n 1 \
      | cut -d '"' -f 4)

    if [ -z "$version" ]; then
      error "Could not determine the latest release. Check https://github.com/$REPO/releases"
    fi
  fi

  echo "$version"
}

install() {
  local os="$1"
  local arch="$2"
  local version="$3"

  local ext=".tar.gz"
  if [ "$os" = "windows" ]; then
    ext=".zip"
  fi

  local asset_name="${BINARY_NAME}-${os}-${arch}${ext}"
  local download_url="https://github.com/$REPO/releases/download/$version/$asset_name"

  info "Detected: ${BOLD}${os}${RESET} / ${BOLD}${arch}${RESET}"
  info "Version:  ${BOLD}${version}${RESET}"
  info "Downloading ${BOLD}${asset_name}${RESET}..."

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local tmp_file="${tmp_dir}/${asset_name}"

  # Create install directory
  mkdir -p "$INSTALL_DIR"

  # Download
  local http_code
  http_code=$(curl -fsSL -w "%{http_code}" -o "$tmp_file" "$download_url" 2>&1) || true

  if [ ! -f "$tmp_file" ] || [ ! -s "$tmp_file" ]; then
    rm -rf "$tmp_dir"
    error "Download failed. URL: $download_url\n       Make sure release $version exists with asset $asset_name."
  fi

  info "Extracting..."
  if [ "$os" = "windows" ]; then
    unzip -q -o "$tmp_file" -d "$INSTALL_DIR" || {
      rm -rf "$tmp_dir"
      error "Failed to extract $tmp_file"
    }
  else
    tar -xzf "$tmp_file" -C "$INSTALL_DIR" || {
      rm -rf "$tmp_dir"
      error "Failed to extract $tmp_file"
    }
  fi

  rm -rf "$tmp_dir"

  local extracted_file="${INSTALL_DIR}/${BINARY_NAME}-${os}-${arch}"
  local target_path="${INSTALL_DIR}/${BINARY_NAME}"

  if [ "$os" = "windows" ]; then
    target_path="${target_path}.exe"
    if [ -f "${extracted_file}.exe" ]; then
      extracted_file="${extracted_file}.exe"
    fi
  fi

  if [ -f "$extracted_file" ]; then
    mv "$extracted_file" "$target_path"
  else
    error "Could not find expected binary '$extracted_file' after extraction."
  fi

  # Make executable (skip on Windows)
  if [ "$os" != "windows" ]; then
    chmod +x "$target_path"
  fi

  success "Installed to ${BOLD}${target_path}${RESET}"
}

# ─── Configure PATH ─────────────────────────────────────────────────────────────

configure_path() {
  local os="$1"
  local path_entry="$INSTALL_DIR"
  local export_line="export PATH=\"$path_entry:\$PATH\""

  # Check if already in PATH
  if echo "$PATH" | tr ':' '\n' | grep -q "^${path_entry}$"; then
    info "PATH already contains ${BOLD}${path_entry}${RESET}"
    return
  fi

  # ── Windows (Git Bash / MSYS / Cygwin) ──
  if [ "$os" = "windows" ]; then
    warn "Automatic PATH configuration is not supported on Windows."
    echo ""
    echo -e "  ${BOLD}Please add the following to your system PATH manually:${RESET}"
    echo -e "  ${CYAN}${path_entry}${RESET}"
    echo ""
    echo -e "  Or run in ${BOLD}PowerShell${RESET} (as Administrator):"
    echo -e "  ${CYAN}[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';${path_entry}', 'User')${RESET}"
    return
  fi

  # ── Unix shells ──
  local configured=false
  local shell_name
  shell_name="$(basename "${SHELL:-/bin/bash}")"

  # Bash
  local bashrc="$HOME/.bashrc"
  if [ -f "$bashrc" ] || [ "$shell_name" = "bash" ]; then
    if ! grep -qF "$path_entry" "$bashrc" 2>/dev/null; then
      echo "" >> "$bashrc"
      echo "# simutil" >> "$bashrc"
      echo "$export_line" >> "$bashrc"
      success "Added to ${BOLD}~/.bashrc${RESET}"
      configured=true
    fi
  fi

  # Zsh
  local zshrc="$HOME/.zshrc"
  if [ -f "$zshrc" ] || [ "$shell_name" = "zsh" ]; then
    if ! grep -qF "$path_entry" "$zshrc" 2>/dev/null; then
      echo "" >> "$zshrc"
      echo "# simutil" >> "$zshrc"
      echo "$export_line" >> "$zshrc"
      success "Added to ${BOLD}~/.zshrc${RESET}"
      configured=true
    fi
  fi

  # Fish
  local fish_config="$HOME/.config/fish/config.fish"
  if [ -f "$fish_config" ] || [ "$shell_name" = "fish" ]; then
    if ! grep -qF "$path_entry" "$fish_config" 2>/dev/null; then
      mkdir -p "$(dirname "$fish_config")"
      echo "" >> "$fish_config"
      echo "# simutil" >> "$fish_config"
      echo "fish_add_path $path_entry" >> "$fish_config"
      success "Added to ${BOLD}~/.config/fish/config.fish${RESET}"
      configured=true
    fi
  fi

  if [ "$configured" = false ]; then
    warn "Could not detect shell config file."
    echo -e "  Please add the following to your shell profile manually:"
    echo -e "  ${CYAN}${export_line}${RESET}"
  fi
}

main() {
  local os arch version

  os="$(detect_os)"
  arch="$(detect_arch)"
  version="$(resolve_version "${1:-latest}")"

  install "$os" "$arch" "$version"
  configure_path "$os"

  echo ""
  echo -e "${GREEN}${BOLD}  Installation completed!${RESET}"
  echo ""
  echo -e "  Restart your terminal or run:"
  echo -e "    ${CYAN}source ~/.bashrc${RESET}  or  ${CYAN}source ~/.zshrc${RESET}"
  echo ""
  echo -e "  Then verify with:"
  echo -e "    ${CYAN}simutil${RESET}"
  echo ""
}

main "$@"
