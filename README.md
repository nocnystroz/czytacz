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
# or, to allow automatic handling of system dependencies and man page:
sudo bash installator/install.sh
```

**Installer Behavior:**
*   If run with `sudo`, it will automatically handle system-level dependencies (`mpg123`) and install the man page.
*   If run without `sudo`, it will prompt you. If you proceed, it will install user-level components, but `mpg123` installation and man page setup will either require manual `sudo` input during the process or manual steps afterwards.

The script will automatically:
1.  Detect your package manager and install `mpg123` (or prompt for `sudo` if not run as `sudo`).
2.  Create the `~/.local/share/speaker` directory and copy the application files there.
3.  Create a Python virtual environment and install dependencies from `requirements.txt`.
4.  Add the `speak` command to your shell (`.bashrc` or `.zshrc`).
5.  Install the man page (`speak.1.gz`) (or provide manual instructions if not run as `sudo`).

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

*Note: The `install.sh` script can handle this automatically if run with `sudo`.*

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

## Important Note on Jina AI Reader Service

The `Speaker` tool utilizes the `r.jina.ai` service provided by Jina AI for fetching and parsing web page content.

*   **Usage of `r.jina.ai` is subject to Jina AI's own Terms of Service.**
*   Users are responsible for reviewing and complying with these terms, especially concerning any limitations on commercial use, rate limits, or data privacy.
*   The `Speaker` project's GPLv3 license covers only the `Speaker` software itself, not the Jina AI service or its terms. Your use of the Jina AI service is independent of the `Speaker` software's license.

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
# or, to allow automatic handling of system-level cleanup (man page, mpg123):
sudo bash installator/uninstall.sh
```

**Uninstaller Behavior:**
*   If run with `sudo`, it will automatically remove the man page. It will also *ask you* if you wish to remove `mpg123`.
*   If run without `sudo`, it will prompt you. If you proceed, it will remove user-level components, but man page removal and `mpg123` removal will require manual `sudo` steps.

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

#### 3. Remove Man Page (if installed)
```bash
sudo rm /usr/local/share/man/man1/speak.1.gz
sudo mandb
```

#### 4. Remove mpg123 (if installed and desired)
```bash
sudo apt-get remove mpg123 # or use your package manager (dnf, yum, pacman, etc.)
```

#### 5. Refresh the terminal
```bash
source ~/.bashrc 
# or
source ~/.zshrc
```
