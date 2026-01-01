# Speaker

Speaker is a simple command-line tool that can read any given text or the content of a specified webpage aloud. It uses Google's Text-to-Speech engines for speech synthesis.

It also has an optional feature to summarize long texts using a configured Large Language Model (LLM) before reading them aloud. By default, summaries are produced in the same language as the input text (the LLM is instructed to reply in the source language); use `-t/--translate` to request a translated summary in `TRANSLATE_TO_LANG`.

## Main Features

- Reads text aloud (supports multiple languages; by default summaries and output are produced in the source text language).
- Optionally translates summaries into another language using `-t/--translate` (controlled by `TRANSLATE_TO_LANG` in `~/.local/share/speaker/.env`).
- Fetches and reads content from websites (using `r.jina.ai`).
- Optionally summarizes content using LLM providers (Gemini, OpenAI, etc.).
- Configurable API keys, LLM provider order, and TTS engine order via a `.env` file.
- Optionally configure a comma-separated list of Gemini models (`GEMINI_MODELS`) to try in priority order; the actually selected LLM provider and model (format `provider:model`) are cached per-terminal session to prefer the best working model on subsequent runs.
- Simple installation and shell integration with the `speak` command.
- Includes installer and uninstaller scripts for easy management.

## Supported Linux Distributions

Speaker works on most popular Linux distributions with the following package managers:

- **Debian/Ubuntu/Mint** (apt-get)
- **Fedora/RHEL 8+** (dnf)
- **CentOS/RHEL 7** (yum)
- **Arch/Manjaro** (pacman)

The installer automatically detects your package manager and installs required dependencies (`mpg123`).

## Installation

The main and recommended installation method is to use the included `install.sh` script.

**Recommended workflow:** prepare the `.env` file in the project root (copy from `.env.example` and edit it) *before* running the installer. The installer will detect a `.env` in the repository and offer to copy it into `~/.local/share/speaker` so the installed `speak` command has your API keys available immediately.

Example (prepare `.env` in the project):

```bash
# Prepare .env in the project root and edit it
cp .env.example .env
# Edit ./.env and set your API keys
nano ./.env

# Then run the installer (it will offer to copy the repo .env to the install dir)
chmod +x installator/install.sh
bash installator/install.sh
# or, to allow automatic handling of system dependencies and man page:
sudo bash installator/install.sh
```

If you prefer to create or edit the install `.env` after installation, the installer can also create `~/.local/share/speaker/.env` from `.env.example`, or you can manually copy your project `.env` later with:

```bash
cp ./.env ~/.local/share/speaker/.env
```

If you prefer to create the `.env` after installation, the installer prints a reminder and you can also run:

```bash
cp ~/.local/share/speaker/.env.example ~/.local/share/speaker/.env
# Edit ~/.local/share/speaker/.env and set your API keys
nano ~/.local/share/speaker/.env
```

If you edited the project's `.env` in the repository, copy it to the installation directory so the installed `speak` command will use the updated values:

```bash
cp ./.env ~/.local/share/speaker/.env
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

## LLM model lists and per-session cache

You can configure provider-specific model lists with environment variables:
- `GEMINI_MODELS` (comma-separated list, e.g., `gemini-pro,gemini-2.5-flash`)
- `OPENAI_MODEL`, `DEEPSEEK_MODEL`, `OLLAMA_MODEL` (single or comma-separated values are supported)

The tool caches the actually selected working LLM as `provider:model` in a per-terminal cache file located at `$XDG_RUNTIME_DIR/speaker_llm_<uid>_<ptsN>` (falls back to `/tmp` when `XDG_RUNTIME_DIR` is not set). On subsequent runs in the same terminal session the cached `provider:model` is tried first to prefer a known-working configuration.

To manually inspect or clear the cache:

```bash
# List cache files
ls ${XDG_RUNTIME_DIR:-/tmp}/speaker_llm_*
# Show the cached provider:model
cat ${XDG_RUNTIME_DIR:-/tmp}/speaker_llm_<uid>_<ptsN>
# Remove cache manually
rm ${XDG_RUNTIME_DIR:-/tmp}/speaker_llm_<uid>_<ptsN>
```

Testing tip: use `speak -s "long text..."` and then check the cache file to see which provider and model were selected.

Translation: the summary is generated in the same language as the input by default. If you pass `-t|--translate`, the summarization request will ask the LLM to return the summary translated into the language defined by `TRANSLATE_TO_LANG` in `.env` (single-step summarize+translate). The translation flag is only applied during summarization; plain `speak` without `-s` will not translate. When using `-t`, the tool sends a single summarization request instructing the LLM to return the summary already translated into the `TRANSLATE_TO_LANG` language (single-step summarize+translate).

Note on quoting: when running `speak` from the shell, avoid using single quotes (apostrophes) around your text; use double quotes or no quotes, for example:

```bash
speak -s This is a long text to summarize
speak -s "To jest bardzo długi tekst do streszczenia"
# Avoid: speak -s 'text with apostrophes' (single quotes)
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
*   If run with `sudo`, it will prompt whether to remove Speaker for **all users** and automatically remove the man page; use `--all` to force non-interactive all-user removal. It will also ask you if you wish to remove `mpg123`.
*   If run without `sudo`, it will prompt you and remove only the current user's components. Attempting `--all` without root will produce an error (use sudo).

**Flags:**
* `--all` (or `-a`) — remove Speaker for all users (requires root). When run as root the script will ask for confirmation unless `--all` is explicitly provided. Use `--yes`/`-y` to skip confirmation prompts for automated scenarios.
* `--target-user <username>` — perform removal only for the specified user (requires root when removing another user's files).

The script will ask for confirmation, then remove the `speak` function from your shell configuration and delete the `~/.local/share/speaker` application directory. If you later wish to restore the tool, simply re-run the installer.

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
