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
PORTAL_DIR="${REPO_DIR}/config/xdg-desktop-portal"
CONFIG_DIRS=(waybar niri mako fuzzel xdg-desktop-portal)
LOCAL_BIN="${HOME}/.local/bin"
TS="$(date +%Y%m%d-%H%M%S)"

CHECK_ONLY=false
DRY_RUN=false
THEME="tokyo-night"
NO_BACKUP=false
UNINSTALL=false
ASSUME_YES=false

# ---- Arg parse ----------------------------------------------------------

PKG_FOR_QUERY=""

while [ $# -gt 0 ]; do
    case "$1" in
        --check-only)  CHECK_ONLY=true ;;
        --dry-run)     DRY_RUN=true; CHECK_ONLY=true ;;
        --theme=*)     THEME="${1#*=}" ;;
        --theme)       shift; THEME="${1:?--theme requires a value}" ;;
        --no-backup)   NO_BACKUP=true ;;
        --uninstall)   UNINSTALL=true ;;
        --pkg-for)     shift; PKG_FOR_QUERY="${1:?--pkg-for requires key:family}" ;;
        -y|--yes)      ASSUME_YES=true ;;
        -h|--help)
            sed -n '2,13p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
    shift
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
    # Match on ID first, then fall back to ID_LIKE so derivatives
    # (e.g. pop, garuda, nobara, tumbleweed) map to the right family.
    local candidates="${ID:-unknown} ${ID_LIKE:-}"
    FAMILY=""
    for id in $candidates; do
        case "$id" in
            fedora|rhel|centos)        FAMILY="fedora"; break ;;
            arch|archlinux|manjaro|endeavouros) FAMILY="arch"; break ;;
            debian|ubuntu|pop|linuxmint|elementary|zorin) FAMILY="debian"; break ;;
            opensuse*|suse|sles)       FAMILY="suse"; break ;;
        esac
    done
    case "$FAMILY" in
        fedora) PM="dnf";    INSTALL=(sudo dnf install -y) ;;
        arch)   PM="pacman"; INSTALL=(sudo pacman -S --noconfirm --needed) ;;
        debian) PM="apt";    INSTALL=(sudo apt install -y) ;;
        suse)   PM="zypper"; INSTALL=(sudo zypper install -y) ;;
        *) fail "unsupported distro: ${ID:-unknown} (${PRETTY_NAME:-}). Manual install: https://github.com/Alexays/Waybar" ;;
    esac
    log "Detected: ${PRETTY_NAME:-$ID} (family: $FAMILY, using $PM)"
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
                portal)        echo "xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk" ;;
                pipewire)      echo "pipewire pipewire-pulseaudio" ;;
                lockscreen)    echo "swaylock swayidle" ;;
                wl-clipboard)  echo "wl-clipboard" ;;
                imagemagick)   echo "ImageMagick" ;;
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
                portal)        echo "xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk" ;;
                pipewire)      echo "pipewire pipewire-pulse" ;;
                lockscreen)    echo "swaylock swayidle" ;;
                wl-clipboard)  echo "wl-clipboard" ;;
                imagemagick)   echo "imagemagick" ;;
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
                mako)          echo "mako-notifier" ;;  # NOT "mako" (that name is taken by a python lib)
                wireplumber)   echo "wireplumber" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "network-manager" ;;
                portal)        echo "xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk" ;;
                pipewire)      echo "pipewire pipewire-pulse" ;;
                lockscreen)    echo "swaylock swayidle" ;;
                wl-clipboard)  echo "wl-clipboard" ;;
                imagemagick)   echo "imagemagick" ;;
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
        suse)
            case "$key" in
                waybar)        echo "waybar" ;;
                niri)          echo "niri" ;;
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "NetworkManager" ;;
                portal)        echo "xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk" ;;
                pipewire)      echo "pipewire pipewire-pulseaudio" ;;
                lockscreen)    echo "swaylock swayidle" ;;
                wl-clipboard)  echo "wl-clipboard" ;;
                imagemagick)   echo "ImageMagick" ;;
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
                notify-send)   echo "libnotify-tools" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "jetbrains-mono-fonts" ;;
                font-icons)    echo "fontawesome-fonts" ;;
                checkupdates)  echo "" ;;
                *)             echo "" ;;
            esac
            ;;
    esac
}

# Test/debug hook: ./install.sh --pkg-for mako:debian prints the mapping and exits.
if [ -n "$PKG_FOR_QUERY" ]; then
    pkg_for "${PKG_FOR_QUERY%%:*}" "${PKG_FOR_QUERY#*:}"
    exit 0
fi

REQUIRED_KEYS=(
    waybar fuzzel mako wireplumber playerctl networkmanager bluetooth
    brightnessctl grim slurp swaybg zenity notify-send
    pavucontrol font-mono font-icons
    portal pipewire lockscreen wl-clipboard
)

# swappy is optional: not packaged on some distros (e.g. Ubuntu 24.04);
# tokyo-niri-screenshot falls back to plain grim when it's absent.
# imagemagick is only needed for the blurred lock-screen background.
OPTIONAL_KEYS=(
    swappy imagemagick tlp ppd checkupdates niri
)

pkg_installed() {
    local p="$1"
    case "$FAMILY" in
        debian)      dpkg -s "$p" >/dev/null 2>&1 ;;
        arch)        pacman -Qi "$p" >/dev/null 2>&1 ;;
        fedora|suse) rpm -q "$p" >/dev/null 2>&1 ;;
    esac
}

# Is the package installable from the configured repos?
pkg_available() {
    local p="$1"
    case "$FAMILY" in
        debian) LC_ALL=C apt-cache policy "$p" 2>/dev/null \
                    | awk '/Candidate:/ && $2 != "(none)" {ok=1} END {exit !ok}' ;;
        arch)   pacman -Si "$p" >/dev/null 2>&1 ;;
        fedora) LC_ALL=C dnf --cacheonly info "$p" >/dev/null 2>&1 \
                    || LC_ALL=C dnf info "$p" >/dev/null 2>&1 ;;
        suse)   LC_ALL=C zypper --non-interactive info "$p" 2>/dev/null \
                    | grep -q '^Version' ;;
    esac
}

missing_packages() {
    local missing=()
    local key pkg
    for key in "$@"; do
        pkg="$(pkg_for "$key" "$FAMILY")"
        [ -z "$pkg" ] && continue
        # shellcheck disable=SC2086
        for p in $pkg; do
            pkg_installed "$p" || missing+=("$p")
        done
    done
    printf '%s\n' "${missing[@]}"
}

# Split a list of packages into INSTALLABLE / UNAVAILABLE based on the repos.
# A single unknown name would abort the whole apt/dnf transaction, so weed
# them out up front and report them instead.
split_by_availability() {
    INSTALLABLE=()
    UNAVAILABLE=()
    local p
    for p in "$@"; do
        if pkg_available "$p"; then
            INSTALLABLE+=("$p")
        else
            UNAVAILABLE+=("$p")
        fi
    done
}

report_unavailable() {
    warn "not found in your configured repos: $*"
    case "$FAMILY" in
        debian)
            if [ "${ID:-}" = "ubuntu" ]; then
                warn "  hint: most of these live in 'universe' — try: sudo add-apt-repository universe && sudo apt update"
            else
                warn "  hint: check that 'contrib' is enabled, or install manually"
            fi
            ;;
        suse) warn "  hint: some packages need an extra OBS repo (e.g. X11:Wayland)" ;;
    esac
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
    pkill -x swayidle 2>/dev/null || true
    pkill -x swaybg 2>/dev/null || true
    sleep 1

    log "Removing symlinks in $LOCAL_BIN"
    for s in "$LOCAL_BIN"/tokyo-niri-* "$LOCAL_BIN"/waybar-*.sh "$LOCAL_BIN"/theme-switch.sh; do
        [ -L "$s" ] || continue
        run rm "$s"
    done

    for d in "${CONFIG_DIRS[@]}"; do
        target="${HOME}/.config/${d}"
        if [ -L "$target" ]; then
            log "removing symlink $target"
            run rm "$target"
        fi
    done

    # Restore newest .bak
    for d in "${CONFIG_DIRS[@]}"; do
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
    else
        # Refresh apt lists first: stale lists make pkg_available lie and
        # apt install fail on perfectly valid names.
        if [ "$FAMILY" = "debian" ]; then
            run sudo apt update
        fi
        split_by_availability "${MISSING[@]}"
        if [ ${#UNAVAILABLE[@]} -gt 0 ]; then
            report_unavailable "${UNAVAILABLE[@]}"
        fi
        if [ ${#INSTALLABLE[@]} -gt 0 ]; then
            if confirm "Install ${INSTALLABLE[*]} with $PM?"; then
                run "${INSTALL[@]}" "${INSTALLABLE[@]}"
            else
                fail "refusing to continue without required packages"
            fi
        fi
        if [ ${#UNAVAILABLE[@]} -gt 0 ] && ! confirm "Continue without ${UNAVAILABLE[*]}?"; then
            fail "aborted — install the missing packages manually, then re-run"
        fi
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
    if $CHECK_ONLY; then
        log "Optional packages missing: ${OPT_MISSING[*]}"
        log "  (would prompt to install; skipping in --check-only)"
    else
        split_by_availability "${OPT_MISSING[@]}"
        if [ ${#UNAVAILABLE[@]} -gt 0 ]; then
            log "Optional packages not in your repos (skipping): ${UNAVAILABLE[*]}"
        fi
        if [ ${#INSTALLABLE[@]} -gt 0 ]; then
            log "Optional packages available: ${INSTALLABLE[*]}"
            if confirm "Install optional packages (${INSTALLABLE[*]})?"; then
                run "${INSTALL[@]}" "${INSTALLABLE[@]}"
            fi
        fi
    fi
fi

if $CHECK_ONLY; then
    log "Check complete — exiting (--check-only)"
    exit 0
fi

log "Backing up existing configs"
for d in "${CONFIG_DIRS[@]}"; do
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
symlink "$PORTAL_DIR" "${HOME}/.config/xdg-desktop-portal"

# Local state dir for wallpaper / lock-wallpaper (user content, not symlinked)
run mkdir -p "${HOME}/.config/tokyo-niri"

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
    WAYBAR_VERSION=$(waybar --version 2>/dev/null | awk '{print $2}')
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
