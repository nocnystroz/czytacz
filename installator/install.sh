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
    echo "mpg123 not found."
    # Always ask before installing system dependencies (even as root)
    INSTALL_MPG123_NOW=false
    if command -v sudo &> /dev/null || [ "$RUN_AS_ROOT" = true ]; then
        if [ "$RUN_AS_ROOT" = true ]; then
            read -r -p "Install mpg123 now as root (this will run package manager commands)? (Y/n) " REPLY_MPG
        else
            read -r -p "Install mpg123 now using sudo (this will run package manager commands)? (Y/n) " REPLY_MPG
        fi
        echo
        # Default is Yes - only skip if user explicitly says No
        if [[ ! "$REPLY_MPG" =~ ^[Nn]$ ]]; then
            INSTALL_MPG123_NOW=true
        fi
    else
        printf "${YELLOW}sudo not available and not running as root: cannot install mpg123 automatically.${NC}\\n" >&2
        printf "${YELLOW}Please install mpg123 manually using your system's package manager.${NC}\\n" >&2
    fi

    # Determine package manager and install mpg123
    PACKAGE_MANAGER_INSTALL_CMD=""
    MPG123_INSTALL_SUCCESS=false
    if [ "$INSTALL_MPG123_NOW" = true ]; then
        echo "Installing mpg123..."
        # Temporarily disable exit-on-error for package installation
        set +e

        if command -v apt-get &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                UPDATE_OUTPUT=$(apt-get update 2>&1)
                UPDATE_EXIT_CODE=$?
            else
                echo "This will require your sudo password:"
                UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
                UPDATE_EXIT_CODE=$?
            fi

            # Check if update failed and inform user about potential issues
            if [ $UPDATE_EXIT_CODE -ne 0 ]; then
                printf "${YELLOW}⚠ Warning: apt-get update reported errors.${NC}\\n" >&2

                # Check for common issues and provide helpful messages
                if echo "$UPDATE_OUTPUT" | grep -q "does not have a Release file"; then
                    printf "${YELLOW}  Issue detected: One or more repositories are broken or unavailable.${NC}\\n" >&2

                    # Extract broken PPA names
                    BROKEN_REPOS=$(echo "$UPDATE_OUTPUT" | grep "does not have a Release file" | sed -n "s/.*'\(https\?:\/\/[^']*\)'.*/\1/p")
                    if [ -n "$BROKEN_REPOS" ]; then
                        printf "${YELLOW}  Broken repositories found:${NC}\\n" >&2
                        echo "$BROKEN_REPOS" | while read -r repo; do
                            printf "${YELLOW}    - $repo${NC}\\n" >&2
                            # Try to identify PPA name
                            if echo "$repo" | grep -q "ppa.launchpadcontent.net"; then
                                PPA_NAME=$(echo "$repo" | sed -n 's|.*ppa.launchpadcontent.net/\([^/]*/[^/]*\)/.*|\1|p')
                                if [ -n "$PPA_NAME" ]; then
                                    printf "${YELLOW}      Fix with: sudo add-apt-repository --remove ppa:$PPA_NAME -y${NC}\\n" >&2
                                fi
                            fi
                        done
                    fi
                elif echo "$UPDATE_OUTPUT" | grep -q "Could not resolve"; then
                    printf "${YELLOW}  Issue detected: Network connectivity problems or DNS resolution failure.${NC}\\n" >&2
                    printf "${YELLOW}  Check your internet connection and try again.${NC}\\n" >&2
                fi

                printf "${YELLOW}  Continuing with installation anyway...${NC}\\n" >&2
            fi

            # Try to install mpg123 regardless of update errors
            if [ "$RUN_AS_ROOT" = true ]; then
                apt-get install -y mpg123
            else
                sudo apt-get install -y mpg123
            fi

            # Check if mpg123 is now available (better test than $?)
            command -v mpg123 &> /dev/null && MPG123_INSTALL_SUCCESS=true
            PACKAGE_MANAGER_INSTALL_CMD="apt-get install -y"
        elif command -v dnf &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                INSTALL_OUTPUT=$(dnf install -y mpg123 2>&1)
                INSTALL_EXIT_CODE=$?
            else
                echo "This will require your sudo password:"
                INSTALL_OUTPUT=$(sudo dnf install -y mpg123 2>&1)
                INSTALL_EXIT_CODE=$?
            fi

            if [ $INSTALL_EXIT_CODE -ne 0 ]; then
                printf "${YELLOW}⚠ Warning: dnf install reported errors:${NC}\\n" >&2
                echo "$INSTALL_OUTPUT" | tail -5 >&2
            fi

            command -v mpg123 &> /dev/null && MPG123_INSTALL_SUCCESS=true
            PACKAGE_MANAGER_INSTALL_CMD="dnf install -y"
        elif command -v yum &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                INSTALL_OUTPUT=$(yum install -y mpg123 2>&1)
                INSTALL_EXIT_CODE=$?
            else
                echo "This will require your sudo password:"
                INSTALL_OUTPUT=$(sudo yum install -y mpg123 2>&1)
                INSTALL_EXIT_CODE=$?
            fi

            if [ $INSTALL_EXIT_CODE -ne 0 ]; then
                printf "${YELLOW}⚠ Warning: yum install reported errors:${NC}\\n" >&2
                echo "$INSTALL_OUTPUT" | tail -5 >&2
            fi

            command -v mpg123 &> /dev/null && MPG123_INSTALL_SUCCESS=true
            PACKAGE_MANAGER_INSTALL_CMD="yum install -y"
        elif command -v pacman &> /dev/null; then
            if [ "$RUN_AS_ROOT" = true ]; then
                INSTALL_OUTPUT=$(pacman -S --noconfirm mpg123 2>&1)
                INSTALL_EXIT_CODE=$?
            else
                echo "This will require your sudo password:"
                INSTALL_OUTPUT=$(sudo pacman -S --noconfirm mpg123 2>&1)
                INSTALL_EXIT_CODE=$?
            fi

            if [ $INSTALL_EXIT_CODE -ne 0 ]; then
                printf "${YELLOW}⚠ Warning: pacman install reported errors:${NC}\\n" >&2
                echo "$INSTALL_OUTPUT" | tail -5 >&2
            fi

            command -v mpg123 &> /dev/null && MPG123_INSTALL_SUCCESS=true
            PACKAGE_MANAGER_INSTALL_CMD="pacman -S --noconfirm"
        else
            printf "${YELLOW}Could not detect a supported package manager (apt-get, dnf, yum, pacman).${NC}\\n" >&2
            printf "${YELLOW}Please install mpg123 manually using your system's package manager.${NC}\\n" >&2
        fi

        # Re-enable exit-on-error
        set -e

        if [ "$MPG123_INSTALL_SUCCESS" = true ]; then
            echo "✓ mpg123 has been successfully installed."
        else
            printf "${YELLOW}✗ WARNING: mpg123 installation failed. Audio playback will not work.${NC}\\n" >&2
            printf "${YELLOW}  To install it later, run: sudo apt-get install mpg123 (or equivalent)${NC}\\n" >&2
        fi
    else
        printf "${YELLOW}WARNING: mpg123 was not installed. Audio playback will not work.${NC}\\n" >&2
        printf "${YELLOW}To install it later, run: sudo apt-get install mpg123 (or equivalent for your system)${NC}\\n" >&2
    fi
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
        # Append the function directly (avoiding variable expansion issues with run_as_user)
        if [ "$EUID" -eq 0 ] && [ -n "$INSTALL_USER" ] && [ "$INSTALL_USER" != "root" ]; then
            # When running as root, write as target user but use tee to avoid expansion issues
            echo "$SPEAK_FUNCTION" | sudo -u "$INSTALL_USER" tee -a "$BASHRC_PATH" > /dev/null
            echo "Added 'speak' function to $BASHRC_PATH"
        else
            # When not root, append directly
            echo "$SPEAK_FUNCTION" >> "$BASHRC_PATH"
            echo "Added 'speak' function to $BASHRC_PATH"
        fi
    else
        echo "'speak' function already exists in $BASHRC_PATH. Skipping."
    fi
fi

# Check and add the function to the user's .zshrc
ZSHRC_PATH="$INSTALL_HOME/.zshrc"
if [ -f "$ZSHRC_PATH" ]; then
    if ! grep -q "# --- Function for the Speaker tool ---" "$ZSHRC_PATH"; then
        # Append the function directly (avoiding variable expansion issues with run_as_user)
        if [ "$EUID" -eq 0 ] && [ -n "$INSTALL_USER" ] && [ "$INSTALL_USER" != "root" ]; then
            # When running as root, write as target user but use tee to avoid expansion issues
            echo "$SPEAK_FUNCTION" | sudo -u "$INSTALL_USER" tee -a "$ZSHRC_PATH" > /dev/null
            echo "Added 'speak' function to $ZSHRC_PATH"
        else
            # When not root, append directly
            echo "$SPEAK_FUNCTION" >> "$ZSHRC_PATH"
            echo "Added 'speak' function to $ZSHRC_PATH"
        fi
    else
        echo "'speak' function already exists in $ZSHRC_PATH. Skipping."
    fi
fi

# --- Step 5: Install Man Page (always ask, even as root) ---
printf "\\n${YELLOW}Step 5: Installing Man Page...${NC}\\n"
INSTALL_MAN_NOW=false
if command -v sudo &> /dev/null || [ "$RUN_AS_ROOT" = true ]; then
    if [ "$RUN_AS_ROOT" = true ]; then
        read -r -p "Install man page system-wide now as root (will run 'mandb')? (Y/n) " REPLY_MAN
    else
        read -r -p "Install man page system-wide now using sudo (will run 'sudo mandb')? (Y/n) " REPLY_MAN
    fi
    echo
    # Default is Yes - only skip if user explicitly says No
    if [[ ! "$REPLY_MAN" =~ ^[Nn]$ ]]; then
        INSTALL_MAN_NOW=true
    fi
else
    printf "${YELLOW}sudo not available and not running as root: cannot install man page automatically.${NC}\\n" >&2
    printf "${YELLOW}Please install it manually if desired.${NC}\\n" >&2
fi

if [ "$INSTALL_MAN_NOW" = true ]; then
    echo "Installing man page..."
    # Temporarily disable exit-on-error for man page installation
    set +e
    MAN_INSTALL_SUCCESS=false

    if [ "$RUN_AS_ROOT" = true ]; then
        cp "$REPO_DIR/speak.1.gz" "/usr/local/share/man/man1/" && mandb
        [ $? -eq 0 ] && MAN_INSTALL_SUCCESS=true
    else
        echo "This will require your sudo password:"
        sudo cp "$REPO_DIR/speak.1.gz" "/usr/local/share/man/man1/" && sudo mandb
        [ $? -eq 0 ] && MAN_INSTALL_SUCCESS=true
    fi

    # Re-enable exit-on-error
    set -e

    if [ "$MAN_INSTALL_SUCCESS" = true ]; then
        echo "✓ Man page for 'speak' installed successfully."
    else
        printf "${YELLOW}✗ WARNING: Man page installation failed.${NC}\\n" >&2
        printf "${YELLOW}  To install manually, run the commands shown below.${NC}\\n" >&2
    fi
else
    echo "Man page installation skipped. To install manually run:"
    printf "${YELLOW}sudo cp $REPO_DIR/speak.1.gz /usr/local/share/man/man1/\n${NC}"
    printf "${YELLOW}sudo mandb\n${NC}"
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