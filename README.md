# Speaker

Speaker is a simple command-line tool that can read any given text or the content of a specified webpage aloud. It uses Google's Text-to-Speech engines for speech synthesis.

It also has an optional feature to summarize long texts using a configured Large Language Model (LLM) before reading them.

## Main Features

- Reads text aloud (primarily in Polish).
- Fetches and reads content from websites (using `r.jina.ai`).
- Optionally summarizes content using LLM providers (Gemini, OpenAI, etc.).
- Configurable API keys, LLM provider order, and TTS engine order via a `.env` file.
- Simple installation and shell integration with the `speak` command.
- Includes installer and uninstaller scripts for easy management.

## Installation

The main and recommended installation method is to use the included `install.sh` script.

```bash
# Ensure the script is executable
chmod +x installator/install.sh

# Run the installer from the main repository directory
bash installator/install.sh
```

The script will automatically:
1.  Detect your package manager and install `mpg123`.
2.  Create the `~/.local/share/speaker` directory and copy the application files there.
3.  Create a Python virtual environment and install dependencies from `requirements.txt`.
4.  Add the `speak` command to your shell (`.bashrc` or `.zshrc`).

After the installation is complete, restart your terminal or refresh the session with `source ~/.bashrc` (or `source ~/.zshrc`).

## Usage

```bash
# Read a simple text (quotes are not required)
speak This is a sample text to be read aloud.

# Read the content of a website
speak https://example.com

# Summarize and read a long text
speak -s This is a very long text that we want to summarize...
```

## Man Page Installation (`man speak`)

To use the system help `man speak`, you need to install the included man page file. The `speak.1.gz` file is located in this repository.

1.  **Copy the `speak.1.gz` file to the system directory:**
    ```bash
    sudo cp speak.1.gz /usr/local/share/man/man1/
    ```
    *Note: The `cp` command will automatically overwrite the old version of the file if it already exists.*

2.  **Update the man page database:**
    ```bash
    sudo mandb
    ```

After these steps, the `man speak` command should work correctly.

---

## License

This project is licensed under the **GNU General Public License v3 (GPLv3)**. See the `LICENSE` file for full details.

---

## Uninstallation

The recommended uninstallation method is to use the `uninstall.sh` script.

```bash
# Ensure the script is executable
chmod +x installator/uninstall.sh

# Run the uninstaller
bash installator/uninstall.sh
```

The script will ask for confirmation, then automatically remove the `speak` function from your shell configuration and delete the entire `~/.local/share/speaker` application directory.

### Manual Uninstallation

If for some reason you prefer to remove the tool manually, here are the steps the script performs:

#### 1. Remove the function from `.bashrc` / `.zshrc`
Use the following command to automatically remove the `speak` function block (creating a backup first is recommended: `cp ~/.bashrc ~/.bashrc.bak`).
```bash
sed -i '/# --- Function for the Speaker tool ---/,/}/d' ~/.bashrc
sed -i '/# --- Function for the Speaker tool ---/,/}/d' ~/.zshrc
```

#### 2. Remove the application directory
```bash
rm -rf ~/.local/share/speaker
```

#### 3. Refresh the terminal
```bash
source ~/.bashrc 
# or
source ~/.zshrc
```
