#!/bin/sh
# Prismio installer script
# Run via: curl -fsSL https://prismio.org/install.sh | sh
#
# Environment variables:
#   PRISMIO_INSTALL     Custom installation directory (default: $HOME/.prismio)
#   PRISMIO_VERSION     Version to install (default: latest, e.g. 0.1.0 or v0.1.0)
#   PRISMIO_TARBALL     Path to local tarball (for offline or custom builds)
#   PRISMIO_DOWNLOAD_URL Custom URL to download tarball directly

set -eu

# Setup formatting & truecolor detection
if [ -t 1 ]; then
    BOLD="\033[1m"
    DIM="\033[2m"
    RESET="\033[0m"

    # Detect 24-bit truecolor support (macOS Terminal, iTerm2, VSCode, Alacritty, Kitty, Ghostty, etc.)
    HAS_TRUECOLOR=0
    case "${COLORTERM:-}" in
        truecolor|24bit) HAS_TRUECOLOR=1 ;;
    esac
    case "${TERM_PROGRAM:-}" in
        Apple_Terminal|iTerm.app|vscode|Ghostty|WezTerm|Hyper) HAS_TRUECOLOR=1 ;;
    esac
    case "${TERM:-}" in
        xterm-256color|screen-256color|tmux-256color|alacritty|kitty*) HAS_TRUECOLOR=1 ;;
    esac

    if [ "$HAS_TRUECOLOR" -eq 1 ]; then
        C_PURPLE="\033[38;2;192;132;252m" # #c084fc
        C_VIOLET="\033[38;2;168;85;247m"  # #a855f7
        C_INDIGO="\033[38;2;99;102;241m"  # #6366f1
        C_SKY="\033[38;2;14;165;233m"     # #0ea5e9
        C_MINT="\033[38;2;71;215;181m"    # #47d7b5 (brand accent)
        C_GREEN="\033[38;2;16;185;129m"   # #10b981
        C_YELLOW="\033[38;2;245;158;11m"  # #f59e0b
        C_RED="\033[38;2;239;68;68m"      # #ef4444
    else
        # Standard ANSI fallback
        C_PURPLE="\033[1;35m"
        C_VIOLET="\033[35m"
        C_INDIGO="\033[1;34m"
        C_SKY="\033[1;36m"
        C_MINT="\033[36m"
        C_GREEN="\033[32m"
        C_YELLOW="\033[33m"
        C_RED="\033[31m"
    fi
else
    BOLD=""
    DIM=""
    RESET=""
    C_PURPLE=""
    C_VIOLET=""
    C_INDIGO=""
    C_SKY=""
    C_MINT=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
fi

info() {
    printf "  ${C_SKY}•${RESET} %s\n" "$1"
}

success() {
    printf "  ${C_GREEN}✓${RESET} %s\n" "$1"
}

warn() {
    printf "  ${C_YELLOW}!${RESET} %s\n" "$1"
}

error() {
    printf "  ${C_RED}✗${RESET} %s\n" "$1" >&2
}

fatal() {
    error "$1"
    exit 1
}

banner() {
    printf "\n"
    printf "   ${C_PURPLE}    ____       _               _       ${RESET}\n"
    printf "   ${C_VIOLET}   / __ \\_____(_)____ ___ ___ (_)____  ${RESET}\n"
    printf "   ${C_INDIGO}  / /_/ / ___/ / ___// __ \`__ \\/ / __ \\ ${RESET}\n"
    printf "   ${C_SKY} / ____/ /  / (__  )/ / / / / / / /_/ /${RESET}\n"
    printf "   ${C_MINT}/_/   /_/  /_/____//_/ /_/ /_/_/\\____/ ${RESET}\n"
    printf "\n"
    printf "   ${C_MINT}◆${RESET} ${BOLD}Fast${RESET}   ${C_SKY}◆${RESET} ${BOLD}Deterministic${RESET}   ${C_VIOLET}◆${RESET} ${BOLD}Memory-Safe${RESET}\n"
    printf "   ${DIM}Official Toolchain Installer ${RESET}• ${C_MINT}https://prismio.org${RESET}\n"
    printf "\n"
}

# 1. Dependency checks
if command -v curl >/dev/null 2>&1; then
    FETCH_CMD="curl"
elif command -v wget >/dev/null 2>&1; then
    FETCH_CMD="wget"
else
    fatal "Neither 'curl' nor 'wget' was found on your system. Please install one of them to proceed."
fi

if ! command -v tar >/dev/null 2>&1; then
    fatal "'tar' is required to extract the Prismio archive but was not found."
fi

if ! command -v gzip >/dev/null 2>&1; then
    fatal "'gzip' is required to extract the Prismio archive but was not found."
fi

fetch() {
    url="$1"
    dest="$2"
    if [ "$FETCH_CMD" = "curl" ]; then
        curl -fsSL "$url" -o "$dest"
    elif [ "$FETCH_CMD" = "wget" ]; then
        wget -qO "$dest" "$url"
    fi
}

banner

# 2. Platform and architecture detection
OS="$(uname -s)"
case "$OS" in
    Darwin)
        OS_NAME="macos"
        PLATFORM_TRIPLE="apple-darwin"
        ;;
    Linux)
        OS_NAME="linux"
        PLATFORM_TRIPLE="unknown-linux-gnu"
        ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT)
        printf "${C_YELLOW}Prismio installation via shell script is for macOS and Linux.${RESET}\n"
        printf "On Windows, install Prismio using WinGet:\n"
        printf "  ${BOLD}winget install prismio-lang.prismio${RESET}\n\n"
        printf "Or visit https://prismio.org/install for Windows instructions.\n"
        exit 1
        ;;
    *)
        fatal "Unsupported operating system: $OS"
        ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)
        ARCH_NAME="x64"
        ARCH_TRIPLE="x86_64"
        ;;
    arm64|aarch64)
        ARCH_NAME="arm64"
        ARCH_TRIPLE="arm64"
        if [ "$OS_NAME" = "linux" ]; then
            ARCH_TRIPLE="aarch64"
        fi
        ;;
    *)
        fatal "Unsupported architecture: $ARCH"
        ;;
esac

info "Detected platform: ${OS_NAME} (${ARCH_NAME})"

# 3. Version resolution
REQ_VERSION="${PRISMIO_VERSION:-latest}"
TAG=""

if [ "$REQ_VERSION" != "latest" ]; then
    case "$REQ_VERSION" in
        v*) TAG="$REQ_VERSION" ;;
        *)  TAG="v$REQ_VERSION" ;;
    esac
else
    info "Querying latest release from GitHub..."
    if [ "$FETCH_CMD" = "curl" ]; then
        API_RESP="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/prismio-lang/prismio/releases/latest" 2>/dev/null || true)"
        TAG="$(printf '%s' "$API_RESP" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)"
        
        # Fallback to redirect URL if API returned empty or was rate limited
        if [ -z "$TAG" ]; then
            REDIRECT_URL="$(curl -fsSL -o /dev/null -w "%{url_effective}" "https://github.com/prismio-lang/prismio/releases/latest" 2>/dev/null || true)"
            case "$REDIRECT_URL" in
                */tag/*)
                    TAG="${REDIRECT_URL##*/tag/}"
                    ;;
            esac
        fi
    else
        API_RESP="$(wget -qO- "https://api.github.com/repos/prismio-lang/prismio/releases/latest" 2>/dev/null || true)"
        TAG="$(printf '%s' "$API_RESP" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)"
    fi

    if [ -z "$TAG" ]; then
        TAG="v0.1.0"
        info "Defaulting to initial release ${TAG}"
    fi
fi

VERSION="${TAG#v}"
RELEASE_TAG="v$VERSION"
info "Target release: ${RELEASE_TAG}"

# Setup temp directory
TMP_DIR="$(mktemp -d -t prismio-install-XXXXXX 2>/dev/null || mktemp -d 2>/dev/null || fatal "Failed to create temporary directory")"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# 4. Acquire the archive
CHOSEN_ARCHIVE=""
CHOSEN_URL=""

if [ -n "${PRISMIO_TARBALL:-}" ]; then
    if [ ! -f "$PRISMIO_TARBALL" ]; then
        fatal "Specified PRISMIO_TARBALL file does not exist: $PRISMIO_TARBALL"
    fi
    info "Using local tarball: $PRISMIO_TARBALL"
    CHOSEN_ARCHIVE="$PRISMIO_TARBALL"
elif [ -n "${PRISMIO_DOWNLOAD_URL:-}" ]; then
    info "Downloading from custom URL: $PRISMIO_DOWNLOAD_URL"
    TARGET_FILE="${TMP_DIR}/prismio-custom.tar.gz"
    if fetch "$PRISMIO_DOWNLOAD_URL" "$TARGET_FILE" && [ -s "$TARGET_FILE" ]; then
        CHOSEN_ARCHIVE="$TARGET_FILE"
        CHOSEN_URL="$PRISMIO_DOWNLOAD_URL"
    else
        fatal "Failed to download Prismio from $PRISMIO_DOWNLOAD_URL"
    fi
else
    GITHUB_RELEASE_BASE="https://github.com/prismio-lang/prismio/releases/download/${RELEASE_TAG}"
    
    CANDIDATE_NAMES="
prismio-${VERSION}-${ARCH_TRIPLE}-${PLATFORM_TRIPLE}.tar.gz
prismio-${VERSION}-${OS_NAME}-${ARCH_NAME}.tar.gz
prismio-${VERSION}-${ARCH_NAME}-${OS_NAME}.tar.gz
"

    DOWNLOAD_FOUND=0
    for CANDIDATE in $CANDIDATE_NAMES; do
        URL="${GITHUB_RELEASE_BASE}/${CANDIDATE}"
        TARGET_FILE="${TMP_DIR}/${CANDIDATE}"
        info "Attempting download: ${CANDIDATE}..."
        if fetch "$URL" "$TARGET_FILE" 2>/dev/null && [ -s "$TARGET_FILE" ]; then
            DOWNLOAD_FOUND=1
            CHOSEN_ARCHIVE="$TARGET_FILE"
            CHOSEN_URL="$URL"
            break
        fi
    done

    if [ "$DOWNLOAD_FOUND" -eq 0 ]; then
        error "Could not find a downloadable release archive for ${OS_NAME}-${ARCH_NAME} at:"
        error "  ${GITHUB_RELEASE_BASE}"
        printf "\n"
        printf "  If this release has not yet been published to GitHub releases,\n"
        printf "  you can install from source by following the instructions at:\n"
        printf "    ${C_MINT}https://docs.prismio.org/start/installation${RESET}\n\n"
        printf "  Or provide a pre-packaged tarball:\n"
        printf "    ${BOLD}PRISMIO_TARBALL=/path/to/archive.tar.gz sh install.sh${RESET}\n\n"
        exit 1
    fi
fi

# 5. Checksum verification
if [ -n "$CHOSEN_URL" ]; then
    CHECKSUM_URL="${CHOSEN_URL}.sha256"
    CHECKSUM_FILE="${TMP_DIR}/archive.sha256"
    if fetch "$CHECKSUM_URL" "$CHECKSUM_FILE" 2>/dev/null && [ -s "$CHECKSUM_FILE" ]; then
        info "Verifying SHA-256 checksum..."
        EXPECTED_HASH="$(awk '{print $1}' "$CHECKSUM_FILE" | head -n 1)"
        ACTUAL_HASH=""
        if command -v sha256sum >/dev/null 2>&1; then
            ACTUAL_HASH="$(sha256sum "$CHOSEN_ARCHIVE" | awk '{print $1}')"
        elif command -v shasum >/dev/null 2>&1; then
            ACTUAL_HASH="$(shasum -a 256 "$CHOSEN_ARCHIVE" | awk '{print $1}')"
        fi

        if [ -n "$ACTUAL_HASH" ]; then
            if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
                fatal "Checksum verification failed!\n  Expected: $EXPECTED_HASH\n  Actual:   $ACTUAL_HASH"
            fi
            success "Checksum verified"
        fi
    fi
fi

# 6. Extract archive
EXTRACT_DIR="${TMP_DIR}/extract"
mkdir -p "$EXTRACT_DIR"
info "Extracting archive..."
tar -xzf "$CHOSEN_ARCHIVE" -C "$EXTRACT_DIR"

SOURCE_ROOT=""
if [ -f "${EXTRACT_DIR}/bin/prismio" ]; then
    SOURCE_ROOT="${EXTRACT_DIR}"
else
    for entry in "${EXTRACT_DIR}"/*; do
        if [ -d "$entry" ] && [ -f "$entry/bin/prismio" ]; then
            SOURCE_ROOT="$entry"
            break
        fi
    done
fi

if [ -z "$SOURCE_ROOT" ] || [ ! -f "${SOURCE_ROOT}/bin/prismio" ]; then
    fatal "Corrupted or invalid Prismio archive: missing bin/prismio executable."
fi

# 7. Install to target directory
INSTALL_DIR="${PRISMIO_INSTALL:-$HOME/.prismio}"
mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/lib" "${INSTALL_DIR}/stdlib"

info "Installing to ${INSTALL_DIR}..."
cp -R "${SOURCE_ROOT}/bin"/* "${INSTALL_DIR}/bin/"
if [ -d "${SOURCE_ROOT}/lib" ]; then
    cp -R "${SOURCE_ROOT}/lib"/* "${INSTALL_DIR}/lib/"
fi
if [ -d "${SOURCE_ROOT}/stdlib" ]; then
    cp -R "${SOURCE_ROOT}/stdlib"/* "${INSTALL_DIR}/stdlib/"
fi
if [ -d "${SOURCE_ROOT}/third_party" ]; then
    mkdir -p "${INSTALL_DIR}/third_party"
    cp -R "${SOURCE_ROOT}/third_party"/* "${INSTALL_DIR}/third_party/"
fi
for meta in LICENSE CHANGELOG.md; do
    if [ -f "${SOURCE_ROOT}/${meta}" ]; then
        cp "${SOURCE_ROOT}/${meta}" "${INSTALL_DIR}/"
    fi
done

chmod +x "${INSTALL_DIR}/bin/prismio"
success "Installed toolchain binaries and standard library"

# 8. Configure Shell Profile PATH
PROFILE_UPDATED=""

update_profile() {
    target_profile="$1"
    line_export="export PRISMIO_INSTALL=\"$INSTALL_DIR\""
    line_path='export PATH="$PRISMIO_INSTALL/bin:$PATH"'

    if [ -f "$target_profile" ] && grep -Fq "PRISMIO_INSTALL" "$target_profile" 2>/dev/null; then
        return 0
    fi

    printf '\n# Prismio toolchain\n%s\n%s\n' "$line_export" "$line_path" >> "$target_profile"
    PROFILE_UPDATED="$target_profile"
}

case ":$PATH:" in
    *":${INSTALL_DIR}/bin:"*)
        # Already present on PATH
        ;;
    *)
        CURRENT_SHELL="$(basename "${SHELL:-}")"
        case "$CURRENT_SHELL" in
            zsh)
                ZSH_RC="${ZDOTDIR:-$HOME}/.zshrc"
                touch "$ZSH_RC"
                update_profile "$ZSH_RC"
                ;;
            bash)
                if [ -f "$HOME/.bashrc" ]; then
                    update_profile "$HOME/.bashrc"
                fi
                if [ -f "$HOME/.bash_profile" ]; then
                    update_profile "$HOME/.bash_profile"
                fi
                if [ -z "$PROFILE_UPDATED" ]; then
                    update_profile "$HOME/.profile"
                fi
                ;;
            fish)
                FISH_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
                mkdir -p "$(dirname "$FISH_CONF")"
                if [ ! -f "$FISH_CONF" ] || ! grep -Fq "PRISMIO_INSTALL" "$FISH_CONF" 2>/dev/null; then
                    printf '\n# Prismio toolchain\nset -gx PRISMIO_INSTALL "%s"\nfish_add_path "$PRISMIO_INSTALL/bin"\n' "$INSTALL_DIR" >> "$FISH_CONF"
                    PROFILE_UPDATED="$FISH_CONF"
                fi
                ;;
            *)
                update_profile "$HOME/.profile"
                ;;
        esac
        ;;
esac

# 9. Verify Installation
VERSION_OUTPUT="$("${INSTALL_DIR}/bin/prismio" --version 2>/dev/null | head -n 1 || true)"
[ -z "$VERSION_OUTPUT" ] && VERSION_OUTPUT="prismio $VERSION"

printf "\n"
printf "  ${C_GREEN}${BOLD}✓ Prismio installed successfully!${RESET}\n\n"
printf "    ${BOLD}Version:${RESET}   ${C_MINT}%s${RESET}\n" "$VERSION_OUTPUT"
printf "    ${BOLD}Location:${RESET}  %s\n\n" "${INSTALL_DIR}"

if [ -n "$PROFILE_UPDATED" ]; then
    printf "  ${C_SKY}•${RESET} Configured PATH in: ${DIM}%s${RESET}\n\n" "$PROFILE_UPDATED"
    printf "  ${BOLD}Next Steps:${RESET}\n"
    printf "    ${C_MINT}1.${RESET} Reload your shell or run:\n"
    printf "       ${BOLD}export PATH=\"%s/bin:\$PATH\"${RESET}\n\n" "${INSTALL_DIR}"
elif case ":$PATH:" in *":${INSTALL_DIR}/bin:"*) false;; *) true;; esac; then
    printf "  ${BOLD}Next Steps:${RESET}\n"
    printf "    ${C_MINT}1.${RESET} Add Prismio to your current terminal session:\n"
    printf "       ${BOLD}export PATH=\"%s/bin:\$PATH\"${RESET}\n\n" "${INSTALL_DIR}"
else
    printf "  ${BOLD}Next Steps:${RESET}\n"
fi

printf "    ${C_MINT}2.${RESET} Verify your installation:\n"
printf "       ${BOLD}prismio --version${RESET}\n\n"
printf "    ${C_MINT}3.${RESET} Run your first program:\n"
printf "       ${BOLD}prismio run main.psm${RESET}\n\n"
printf "  ${DIM}Documentation: ${C_MINT}https://docs.prismio.org${RESET}\n"
printf "\n"
