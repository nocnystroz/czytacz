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
INSTALL_DIR="$HOME/.local/share/speaker"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "${GREEN}Starting installation of the Speaker tool...${NC}\\n"

# --- Step 1: Detect package manager and install mpg123 ---
printf "\\n${YELLOW}Step 1: Checking system dependencies (mpg123)...${NC}\\n"

if command -v mpg123 &> /dev/null; then
    echo "mpg123 is already installed."
else
    echo "mpg13 not found. Attempting to install..."
    # Determine package manager and install mpg123
    PACKAGE_MANAGER_INSTALL_CMD=""
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
printf "Application files have been copied to %s.\\n" "$INSTALL_DIR"

# --- Step 3: Create virtual environment and install Python dependencies ---
printf "\\n${YELLOW}Step 3: Setting up Python virtual environment...${NC}\\n"
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"
pip install -r "$INSTALL_DIR/requirements.txt"
deactivate
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

# Check and add the function to .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "# --- Function for the Speaker tool ---" "$HOME/.bashrc"; then
        printf "\\n%s\\n" "$SPEAK_FUNCTION" >> "$HOME/.bashrc"
        echo "Added 'speak' function to ~/.bashrc"
    else
        echo "'speak' function already exists in ~/.bashrc. Skipping."
    fi
fi

# Check and add the function to .zshrc
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "# --- Function for the Speaker tool ---" "$HOME/.zshrc"; then
        printf "\\n%s\\n" "$SPEAK_FUNCTION" >> "$HOME/.zshrc"
        echo "Added 'speak' function to ~/.zshrc"
    else
        echo "'speak' function already exists in ~/.zshrc. Skipping."
    fi
fi

# --- Step 5: Install Man Page (conditional on root privileges) ---
printf "\\n${YELLOW}Step 5: Installing Man Page...${NC}\\n"
if [ "$RUN_AS_ROOT" = true ]; then
    cp "$REPO_DIR/speak.1.gz" "/usr/local/share/man/man1/"
    mandb
    echo "Man page for 'speak' installed."
else
    echo "Man page installation requires root privileges to install to system directories. Please install it manually if desired:"
    printf "${YELLOW}sudo cp $REPO_DIR/speak.1.gz /usr/local/share/man/man1/\\n${NC}"
    printf "${YELLOW}sudo mandb\\n${NC}"
fi

# --- Completion ---
printf "\\n${GREEN}Installation completed successfully!${NC}\\n"
echo "To start using the 'speak' command, please restart your terminal or run:"
printf "${YELLOW}source ~/.bashrc${NC} (if you use bash)\\n"
echo "or"
printf "${YELLOW}source ~/.zshrc${NC} (if you use zsh)\\n"
printf "\\nDon't forget to configure your API keys by copying and editing the file:\\n"
printf "${YELLOW}cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env${NC}\\n"
