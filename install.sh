#!/usr/bin/env bash
# install.sh — multi-distro installer for best-linux-conf.
# Detects Fedora / Arch / Ubuntu (and derivatives) via /etc/os-release,
# installs runtime + build deps for waybar, symlinks repo files into place,
# backs up existing configs, and verifies the result.
#
# Usage: ./install.sh [options]
#   --check-only      Print the plan and exit
#   --dry-run         Print commands without executing
#   --theme NAME      Set initial theme (default: tokyo-night)
#   --no-backup       Skip backup of existing configs
#   --uninstall       Run uninstall flow instead
#   -y, --yes         Skip all confirmation prompts

set -euo pipefail

# ---- Constants ----------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
WAYBAR_DIR="${REPO_DIR}/config/waybar"
NIRI_DIR="${REPO_DIR}/niri"
MAKO_DIR="${REPO_DIR}/config/mako"
FUZZEL_DIR="${REPO_DIR}/config/fuzzel"
LOCAL_BIN="${HOME}/.local/bin"
TS="$(date +%Y%m%d-%H%M%S)"

CHECK_ONLY=false
DRY_RUN=false
THEME="tokyo-night"
NO_BACKUP=false
UNINSTALL=false
ASSUME_YES=false

# ---- Arg parse ----------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --check-only)  CHECK_ONLY=true ;;
        --dry-run)     DRY_RUN=true; CHECK_ONLY=true ;;
        --theme=*)     THEME="${arg#*=}" ;;
        --theme)       shift; THEME="${1:-tokyo-night}" ;;
        --no-backup)   NO_BACKUP=true ;;
        --uninstall)   UNINSTALL=true ;;
        -y|--yes)      ASSUME_YES=true ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

# ---- Helpers ------------------------------------------------------------

log()  { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }
fail() { echo "error: $*" >&2; exit 1; }

run() {
    if $DRY_RUN; then
        echo "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

confirm() {
    $ASSUME_YES && return 0
    local prompt="$1"
    read -rp "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

trap 'echo "interrupted — partial state may be in place" >&2; exit 130' INT TERM

# ---- Distro detection ---------------------------------------------------

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    elif [ -f /usr/lib/os-release ]; then
        . /usr/lib/os-release
    else
        fail "cannot read /etc/os-release — unsupported system"
    fi
    case "${ID:-unknown}" in
        fedora)         PM="dnf";   INSTALL=(sudo dnf install -y); FAMILY="fedora" ;;
        arch|manjaro|endeavouros)
                        PM="pacman"; INSTALL=(sudo pacman -S --noconfirm --needed); FAMILY="arch" ;;
        ubuntu|pop|linuxmint|elementary|zorin)
                        PM="apt";   INSTALL=(sudo apt install -y); FAMILY="debian" ;;
        debian)         PM="apt";   INSTALL=(sudo apt install -y); FAMILY="debian" ;;
        *) fail "unsupported distro: ${ID:-unknown} (${PRETTY_NAME:-}). Manual install: https://github.com/Alexays/Waybar" ;;
    esac
    log "Detected: ${PRETTY_NAME:-$ID} (using $PM)"
}

# ---- Package maps -------------------------------------------------------
# Map a logical name to a distro-specific package (space-separated for multiple).

pkg_for() {
    local key="$1" fam="$2"
    case "$fam" in
        fedora)
            case "$key" in
                waybar)        echo "waybar" ;;
                niri)          echo "" ;;  # not in Fedora repos — skip
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber wireplumber-libs" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "NetworkManager-tui" ;;
                bluetooth)     echo "bluez bluez-tools" ;;
                tlp)           echo "tlp tlp-rdw" ;;
                ppd)           echo "power-profiles-daemon" ;;
                brightnessctl) echo "brightnessctl" ;;
                wpctl)         echo "" ;;  # comes with wireplumber
                grim)          echo "grim" ;;
                slurp)         echo "slurp" ;;
                swappy)        echo "swappy" ;;
                swaybg)        echo "swaybg" ;;
                zenity)        echo "zenity" ;;
                notify-send)   echo "libnotify" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "jetbrains-mono-fonts" ;;
                font-icons)    echo "fontawesome-fonts" ;;
                checkupdates)  echo "pacman-contrib" ;;  # for arch compat
                *)             echo "" ;;
            esac
            ;;
        arch)
            case "$key" in
                waybar)        echo "waybar" ;;
                niri)          echo "niri" ;;
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "networkmanager" ;;
                bluetooth)     echo "bluez bluez-utils" ;;
                tlp)           echo "tlp" ;;
                ppd)           echo "power-profiles-daemon" ;;
                brightnessctl) echo "brightnessctl" ;;
                wpctl)         echo "wireplumber" ;;
                grim)          echo "grim" ;;
                slurp)         echo "slurp" ;;
                swappy)        echo "swappy" ;;
                swaybg)        echo "swaybg" ;;
                zenity)        echo "zenity" ;;
                notify-send)   echo "libnotify" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "ttf-jetbrains-mono" ;;
                font-icons)    echo "ttf-font-awesome" ;;
                checkupdates)  echo "pacman-contrib" ;;
                *)             echo "" ;;
            esac
            ;;
        debian)
            case "$key" in
                waybar)        echo "waybar" ;;  # may need PPA
                niri)          echo "" ;;  # not packaged — skip
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "network-manager" ;;
                bluetooth)     echo "bluez" ;;
                tlp)           echo "tlp" ;;
                ppd)           echo "power-profiles-daemon" ;;
                brightnessctl) echo "brightnessctl" ;;
                wpctl)         echo "wireplumber" ;;
                grim)          echo "grim" ;;
                slurp)         echo "slurp" ;;
                swappy)        echo "swappy" ;;
                swaybg)        echo "swaybg" ;;
                zenity)        echo "zenity" ;;
                notify-send)   echo "libnotify-bin" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "fonts-jetbrains-mono" ;;
                font-icons)    echo "fonts-font-awesome" ;;
                checkupdates)  echo "" ;;
                *)             echo "" ;;
            esac
            ;;
    esac
}

REQUIRED_KEYS=(
    waybar fuzzel mako wireplumber playerctl networkmanager bluetooth
    brightnessctl grim slurp swappy swaybg zenity notify-send
    pavucontrol font-mono font-icons
)

OPTIONAL_KEYS=(
    tlp ppd checkupdates niri
)

missing_packages() {
    local missing=()
    local key pkg
    for key in "$@"; do
        pkg="$(pkg_for "$key" "$FAMILY")"
        [ -z "$pkg" ] && continue
        # shellcheck disable=SC2086
        for p in $pkg; do
            if ! rpm -q "$p" >/dev/null 2>&1 && ! dpkg -s "$p" >/dev/null 2>&1; then
                missing+=("$p")
            fi
        done
    done
    printf '%s\n' "${missing[@]}"
}

# ---- Backup -------------------------------------------------------------

backup_path() {
    local p="$1"
    [ -e "$p" ] || return 0
    $NO_BACKUP && { warn "skipping backup of $p (--no-backup)"; return 0; }
    local bak="${p}.bak.${TS}"
    log "backing up $p -> $bak"
    run mv "$p" "$bak"
}

# ---- Symlink ------------------------------------------------------------

symlink() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        run rm "$dst"
    elif [ -e "$dst" ]; then
        backup_path "$dst"
    fi
    run ln -sfn "$src" "$dst"
}

# ---- Uninstall ----------------------------------------------------------

do_uninstall() {
    log "Uninstall: stopping daemons"
    pkill -x waybar 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
    sleep 1

    log "Removing symlinks in $LOCAL_BIN"
    for s in "$LOCAL_BIN"/tokyo-niri-* "$LOCAL_BIN"/waybar-*.sh "$LOCAL_BIN"/theme-switch.sh; do
        [ -L "$s" ] || continue
        run rm "$s"
    done

    for d in waybar niri mako fuzzel; do
        target="${HOME}/.config/${d}"
        if [ -L "$target" ]; then
            log "removing symlink $target"
            run rm "$target"
        fi
    done

    # Restore newest .bak
    for d in waybar niri mako fuzzel; do
        target="${HOME}/.config/${d}"
        [ ! -L "$target" ] || continue
        local newest=""
        for bak in "${target}".bak.*; do
            [ -d "$bak" ] || continue
            [ -z "$newest" ] && newest="$bak" || [ "$bak" -nt "$newest" ] && newest="$bak"
        done
        if [ -n "$newest" ]; then
            log "restoring $newest -> $target"
            run mv "$newest" "$target"
        fi
    done

    log "Uninstall complete. Manual cleanup: ~/.config/*.bak.* directories."
}

# ---- Main flow ----------------------------------------------------------

if $UNINSTALL; then
    detect_distro
    do_uninstall
    exit 0
fi

detect_distro

log "Plan:"
echo "  Repo:          $REPO_DIR"
echo "  Distro:        ${ID} (${FAMILY})"
echo "  Package mgr:   $PM"
echo "  Initial theme: $THEME"
echo "  Local bin:     $LOCAL_BIN"
echo

log "Checking required packages..."
MISSING=()
while IFS= read -r p; do
    [ -n "$p" ] && MISSING+=("$p")
done < <(missing_packages "${REQUIRED_KEYS[@]}")

if [ ${#MISSING[@]} -gt 0 ]; then
    log "Missing required packages: ${MISSING[*]}"
    if $CHECK_ONLY; then
        log "  (would prompt to install; skipping in --check-only)"
    elif confirm "Install them now with $PM?"; then
        run "${INSTALL[@]}" "${MISSING[@]}"
    else
        fail "refusing to continue without required packages"
    fi
else
    log "All required packages already installed"
fi

log "Checking optional packages..."
OPT_MISSING=()
while IFS= read -r p; do
    [ -n "$p" ] && OPT_MISSING+=("$p")
done < <(missing_packages "${OPTIONAL_KEYS[@]}")
if [ ${#OPT_MISSING[@]} -gt 0 ]; then
    log "Optional packages available: ${OPT_MISSING[*]}"
    if $CHECK_ONLY; then
        log "  (would prompt to install; skipping in --check-only)"
    elif confirm "Install optional packages (tlp, power-profiles-daemon)?"; then
        run "${INSTALL[@]}" "${OPT_MISSING[@]}"
    fi
fi

if $CHECK_ONLY; then
    log "Check complete — exiting (--check-only)"
    exit 0
fi

log "Backing up existing configs"
for d in waybar niri mako fuzzel; do
    target="${HOME}/.config/${d}"
    [ -e "$target" ] || continue
    if [ -L "$target" ]; then
        log "removing existing symlink $target"
        run rm "$target"
    else
        backup_path "$target"
    fi
done

log "Symlinking repo files"
run mkdir -p "$LOCAL_BIN"

# Directories: symlink the whole config dir
symlink "$WAYBAR_DIR" "${HOME}/.config/waybar"
symlink "$NIRI_DIR"   "${HOME}/.config/niri"
symlink "$MAKO_DIR"   "${HOME}/.config/mako"
symlink "$FUZZEL_DIR" "${HOME}/.config/fuzzel"

# Scripts: one symlink per file
for s in "$SCRIPTS_DIR"/*; do
    [ -x "$s" ] || continue
    name="$(basename "$s")"
    symlink "$s" "${LOCAL_BIN}/${name}"
done
# ensure executable perms on the source files (idempotent)
run chmod +x "$SCRIPTS_DIR"/*

log "Setting initial theme: $THEME"
run "$SCRIPTS_DIR/theme-switch.sh" "$THEME"

log "Verifying waybar"
if command -v waybar >/dev/null 2>&1; then
    WAYBAR_VERSION=$(waybar --version 2>/dev/null | awk '{print $1}')
    log "waybar $WAYBAR_VERSION installed"
else
    fail "waybar not found after install"
fi

if pgrep -x waybar >/dev/null 2>&1; then
    log "waybar already running — sending SIGUSR2 to reload"
    pkill -SIGUSR2 -x waybar
else
    if confirm "Start waybar now?"; then
        nohup waybar -c "${HOME}/.config/waybar/config.jsonc" \
                     -s "${HOME}/.config/waybar/style.css" \
                     >/tmp/tokyo-niri-waybar-top.log 2>&1 &
        sleep 1
        if pgrep -x waybar >/dev/null 2>&1; then
            log "waybar started"
        else
            warn "waybar failed to start — check /tmp/tokyo-niri-waybar-top.log"
        fi
    fi
fi

log "Done."
echo
echo "Next steps:"
echo "  - Switch theme:        theme-switch.sh catppuccin"
echo "  - Live-reload waybar:  waybar-reload.sh"
echo "  - Recovery:            mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken"
echo "  - Backups live at:     ~/.config/*.bak.${TS}"
