# --- Ensure script is run with bash ---
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with Bash. Please use 'bash installator/uninstall.sh'." >&2
    exit 1
fi

set -e # Exit on error

# --- Parse CLI arguments ---
REMOVE_ALL_FLAG=false
TARGET_USER_ARG=""
YES_FLAG=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --all|-a)
            REMOVE_ALL_FLAG=true
            shift
            ;;
        --target-user)
            TARGET_USER_ARG="$2"
            shift 2
            ;;
        --target-user=*)
            TARGET_USER_ARG="${1#*=}"
            shift
            ;;
        --yes|-y)
            YES_FLAG=true
            shift
            ;;
        --help|-h)
            echo "Usage: bash installator/uninstall.sh [--all] [--target-user <username>] [--yes|-y]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# --- Check for root privileges ---
if [ "$EUID" -eq 0 ]; then
    printf "${YELLOW}Script is running as root. Man page will be uninstalled automatically.\\n${NC}"
    RUN_AS_ROOT=true
else
    printf "${YELLOW}Script is NOT running as root. You will need to remove the man page manually if desired.\\n${NC}"
    RUN_AS_ROOT=false

    printf "\\n${YELLOW}Proceeding without root privileges means that the man page will need to be removed manually via 'sudo'.\\n${NC}"
    read -r -p "Do you want to proceed with a non-root uninstallation? (y/n) " REPLY
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
        echo "Uninstallation cancelled."
        exit 1
    fi
fi

# --- Variables and Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper to run commands as a specified user (preserves ownership when possible)
run_as_user() {
    local user="$1"; shift
    local cmd="$*"
    if [ "$EUID" -eq 0 ] && [ -n "$user" ] && [ "$user" != "root" ]; then
        sudo -u "$user" bash -lc "export HOME=\"$(getent passwd "$user" | cut -d: -f6)\"; $cmd"
    else
        bash -lc "$cmd"
    fi
}

# Determine target user/home for uninstallation. Honor --target-user when provided. When not running as root, operate on the current user.
TARGET_USER="$USER"
TARGET_HOME="$HOME"
INSTALL_DIR="$HOME/.local/share/speaker"

# If caller explicitly provided a target user via CLI, validate and use it
if [ -n "$TARGET_USER_ARG" ]; then
    TARGET_USER="$TARGET_USER_ARG"
    if ! getent passwd "$TARGET_USER" > /dev/null 2>&1; then
        echo "Error: user '$TARGET_USER' does not exist on this system." >&2
        exit 1
    fi
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    INSTALL_DIR="$TARGET_HOME/.local/share/speaker"
else
    if [ "$EUID" -eq 0 ]; then
        # Try to determine a logical non-root user when run as root (for targeted removals)
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            TARGET_USER="$SUDO_USER"
        else
            LOGNAME_USER=$(logname 2>/dev/null || true)
            if [ -n "$LOGNAME_USER" ] && [ "$LOGNAME_USER" != "root" ]; then
                TARGET_USER="$LOGNAME_USER"
            else
                WHO_USER=$(who am i 2>/dev/null | awk '{print $1}' || true)
                if [ -n "$WHO_USER" ] && [ "$WHO_USER" != "root" ]; then
                    TARGET_USER="$WHO_USER"
                fi
            fi
        fi
        if ! getent passwd "$TARGET_USER" > /dev/null 2>&1; then
            echo "Error: user '$TARGET_USER' does not exist on this system." >&2
            exit 1
        fi
        TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
        INSTALL_DIR="$TARGET_HOME/.local/share/speaker"
    fi
fi

printf "${YELLOW}This script will remove the Speaker tool and its configuration (target: $TARGET_USER).\\n${NC}"
printf "${RED}Note: this will remove installed files and shell integration; you can re-run the installer to restore components if needed.\\n${NC}"

# Confirmation prompt for general uninstallation; skip if --yes/-y provided
if [ "$YES_FLAG" = true ]; then
    echo "Auto-confirm enabled (--yes). Proceeding with uninstallation."
else
    # Non-root path had an earlier prompt; if running non-root, respect it unless --yes used
    read -r -p "Are you sure you want to continue? (y/n) " REPLY
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
        echo "Uninstallation cancelled."
        exit 1
    fi
fi

# --- Step 1: Remove the function from shell configuration files ---
printf "\\n${YELLOW}Step 1: Removing 'speak' function from shell configuration...\\n${NC}"

# Default removal behavior: when running as root, ask whether to remove for ALL users unless --all specified
REMOVE_ALL=false
if [ "$REMOVE_ALL_FLAG" = "true" ] && [ "$EUID" -ne 0 ]; then
    echo "Error: --all requires root privileges. Re-run with sudo." >&2
    exit 1
fi
if [ "$EUID" -eq 0 ]; then
    # If a target user was explicitly provided, do a targeted removal
    if [ -n "$TARGET_USER_ARG" ]; then
        REMOVE_ALL=false
    else
        # Ask whether to remove for all users
        read -r -p "Do you want to remove Speaker for ALL users on this system? (y/N) " REMOVE_ALL_REPLY
        echo
        if [[ "$REMOVE_ALL_REPLY" =~ ^[Yy]$ ]]; then
            REMOVE_ALL=true
        else
            REMOVE_ALL=false
        fi
    fi
fi

if [ "$REMOVE_ALL" = true ]; then
    # Iterate home directories and root
    for USER_HOME in /home/* /root; do
        [ -d "$USER_HOME" ] || continue
        # Remove function from bashrc
        if [ -f "$USER_HOME/.bashrc" ]; then
            cp "$USER_HOME/.bashrc" "$USER_HOME/.bashrc.bak.$(date +%F)" || true
            sed -i '/# --- Function for the Speaker tool ---/,/}/d' "$USER_HOME/.bashrc" || true
            echo "Removed function from $USER_HOME/.bashrc"
        fi
        # Remove function from zshrc
        if [ -f "$USER_HOME/.zshrc" ]; then
            cp "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.bak.$(date +%F)" || true
            sed -i '/# --- Function for the Speaker tool ---/,/}/d' "$USER_HOME/.zshrc" || true
            echo "Removed function from $USER_HOME/.zshrc"
        fi
        # Remove application dir
        if [ -d "$USER_HOME/.local/share/speaker" ]; then
            rm -rf "$USER_HOME/.local/share/speaker" || true
            echo "Removed directory $USER_HOME/.local/share/speaker"
        fi
    done
else
    # Targeted removal for the selected user
    if [ -f "$TARGET_HOME/.bashrc" ]; then
        # Create a backup and remove the function (do it as the target user when possible)
        if [ "$EUID" -eq 0 ]; then
            run_as_user "$TARGET_USER" "cp \"$TARGET_HOME/.bashrc\" \"$TARGET_HOME/.bashrc.bak.$(date +%F)\" || true; sed -i '/# --- Function for the Speaker tool ---/,/}/d' \"$TARGET_HOME/.bashrc\" || true; echo 'Removed function from $TARGET_HOME/.bashrc'"
        else
            cp "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bashrc.bak.$(date +%F)" || true
            sed -i '/# --- Function for the Speaker tool ---/,/}/d' "$TARGET_HOME/.bashrc" || true
            echo "Removed function from $TARGET_HOME/.bashrc"
        fi
    fi

    if [ -f "$TARGET_HOME/.zshrc" ]; then
        if [ "$EUID" -eq 0 ]; then
            run_as_user "$TARGET_USER" "cp \"$TARGET_HOME/.zshrc\" \"$TARGET_HOME/.zshrc.bak.$(date +%F)\" || true; sed -i '/# --- Function for the Speaker tool ---/,/}/d' \"$TARGET_HOME/.zshrc\" || true; echo 'Removed function from $TARGET_HOME/.zshrc'"
        else
            cp "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zshrc.bak.$(date +%F)" || true
            sed -i '/# --- Function for the Speaker tool ---/,/}/d' "$TARGET_HOME/.zshrc" || true
            echo "Removed function from $TARGET_HOME/.zshrc"
        fi
    fi

    # --- Step 2: Remove the application directory ---
printf "\\n${YELLOW}Step 2: Removing application directory...\\n${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed directory $INSTALL_DIR"
    else
        echo "Directory $INSTALL_DIR does not exist. Skipping."
    fi
fi

# --- Step 3: Remove Man Page (conditional on root privileges) ---
printf "\\n${YELLOW}Step 3: Removing Man Page...${NC}\\n"
if [ "$RUN_AS_ROOT" = true ]; then
    if [ -f "/usr/local/share/man/man1/speak.1.gz" ]; then
        rm "/usr/local/share/man/man1/speak.1.gz"
        mandb
        echo "Man page for 'speak' removed."
    else
        echo "Man page not found at /usr/local/share/man/man1/speak.1.gz. Skipping removal."
    fi
else
    echo "Man page removal requires root privileges. Please remove it manually if desired:"
    printf "${YELLOW}sudo rm /usr/local/share/man/man1/speak.1.gz\\n${NC}"
    printf "${YELLOW}sudo mandb\\n${NC}"
fi

# --- Step 4: Optional: Remove mpg123 (conditional on root privileges) ---
printf "\\n${YELLOW}Step 4: Optional: Removing mpg123...${NC}\\n"
if [ "$RUN_AS_ROOT" = true ]; then
    if [ "$YES_FLAG" = true ]; then
        REMOVE_MPG123_REPLY="y"
        echo "Auto-confirm enabled: removing mpg123 (if present)."
    else
        read -r -p "Do you want to remove the 'mpg123' package from your system? (y/n) " REMOVE_MPG123_REPLY
        echo
    fi
    if [[ "$REMOVE_MPG123_REPLY" =~ ^[Yy]$ ]]
    then
        PACKAGE_MANAGER_UNINSTALL_CMD=""
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER_UNINSTALL_CMD="apt-get remove -y"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER_UNINSTALL_CMD="dnf remove -y"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER_UNINSTALL_CMD="yum remove -y"
        elif command -v pacman &> /dev/null; then
            PACKAGE_MANAGER_UNINSTALL_CMD="pacman -Rns --noconfirm"
        fi

        if [ -n "$PACKAGE_MANAGER_UNINSTALL_CMD" ]; then
            $PACKAGE_MANAGER_UNINSTALL_CMD mpg123
            echo "mpg123 has been removed."
        else
            printf "${YELLOW}Could not determine package manager to remove mpg123. Please remove it manually.${NC}\\n"
        fi
    else
        echo "'mpg123' removal skipped."
    fi
else
    echo "The 'mpg123' package may still be installed. If you wish to remove it, you can do so manually, e.g., via:"
    printf "${YELLOW}sudo apt-get remove mpg123${NC}\\n"
fi

# --- Completion ---
printf "\\n${GREEN}Uninstallation completed successfully!${NC}\\n"
echo "For the changes to take effect, please restart your terminal or run:"
printf "${YELLOW}source ~/.bashrc${NC} or ${YELLOW}source ~/.zshrc${NC}\\n"
