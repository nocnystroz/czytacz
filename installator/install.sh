#!/bin/bash

# Installation script for the Speaker tool
# Run this script from the main repository directory, e.g., by: bash installator/install.sh

# --- Ensure script is run with bash ---
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with Bash. Please use 'bash installator/install.sh'." >&2
    exit 1
fi

set -e # Exit on error

# --- Check for root privileges ---
if [ "$EUID" -eq 0 ]; then
    printf "${YELLOW}Script is running as root. Man page installation and mpg123 will be handled automatically.\\n${NC}"
    RUN_AS_ROOT=true
else
    printf "${YELLOW}Script is NOT running as root. You will be prompted for sudo password for system dependencies, and man page installation will require manual steps.\\n${NC}"
    RUN_AS_ROOT=false

    printf "\\n${YELLOW}Proceeding without root privileges means some system-level components (like 'mpg123' and the man page) will either require manual 'sudo' input during the process or manual installation afterwards.\\n${NC}"
    read -r -p "Do you want to proceed with a non-root installation? (y/n) " REPLY
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
        echo "Installation cancelled."
        exit 1
    fi
fi


# --- Variables and Colors ---
SCRIPT_DIR=$(dirname "$(readlink -f "$0")") # Get absolute path to script's directory (installator/)
REPO_DIR=$(dirname "$SCRIPT_DIR")           # Parent directory is the repo root

# If run as root, try to determine the non-root invoking user (SUDO_USER) and
# fall back to other heuristics (logname, who am i). If none found, prompt for a
# target user. When not running as root, use the current $HOME/$USER.
if [ "$EUID" -eq 0 ]; then
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        INSTALL_USER="$SUDO_USER"
    else
        # Try logname (the user who logged in)
        LOGNAME_USER=$(logname 2>/dev/null || true)
        if [ -n "$LOGNAME_USER" ] && [ "$LOGNAME_USER" != "root" ]; then
            INSTALL_USER="$LOGNAME_USER"
        else
            # Try parsing "who am i" output
            WHO_USER=$(who am i 2>/dev/null | awk '{print $1}' || true)
            if [ -n "$WHO_USER" ] && [ "$WHO_USER" != "root" ]; then
                INSTALL_USER="$WHO_USER"
            else
                # No non-root user auto-detected — ask the operator
                read -r -p "No non-root invoking user detected. Enter target username for installation (leave empty to install for root): " INPUT_USER
                if [ -n "$INPUT_USER" ]; then
                    INSTALL_USER="$INPUT_USER"
                else
                    INSTALL_USER="root"
                fi
            fi
        fi
    fi
    # Validate that the selected user exists
    if ! getent passwd "$INSTALL_USER" > /dev/null 2>&1; then
        echo "Error: user '$INSTALL_USER' does not exist on this system." >&2
        exit 1
    fi
    INSTALL_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)
    INSTALL_DIR="$INSTALL_HOME/.local/share/speaker"
else
    INSTALL_USER="$USER"
    INSTALL_HOME="$HOME"
    INSTALL_DIR="$HOME/.local/share/speaker"
fi

# Helper to run commands as the target (non-root) user when possible
run_as_user() {
    local cmd="$*"
    if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        sudo -u "$INSTALL_USER" bash -lc "export HOME=\"$INSTALL_HOME\"; $cmd"
    else
        bash -lc "$cmd"
    fi
}

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "${GREEN}Starting installation of the Speaker tool...${NC}\\n"

# --- Step 1: Detect package manager and install mpg123 ---
printf "\\n${YELLOW}Step 1: Checking system dependencies (mpg123)...${NC}\\n"

if command -v mpg123 &> /dev/null; then
    echo "mpg123 is already installed."
else
    echo "mpg13 not found."
    # Ask before attempting to install system dependency with sudo when not running as root
    if [ "$RUN_AS_ROOT" = true ]; then
        INSTALL_MPG123_NOW=true
    else
        INSTALL_MPG123_NOW=false
        if command -v sudo &> /dev/null; then
            read -r -p "Install mpg123 now using sudo (this will run package manager commands)? (y/N) " REPLY_MPG
            echo
            if [[ "$REPLY_MPG" =~ ^[Yy]$ ]]; then
                INSTALL_MPG123_NOW=true
            fi
        else
            echo "sudo not available: skipping automatic installation of mpg123. Please install manually if needed."
        fi
    fi

    # Determine package manager and install mpg123
    PACKAGE_MANAGER_INSTALL_CMD=""
    if [ "$INSTALL_MPG123_NOW" = true ]; then
        if command -v apt-get &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                apt-get update && apt-get install -y mpg123
            else
                sudo apt-get update && sudo apt-get install -y mpg123
            fi
            PACKAGE_MANAGER_INSTALL_CMD="apt-get install -y"
        elif command -v dnf &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                dnf install -y mpg123
            else
                sudo dnf install -y mpg123
            fi
            PACKAGE_MANAGER_INSTALL_CMD="dnf install -y"
        elif command -v yum &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                yum install -y mpg123
            else
                sudo yum install -y mpg123
            fi
            PACKAGE_MANAGER_INSTALL_CMD="yum install -y"
        elif command -v pacman &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
            pacman -S --noconfirm mpg123
        else
            sudo pacman -S --noconfirm mpg123
        fi
        PACKAGE_MANAGER_INSTALL_CMD="pacman -S --noconfirm"
    else
        printf "${YELLOW}Could not automatically install mpg123. Please install it manually.${NC}\\n" >&2
        exit 1
    fi
    echo "mpg123 has been successfully installed."
fi

# --- Step 2: Create directory structure and copy files ---
printf "\\n${YELLOW}Step 2: Preparing application directory in $INSTALL_DIR...${NC}\\n"
mkdir -p "$INSTALL_DIR"
cp "$REPO_DIR/speaker.py" "$INSTALL_DIR/"
cp "$REPO_DIR/requirements.txt" "$INSTALL_DIR/"
cp "$REPO_DIR/.env.example" "$INSTALL_DIR/"
# If an install-time .env does not exist, offer to copy the project's .env or the example
if [ ! -f "$INSTALL_DIR/.env" ]; then
    if [ -f "$REPO_DIR/.env" ]; then
        # Automatically copy project .env into install dir to ensure installed 'speak' sees user's keys
        cp "$REPO_DIR/.env" "$INSTALL_DIR/.env"
        echo "Copied project .env to $INSTALL_DIR/.env (using repository .env)."
        echo "If you prefer not to copy it automatically, edit the installer script."
    else
        read -r -p "No .env found in install dir. Create $INSTALL_DIR/.env from .env.example now? (y/N) " REPLY_EX
        if [[ "$REPLY_EX" =~ ^[Yy]$ ]]; then
            cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
            echo "Created $INSTALL_DIR/.env from .env.example — please edit it with your API keys."
            read -r -p "Have you edited $INSTALL_DIR/.env and added your API keys and want to continue installation? (y/N) " REPLY_EDIT
            if [[ ! "$REPLY_EDIT" =~ ^[Yy]$ ]]; then
                echo "Installation aborted: please edit $INSTALL_DIR/.env with your API keys and re-run the installer." >&2
                exit 1
            fi
        else
            read -r -p "Have you already created and edited $INSTALL_DIR/.env with API keys and want to continue installation? (y/N) " REPLY_CONT2
            if [[ ! "$REPLY_CONT2" =~ ^[Yy]$ ]]; then
                echo "Installation aborted: please create and fill $INSTALL_DIR/.env with your API keys before installing." >&2
                exit 1
            fi
        fi
    fi
fi

# If installer was run as root on behalf of another user, ensure the copied files are owned by that user
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    echo "Adjusting ownership of $INSTALL_DIR to user $INSTALL_USER"
    chown -R "$INSTALL_USER":"$INSTALL_USER" "$INSTALL_DIR" || true
fi

# Warn user if .env exists but may be missing keys
if [ -f "$INSTALL_DIR/.env" ]; then
    echo "Note: ensure API keys (e.g., GEMINI_API_KEY, OPENAI_API_KEY) are set in $INSTALL_DIR/.env. Without valid API keys, summarization (LLM) will not be available."
fi
printf "Application files have been copied to %s.\\n" "$INSTALL_DIR"

# --- Step 3: Create virtual environment and install Python dependencies ---
printf "\\n${YELLOW}Step 3: Setting up Python virtual environment...${NC}\\n"
# Create the virtual environment and install dependencies as the target user when possible
run_as_user "python3 -m venv \"$INSTALL_DIR/venv\""
run_as_user "\"$INSTALL_DIR/venv/bin/python\" -m pip install -r \"$INSTALL_DIR/requirements.txt\""
echo "Python dependencies have been installed in the virtual environment."

# --- Step 4: Configure the 'speak' command in the shell ---
printf "\\n${YELLOW}Step 4: Adding the 'speak' command to your shell...${NC}\\n"

SPEAK_FUNCTION=$(cat <<'EOF'

# --- Function for the Speaker tool ---
function speak() {
    local APP_DIR="$HOME/.local/share/speaker"
    local PYTHON_EXEC="$APP_DIR/venv/bin/python"
    local SCRIPT_PATH="$APP_DIR/speaker.py"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: Speaker script not found at '$SCRIPT_PATH'." >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        "$PYTHON_EXEC" "$SCRIPT_PATH" --help
        return 0
    fi

    "$PYTHON_EXEC" "$SCRIPT_PATH" "$@"
}
EOF
)

# Check and add the function to the user's .bashrc
BASHRC_PATH="$INSTALL_HOME/.bashrc"
if [ -f "$BASHRC_PATH" ]; then
    if ! grep -q "# --- Function for the Speaker tool ---" "$BASHRC_PATH"; then
        # Append the function as the target user to preserve ownership
        run_as_user "printf '\n%s\n' \"$SPEAK_FUNCTION\" >> \"$BASHRC_PATH\""
        echo "Added 'speak' function to $BASHRC_PATH"
    else
        echo "'speak' function already exists in $BASHRC_PATH. Skipping."
    fi
fi

# Check and add the function to the user's .zshrc
ZSHRC_PATH="$INSTALL_HOME/.zshrc"
if [ -f "$ZSHRC_PATH" ]; then
    if ! grep -q "# --- Function for the Speaker tool ---" "$ZSHRC_PATH"; then
        run_as_user "printf '\n%s\n' \"$SPEAK_FUNCTION\" >> \"$ZSHRC_PATH\""
        echo "Added 'speak' function to $ZSHRC_PATH"
    else
        echo "'speak' function already exists in $ZSHRC_PATH. Skipping."
    fi
fi

# --- Step 5: Install Man Page (conditional on root privileges) ---
printf "\\n${YELLOW}Step 5: Installing Man Page...${NC}\\n"
if [ "$RUN_AS_ROOT" = true ]; then
    cp "$REPO_DIR/speak.1.gz" "/usr/local/share/man/man1/"
    mandb
    echo "Man page for 'speak' installed."
else
    # Offer to install the man page using sudo and run mandb, when the installer itself
    # was run without root but sudo is available.
    if command -v sudo &> /dev/null; then
        read -r -p "Install man page system-wide now using sudo (will run 'sudo mandb')? (y/N) " REPLY_MAN
        echo
        if [[ "$REPLY_MAN" =~ ^[Yy]$ ]]; then
            sudo cp "$REPO_DIR/speak.1.gz" "/usr/local/share/man/man1/"
            sudo mandb
            echo "Man page for 'speak' installed system-wide."
        else
            echo "Man page installation skipped. To install manually run:"
            printf "${YELLOW}sudo cp $REPO_DIR/speak.1.gz /usr/local/share/man/man1/\n${NC}"
            printf "${YELLOW}sudo mandb\n${NC}"
        fi
    else
        echo "Man page installation requires root privileges to install to system directories. Please install it manually if desired:"
        printf "${YELLOW}sudo cp $REPO_DIR/speak.1.gz /usr/local/share/man/man1/\n${NC}"
        printf "${YELLOW}sudo mandb\n${NC}"
    fi
fi

# --- Completion ---
printf "\\n${GREEN}Installation completed successfully!${NC}\\n"
echo "To start using the 'speak' command, please restart the shell for the installation user or run:"
if [ -n "$INSTALL_HOME" ]; then
    printf "${YELLOW}source $INSTALL_HOME/.bashrc${NC} (if you use bash)\\n"
    echo "or"
    printf "${YELLOW}source $INSTALL_HOME/.zshrc${NC} (if you use zsh)\\n"
else
    printf "${YELLOW}source ~/.bashrc${NC} (if you use bash)\\n"
    echo "or"
    printf "${YELLOW}source ~/.zshrc${NC} (if you use zsh)\\n"
fi
printf "\\nDon't forget to configure your API keys by copying and editing the file:\\n"
printf "${YELLOW}cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env${NC}\\n"