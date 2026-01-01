#!/usr/bin/env python3
import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlparse

import requests
from dotenv import load_dotenv

# --- Configuration and Constants ---
# Determine the app directory and load the .env file
APP_DIR = os.path.dirname(os.path.realpath(__file__))
dotenv_path = os.path.join(APP_DIR, ".env")
load_dotenv(dotenv_path=dotenv_path)

JINA_READER_URL = "https://r.jina.ai/"

# --- LLM Logic (Summarization) ---

def _call_gemini(text: str, api_key: str, model: str, target_lang: str | None = None) -> str | None:
    """Sends a request to the Google Gemini API for a specific model.
    If `target_lang` is provided, request that the summary be translated into that language
    as part of the same operation (single-step summarize+translate).
    """
    print(f"Attempting to use Gemini for summarization (model: {model})...")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    if target_lang:
        prompt = (f"Summarize the following text and translate the summary into {target_lang}. "
                  f"Keep the summary concise (5-7 sentences) and focus on the most important information. Text:\n\n{text}")
    else:
        prompt = (f"Summarize the following text in a maximum of 5-7 sentences. "
                  f"Focus on the most important information and reply in the same language as the input. Text to summarize:\n\n{text}")
    data = {"contents": [{"parts": [{"text": prompt}]}]}

    try:
        response = requests.post(url, headers=headers, json=data, timeout=45)
        # If non-2xx, surface response body for debugging
        if response.status_code != 200:
            print(f"Gemini API returned {response.status_code}: {response.text}", file=sys.stderr)
            return None
        result = response.json()
        # Safely navigate the returned JSON structure
        summary = result.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        return summary.strip() if summary else None
    except requests.RequestException as e:
        # Print request errors and response text if available
        try:
            print(f"Gemini (summarize) request error: {e} - response: {e.response.text}", file=sys.stderr)
        except Exception:
            print(f"Gemini (summarize) request error: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Gemini (summarize) error: {e}", file=sys.stderr)
        return None

# --- LLM session cache helpers (per-TTY) ---
def _get_tty_id() -> str | None:
    """Return the TTY id like 'pts/2' for the current session, or None if unavailable."""
    try:
        tty = os.ttyname(sys.stdin.fileno())
        return os.path.basename(tty)  # 'pts/2'
    except Exception:
        return None


def _get_llm_cache_path() -> str | None:
    """Return a per-tty LLM cache filepath or None if no tty is available."""
    tty_id = _get_tty_id()
    if not tty_id:
        return None
    runtime_dir = os.getenv("XDG_RUNTIME_DIR", "/tmp")
    uid = os.getuid()
    safe_tty = tty_id.replace('/', '_')  # make filesystem-friendly
    return os.path.join(runtime_dir, f"speaker_llm_{uid}_{safe_tty}")


def _read_llm_cache() -> tuple | None:
    """Read cached 'provider:model' from per-tty cache. Returns (provider, model) or None."""
    path = _get_llm_cache_path()
    if not path or not os.path.exists(path):
        return None
    # Ensure TTY still exists; if not, remove stale cache
    tty_id = _get_tty_id()
    if not tty_id or not os.path.exists(f"/dev/{tty_id}"):
        try:
            os.remove(path)
        except Exception:
            pass
        return None
    try:
        with open(path, "r") as f:
            val = f.read().strip()
            if ':' in val:
                provider, model = val.split(':', 1)
                return provider, model
            return None
    except Exception:
        return None


def _write_llm_cache(provider: str, model: str):
    path = _get_llm_cache_path()
    if not path:
        return
    try:
        with open(path, "w") as f:
            f.write(f"{provider}:{model}")
    except Exception:
        pass


def _call_openai(text: str, api_key: str, model: str, target_lang: str | None = None) -> str | None:
    """Sends a request to the OpenAI Chat Completions endpoint to summarize text.
    If `target_lang` is provided, instruct the model to translate the summary into that language
    as part of the same operation.
    """
    print(f"Attempting to use OpenAI ({model}) for summarization...")
    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    if target_lang:
        system_prompt = f"You are a helpful assistant that summarizes text concisely in 5-7 sentences and returns the summary translated into {target_lang}. Reply with the translation only."
    else:
        system_prompt = "You are a helpful assistant that summarizes text concisely in 5-7 sentences and reply in the same language as the user's input."

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": text}
    ]
    data = {"model": model, "messages": messages, "temperature": 0.3, "max_tokens": 500}

    try:
        response = requests.post(url, headers=headers, json=data, timeout=45)
        if response.status_code != 200:
            print(f"OpenAI API returned {response.status_code}: {response.text}", file=sys.stderr)
            return None
        result = response.json()
        # Chat completions v1 response: choices[0].message.content
        summary = result.get("choices", [{}])[0].get("message", {}).get("content", "")
        return summary.strip() if summary else None
    except requests.RequestException as e:
        print(f"OpenAI request error: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"OpenAI error: {e}", file=sys.stderr)
        return None


def _translate_openai(text: str, api_key: str, model: str, target_lang: str) -> str | None:
    """Translate text using OpenAI Chat Completions."""
    print(f"Attempting to use OpenAI ({model}) for translation to {target_lang}...")
    url = "https://api.openai.com/v1/chat/completions"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}
    messages = [
        {"role": "system", "content": f"You are a helpful translator. Translate the user's text into {target_lang} and reply with the translation only."},
        {"role": "user", "content": text}
    ]
    data = {"model": model, "messages": messages, "temperature": 0.0, "max_tokens": 2000}
    try:
        response = requests.post(url, headers=headers, json=data, timeout=45)
        if response.status_code != 200:
            print(f"OpenAI API returned {response.status_code}: {response.text}", file=sys.stderr)
            return None
        result = response.json()
        translation = result.get("choices", [{}])[0].get("message", {}).get("content", "")
        return translation.strip() if translation else None
    except Exception as e:
        print(f"OpenAI translation error: {e}", file=sys.stderr)
        return None


def _translate_gemini(text: str, api_key: str, model: str, target_lang: str) -> str | None:
    """Translate text using Gemini by sending a translation prompt."""
    print(f"Attempting to use Gemini ({model}) for translation to {target_lang}...")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    prompt = f"Translate the following text into {target_lang}. Reply with the translation only. Text:\n\n{text}"
    data = {"contents": [{"parts": [{"text": prompt}]}]}
    try:
        response = requests.post(url, headers=headers, json=data, timeout=45)
        if response.status_code != 200:
            print(f"Gemini API returned {response.status_code}: {response.text}", file=sys.stderr)
            return None
        result = response.json()
        translation = result.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        return translation.strip() if translation else None
    except Exception as e:
        print(f"Gemini translation error: {e}", file=sys.stderr)
        return None


def _call_deepseek(text: str, api_key: str, model: str) -> str | None:
    """Sends a request to the DeepSeek API."""
    print(f"Attempting to use DeepSeek ({model}) for summarization...")
    # Placeholder for DeepSeek logic
    print("DeepSeek logic is not yet implemented.", file=sys.stderr)
    return None
    
def _call_ollama(text: str, base_url: str, model: str) -> str | None:
    """Sends a request to a local Ollama server."""
    print(f"Attempting to use Ollama ({model}) for summarization...")
    # Placeholder for Ollama logic
    print("Ollama logic is not yet implemented.", file=sys.stderr)
    return None

def summarize_text(text: str, target_lang: str | None = None) -> str | None:
    """Summarizes text using LLM providers according to the fallback order.
    If `target_lang` is set, request that the summary be produced in that language (single-step summarize+translate).
    """
    fallback_order = os.getenv("LLM_FALLBACK_ORDER", "gemini,openai").split(',')
    
    # First, attempt cached provider:model if present
    cached = _read_llm_cache()
    if cached:
        cached_provider, cached_model = cached
        if cached_provider in fallback_order:
            print(f"Trying cached LLM: {cached_provider} (model: {cached_model})")
            if cached_provider == "gemini":
                api_key = os.getenv("GEMINI_API_KEY")
                if api_key and api_key != "Your_Gemini_API_Key":
                    summary = _call_gemini(text, api_key, cached_model, target_lang)
                    if summary:
                        _write_llm_cache(cached_provider, cached_model)
                        print(f"Summary generated by: {cached_provider} (model: {cached_model})")
                        return summary
            elif cached_provider == "openai":
                api_key = os.getenv("OPENAI_API_KEY")
                if api_key and api_key != "Your_OpenAI_API_Key":
                    summary = _call_openai(text, api_key, cached_model, target_lang)
                    if summary:
                        _write_llm_cache(cached_provider, cached_model)
                        print(f"Summary generated by: {cached_provider} (model: {cached_model})")
                        return summary
            elif cached_provider == "deepseek":
                api_key = os.getenv("DEEPSEEK_API_KEY")
                if api_key and api_key != "Your_DeepSeek_API_Key":
                    summary = _call_deepseek(text, api_key, cached_model)
                    if summary:
                        _write_llm_cache(cached_provider, cached_model)
                        print(f"Summary generated by: {cached_provider} (model: {cached_model})")
                        return summary
            elif cached_provider == "ollama":
                base = os.getenv("OLLAMA_BASE_URL")
                if base:
                    summary = _call_ollama(text, base, cached_model)
                    if summary:
                        _write_llm_cache(cached_provider, cached_model)
                        print(f"Summary generated by: {cached_provider} (model: {cached_model})")
                        return summary

    # No usable cache or cached attempt failed: iterate providers and provider model lists
    for provider in fallback_order:
        summary = None
        if provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY")
            if api_key and api_key != "Your_Gemini_API_Key":
                models_env = os.getenv("GEMINI_MODELS")
                if models_env:
                    models = [m.strip() for m in models_env.split(',') if m.strip()]
                else:
                    single = os.getenv("GEMINI_MODEL", "gemini-pro")
                    models = [m.strip() for m in single.split(',') if m.strip()]

                for model in models:
                    print(f"Trying Gemini model: {model}")
                    summary = _call_gemini(text, api_key, model, target_lang)
                    if summary:
                        _write_llm_cache("gemini", model)
                        print(f"Summary generated by: gemini (model: {model})")
                        return summary

        elif provider == "openai":
            api_key = os.getenv("OPENAI_API_KEY")
            if api_key and api_key != "Your_OpenAI_API_Key":
                models = [m.strip() for m in os.getenv("OPENAI_MODEL", "gpt-4o").split(',') if m.strip()]
                for model in models:
                    print(f"Trying OpenAI model: {model}")
                    summary = _call_openai(text, api_key, model, target_lang)
                    if summary:
                        _write_llm_cache("openai", model)
                        print(f"Summary generated by: openai (model: {model})")
                        return summary

        elif provider == "deepseek":
            api_key = os.getenv("DEEPSEEK_API_KEY")
            if api_key and api_key != "Your_DeepSeek_API_Key":
                models = [m.strip() for m in os.getenv("DEEPSEEK_MODEL", "deepseek-chat").split(',') if m.strip()]
                for model in models:
                    print(f"Trying DeepSeek model: {model}")
                    summary = _call_deepseek(text, api_key, model)
                    if summary:
                        _write_llm_cache("deepseek", model)
                        print(f"Summary generated by: deepseek (model: {model})")
                        return summary

        elif provider == "ollama":
            base = os.getenv("OLLAMA_BASE_URL")
            if base:
                models = [m.strip() for m in os.getenv("OLLAMA_MODEL", "").split(',') if m.strip()]
                for model in models:
                    print(f"Trying Ollama model: {model}")
                    summary = _call_ollama(text, base, model)
                    if summary:
                        _write_llm_cache("ollama", model)
                        print(f"Summary generated by: ollama (model: {model})")
                        return summary

        # ... (other providers)

        if summary:
            print(f"Summary generated by: {provider}")
            return summary
            
    print("Failed to get summary from any configured LLM.", file=sys.stderr)
    return None


def translate_text(text: str, target_lang: str) -> str | None:
    """Translates text to target_lang using available LLM providers.
    Tries cached provider:model first, then falls back to provider model lists.
    """
    fallback_order = os.getenv("LLM_FALLBACK_ORDER", "gemini,openai").split(',')

    # Try cached provider:model first
    cached = _read_llm_cache()
    if cached:
        provider, model = cached
        print(f"Trying cached LLM for translation: {provider} (model: {model})")
        if provider == "openai":
            api_key = os.getenv("OPENAI_API_KEY")
            if api_key and api_key != "Your_OpenAI_API_Key":
                trans = _translate_openai(text, api_key, model, target_lang)
                if trans:
                    return trans
        elif provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY")
            if api_key and api_key != "Your_Gemini_API_Key":
                trans = _translate_gemini(text, api_key, model, target_lang)
                if trans:
                    return trans

    # No cache or failed: iterate providers
    for provider in fallback_order:
        if provider == "openai":
            api_key = os.getenv("OPENAI_API_KEY")
            if api_key and api_key != "Your_OpenAI_API_Key":
                models = [m.strip() for m in os.getenv("OPENAI_MODEL", "gpt-4o").split(',') if m.strip()]
                for model in models:
                    print(f"Trying OpenAI model for translation: {model}")
                    trans = _translate_openai(text, api_key, model, target_lang)
                    if trans:
                        _write_llm_cache("openai", model)
                        return trans
        elif provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY")
            if api_key and api_key != "Your_Gemini_API_Key":
                models_env = os.getenv("GEMINI_MODELS")
                if models_env:
                    models = [m.strip() for m in models_env.split(',') if m.strip()]
                else:
                    single = os.getenv("GEMINI_MODEL", "gemini-pro")
                    models = [m.strip() for m in single.split(',') if m.strip()]
                for model in models:
                    print(f"Trying Gemini model for translation: {model}")
                    trans = _translate_gemini(text, api_key, model, target_lang)
                    if trans:
                        _write_llm_cache("gemini", model)
                        return trans
    print(f"Translation to {target_lang} failed on all configured LLMs.", file=sys.stderr)
    return None

# --- Content Processing ---

def is_url(text: str) -> bool:
    """Checks if the given text is a valid URL."""
    try:
        result = urlparse(text)
        return all([result.scheme, result.netloc])
    except ValueError:
        return False

def get_content_from_url(url: str) -> str:
    """Fetches and returns the main content of a webpage using Jina AI Reader."""
    print(f"Fetching content from: {url} ...")
    try:
        response = requests.get(f"{JINA_READER_URL}{url}", timeout=30)
        response.raise_for_status()
        
        full_content = response.text
        print("\n--- Fetched Content (Full) ---")
        print(full_content)
        print("--- End of Content ---\n")

        lines = full_content.split('\n')
        meaningful_lines = [line.strip() for line in lines if len(line.strip()) > 40]
        potential_content = [line for line in meaningful_lines if len(line.split()) > 5 and line.endswith('.')]
        
        if not potential_content:
            parts = full_content.split('\n\n', 2)
            return max(parts, key=len) if len(parts) > 1 else full_content

        return "\n\n".join(potential_content)

    except requests.RequestException as e:
        return f"Error while fetching URL: {e}"

# --- TTS (Text-to-Speech) Logic ---

def _tts_gemini(text: str, temp_filename: str) -> bool:
    """Generates speech using Google Cloud TTS API (treated as Gemini TTS)."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key == "Your_Gemini_API_Key":
        return False
        
    print("Attempting to use Google TTS engine (Gemini/Cloud)...")
    url = f"https://texttospeech.googleapis.com/v1/text:synthesize?key={api_key}"
    headers = {"Content-Type": "application/json"}
    
    # Note: Using the standard Google Cloud TTS API. If a dedicated
    # Gemini TTS endpoint becomes available, this logic should be updated.
    data = {
        "input": {"text": text},
        "voice": {"languageCode": "pl-PL", "name": "pl-PL-Wavenet-A"},
        "audioConfig": {"audioEncoding": "MP3"}
    }
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)
        response.raise_for_status()
        audio_content = response.json().get("audioContent")
        if not audio_content:
            print("Google TTS Error: No audio content in response.", file=sys.stderr)
            return False

        with open(temp_filename, "wb") as f:
            f.write(base64.b64decode(audio_content))
        return True

    except Exception as e:
        print(f"Google TTS Error: {e}", file=sys.stderr)
        return False

def _tts_gtts(text: str, temp_filename: str) -> bool:
    """Generates speech using the gTTS library (fallback)."""
    from gtts import gTTS
    print("Attempting to use gTTS engine (fallback)...")
    try:
        tts = gTTS(text, lang='pl')
        tts.save(temp_filename)
        return True
    except Exception as e:
        print(f"gTTS Error: {e}", file=sys.stderr)
        return False

def read_aloud(text: str):
    """Converts text to speech and plays it, using configured TTS engines."""
    if not text.strip():
        print("No text to read.")
        return

    print("Preparing speech...")
    fallback_order = os.getenv("TTS_FALLBACK_ORDER", "gtts,gemini").split(',')
    
    temp_file = None
    success = False
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as fp:
            temp_file = fp.name

        for provider in fallback_order:
            if provider == "gemini":
                if _tts_gemini(text, temp_file):
                    success = True
                    break
            elif provider == "gtts":
                if _tts_gtts(text, temp_file):
                    success = True
                    break
        
        if success:
            print("Playing audio...")
            player_command = ["mpg123", "-q", temp_file]
            subprocess.run(player_command, check=True, capture_output=True)
        else:
            print("All configured TTS engines failed.", file=sys.stderr)

    except Exception as e:
        print(f"An error occurred during speech generation or playback: {e}", file=sys.stderr)
        print("Please ensure 'mpg123' is installed (`sudo apt install mpg123`).", file=sys.stderr)
    finally:
        if temp_file and os.path.exists(temp_file):
            os.remove(temp_file)
            print("Temporary file deleted.")

def clean_text(text: str) -> str:
    """Cleans text of common problematic characters and excessive whitespace."""
    replacements = {
        '\u201c': '"',  # “
        '\u201d': '"',  # ”
        '\u2018': "'",  # ‘
        '\u2019': "'",  # ’
        '\u2013': '-',  # – (en-dash)
        '\u2014': '-',  # — (em-dash)
        '\u00a0': ' ',  # non-breaking space
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    
    # Replace multiple whitespace/newline characters with a single space
    text = re.sub(r'\s+', ' ', text)
    
    return text.strip()

def main():
    """Main script function."""
    parser = argparse.ArgumentParser(
        description="Reads text or web page content aloud, with an option to summarize."
    )
    parser.add_argument(
        "-s", "--summarize",
        action="store_true",
        help="Activates text summarization before reading it aloud using an LLM.",
    )
    parser.add_argument(
        "-t", "--translate",
        action="store_true",
        help="After summarization, translate the summary to the language set in TRANSLATE_TO_LANG in .env.",
    )
    parser.add_argument(
        "text_parts",
        nargs='+',
        type=str,
        help="The text to read or a URL. All words will be joined into a single string.",
    )
    args = parser.parse_args()

    # Join all text parts into a single string
    content_to_process = " ".join(args.text_parts)
    
    # Check if the combined text is a single URL
    if len(args.text_parts) == 1 and is_url(content_to_process):
        content_for_reading = get_content_from_url(content_to_process)
    else:
        content_for_reading = content_to_process

    # Clean the text before further processing
    cleaned_content = clean_text(content_for_reading)

    if args.summarize:
        print("Summarization mode activated.")
        target_lang = None
        if args.translate:
            target_lang = os.getenv("TRANSLATE_TO_LANG", "en")
        summary = summarize_text(cleaned_content, target_lang)
        if summary:
            # The summary might also need cleaning
            read_aloud(clean_text(summary))
        else:
            print("Summarization failed. Reading original text.", file=sys.stderr)
            read_aloud(cleaned_content)
    else:
        read_aloud(cleaned_content)

if __name__ == "__main__":
    main()
