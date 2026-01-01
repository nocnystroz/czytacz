# Roadmap for Czytacz

This document outlines the development plan for the `Czytacz` tool.

## Done (v0.1)

- [x] Core functionality: Read text aloud using gTTS.
- [x] URL support: Fetch content from web pages using `r.jina.ai`.
- [x] Command-line integration: A simple `czytaj` command available in the shell.
- [x] Isolated environment: Use a Python virtual environment (`venv`) for clean dependency management.
- [x] Self-contained installation script/logic.
- [x] Automatic cleanup of temporary `.mp3` files.

## Done (v0.2)

- [x] **LLM Integration for Summarization**:
    - [x] Add a `--summarize` flag to the command.
    - [x] When used, the script will summarize the text using a configured Large Language Model before reading it aloud.

- [x] **Configuration via `.env` file**:
    - [x] Manage API keys for LLM services securely.
    - [x] Define the order of LLM providers to use as a fallback mechanism.

- [x] **Documentation**:
    - [x] Create a `README.md` with a project description and, crucially, uninstallation instructions.
    - [x] Create this `ROADMAP.md` file.

- [x] **Improved Text Extraction**:
    - [x] Enhance the default (non-LLM) logic for extracting the most relevant content from the text provided by Jina Reader.

## Done (v0.3)

- [x] **Configurable TTS Engine**:
    - [x] Add support for Google's Cloud TTS as a primary engine (option "gemini").
    - [x] Implement a fallback mechanism to `gTTS`.
    - [x] Manage TTS provider order via `.env` file.
- [x] **Improved Argument Parsing**:
    - [x] The script now accepts multi-word text input without requiring quotes.
- [x] **Basic Text Cleaning**:
    - [x] Added a function to clean the text from common problematic characters (special quotes, dashes, etc.) before processing.

## Done (v0.4)

- [x] **Installer & Uninstaller**:
    - [x] Created a universal `install.sh` script to automate the setup process.
    - [x] Created an `uninstall.sh` script for easy and clean removal of the tool.
- [x] **Dependency Management**:
    - [x] Created a `requirements.txt` file for cleaner Python dependency installation.

## Future Ideas (v0.5 and beyond)

- [ ] **Support for multiple TTS engines**:
    - Allow choosing different text-to-speech services (e.g., ElevenLabs, or other local ones).
- [ ] **Support for reading local files**:
    - Add the ability to read content from local `.txt`, `.md`, or other text-based files.
- [ ] **Interactive mode**:
    - An interactive shell to manage a playlist of texts/articles to be read.
- [ ] **More advanced text extraction**:
    - Use a dedicated library like `trafilatura` as a fallback or alternative to Jina Reader for more robust web content extraction.
- [ ] **Support for more LLM providers**:
    - Add pre-built support for more APIs like Anthropic Claude, Cohere, etc.
- [ ] **Advanced recording management**:
    - Add features for saving, listing, and re-playing generated audio files. (Wymaga nowych ustaleń i Twojej wyraźnej zgody).
