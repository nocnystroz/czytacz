# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Speaker is a command-line text-to-speech tool that reads text or web content aloud. By default summaries and generated text are produced in the source text language; the tool also supports single-step summary+translation via `-t`/`--translate` into `TRANSLATE_TO_LANG`. The application uses a modular architecture with configurable fallback mechanisms for both LLM summarization and TTS engines.

## Core Architecture

### Main Components

- **speaker.py**: Monolithic Python script containing all core functionality
  - Content processing (text input, URL fetching via Jina Reader)
  - LLM integration for summarization (Gemini, OpenAI, DeepSeek, Ollama)
  - TTS engines (Google Cloud TTS, gTTS fallback)
  - Text cleaning and preprocessing

- **Installer/Uninstaller Scripts**: Bash scripts with conditional root/non-root execution paths
  - `installator/install.sh`: System dependency installation, venv setup, shell integration
  - `installator/uninstall.sh`: Clean removal with optional mpg123 cleanup

### Configuration System

The application uses environment-based configuration via `.env` file:
- **LLM_FALLBACK_ORDER**: Comma-separated provider list (e.g., "gemini,openai,deepseek,ollama"). This controls provider-level fallback.
- **TTS_FALLBACK_ORDER**: TTS engine priority (e.g., "gtts,gemini").
- **Provider model lists**: You can specify provider-specific model priority lists, for example:
  - `GEMINI_MODELS` (comma-separated; e.g., `gemini-pro,gemini-2.5-flash`)
  - `OPENAI_MODEL`, `DEEPSEEK_MODEL`, `OLLAMA_MODEL` (each accepts single or comma-separated values)
- **Per-session LLM cache**: The script caches the actually used LLM as `provider:model` in a per-terminal (per-TTY) cache file (`$XDG_RUNTIME_DIR/speaker_llm_<uid>_<ptsN>` or `/tmp` fallback). When present and valid, the cached `provider:model` is tried first on subsequent runs within the same terminal to prefer a previously working model. The cache is automatically ignored/removed when the terminal session ends; you can remove it manually if needed.
- **Error hints**: If Gemini returns a 404 or `model not found` error, check your `GEMINI_MODELS` values and that your `GEMINI_API_KEY` is valid and authorized for those models (model names must match ones available for your account). For OpenAI, ensure `OPENAI_API_KEY` and `OPENAI_MODEL` are set; speaker now supports OpenAI Chat Completions for summarization.
- API keys for each provider (GEMINI_API_KEY, OPENAI_API_KEY, etc.)

**Recommended workflow (installation):** Prepare the `.env` file in the project root (copy `./.env.example` to `./.env` and edit it) *before* running the installer. The installer will detect a repository `.env` and offer to copy it into `~/.local/share/speaker`, ensuring the installed `speak` command has your API keys right away.

Example:

```bash
# In the repository, prepare and edit the .env
cp .env.example .env
nano .env

# Run the installer (it will prompt to copy the repo .env into the install dir)
bash installator/install.sh
```

You can still create or edit `~/.local/share/speaker/.env` after installation if you prefer; the installer will offer to create it from `.env.example` if it is missing.
#### Notes & examples
- Example `.env` entries:

```dotenv
GEMINI_MODELS="gemini-pro,gemini-2.5-flash"
OPENAI_MODEL="gpt-4o-mini"
```

- Inspect or clear per-TTY cache:

```bash
ls ${XDG_RUNTIME_DIR:-/tmp}/speaker_llm_*
cat ${XDG_RUNTIME_DIR:-/tmp}/speaker_llm_<uid>_<ptsN>
rm ${XDG_RUNTIME_DIR:-/tmp}/speaker_llm_<uid>_<ptsN>
```


Configuration is loaded from `~/.local/share/speaker/.env` when installed.

### Fallback Mechanism Pattern

Both LLM and TTS features use a consistent fallback pattern:
1. Parse order from environment variable
2. Iterate through providers in order
3. Check for valid API keys (not placeholder values)
4. Attempt operation, catch exceptions
5. Return on first success or fail through all options

When adding new providers, follow this pattern in the respective `_call_*()` or `_tts_*()` functions.

## Development Commands

### Testing Locally (without installation)

```bash
# Run directly from repository
python3 speaker.py "test text"
python3 speaker.py -s "long text to summarize"
python3 speaker.py https://example.com

# Test with specific environment
cp .env.example .env
# Edit .env with your API keys
python3 speaker.py "test text"
```

### Installation Testing

```bash
# Test installer
bash installator/install.sh

# Verify installation
speak --help
which speak  # Should show it's a shell function

# Test uninstaller
bash installator/uninstall.sh
# To remove for all users (requires root and interactive confirmation):
sudo bash installator/uninstall.sh --all
# To remove non-interactively (use with care):
sudo bash installator/uninstall.sh --all --yes
# Or target a specific user explicitly:
sudo bash installator/uninstall.sh --target-user alice
```

### Dependencies

Install dependencies manually for development:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Required system dependency:
```bash
sudo apt-get install mpg123  # or equivalent for your package manager
```

## Key Implementation Details

### URL Content Fetching

The tool uses Jina AI Reader (`r.jina.ai`) as a proxy service to fetch and parse web content. The content extraction has two strategies:
1. **Smart extraction**: Filters lines >40 chars, >5 words, ending with periods
2. **Fallback**: Returns largest text chunk from `\n\n` splits

### Text Cleaning

The `clean_text()` function normalizes problematic Unicode characters (smart quotes, dashes, non-breaking spaces) before TTS processing to avoid pronunciation issues.

### Shell Integration

The installed `speak` command is a shell function (not a symlink or script) that:
- Checks for script existence before execution
- Activates the virtual environment automatically
- Passes all arguments through to the Python script
- Shows help when called with no arguments

## Installer Script Architecture

Both install/uninstall scripts follow a conditional execution pattern:

1. **Root privilege detection**: `if [ "$EUID" -eq 0 ]`
2. **Conditional prompting**: Non-root users get confirmation prompts
3. **Conditional system operations**: Man page and mpg123 handled differently based on privileges
4. **User guidance**: Manual steps printed for non-root users

When modifying installers:
- Maintain both root and non-root paths
- Always backup shell config files before modification (`.bashrc.bak.$(date +%F)`)
- Use colored output (GREEN, YELLOW, RED) for user guidance
- Test both `sudo` and non-`sudo` execution paths

## Man Page

The man page (`speak.1.gz`) is a compressed groff file. To edit:
```bash
gunzip speak.1.gz
# Edit speak.1 (groff format)
gzip speak.1
```

## Adding New LLM Providers

1. Add provider to `.env.example` with API key placeholder
2. Create `_call_<provider>()` function in speaker.py following existing pattern
3. Add provider case to `summarize_text()` function
4. Update README.md configuration section
5. Test fallback mechanism

## Adding New TTS Engines

1. Add provider to `.env.example` TTS_FALLBACK_ORDER
2. Create `_tts_<provider>()` function returning bool (success/failure)
3. Save audio to provided temp_filename
4. Add provider case to `read_aloud()` function
5. Ensure proper error handling and user feedback

## Testing Checklist

When making changes:
- [ ] Test with missing dependencies (no mpg123)
- [ ] Test with invalid/missing API keys
- [ ] Test URL fetching with various websites
- [ ] Test text cleaning with Unicode characters
- [ ] Test both root and non-root installation paths
- [ ] Verify shell function works in both bash and zsh
- [ ] Test fallback mechanisms by disabling providers
- [ ] Test `GEMINI_MODELS` ordering: set `GEMINI_MODELS="gemini-pro,gemini-2.1"` and verify models are tried in order.
- [ ] Test per-TTY LLM cache: run summarization in one terminal, verify cache file exists (`$XDG_RUNTIME_DIR/speaker_llm_<uid>_<ptsN>`), then close that terminal and ensure cache is ignored/removed when running in a new terminal session. Also verify cache stores provider:model (e.g., `gemini:gemini-pro` or `openai:gpt-4o`) and is used preferentially on subsequent runs in the same terminal session.

### Summarization language and translation
- By default, the summary is produced in the same language as the input text (the LLM is instructed to reply in the same language).
- To translate the produced summary to another language, use the `-t`/`--translate` flag when running `speak -s`; the tool will ask the LLM to return the summary already translated into the language defined in `TRANSLATE_TO_LANG` in `~/.local/share/speaker/.env` (single-step summarize+translate). The translation flag applies only during summarization; plain `speak` without `-s` will not translate.
- Note on quoting: when running `speak` from the shell, avoid single quotes (apostrophes) around the text; use double quotes or no quotes, e.g.:

```bash
speak -s This is a long text to summarize
speak -s "To jest bardzo długi tekst do streszczenia"
```

## License Considerations

This project is GPLv3. Key dependencies use compatible licenses:
- requests (Apache 2.0)
- python-dotenv (BSD 3-Clause)
- gTTS (MIT)

When adding new dependencies, verify license compatibility with GPLv3.
