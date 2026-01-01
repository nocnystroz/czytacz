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

# --- Konfiguracja i stałe ---
# Ustalenie ścieżki do katalogu aplikacji i załadowanie .env
APP_DIR = os.path.dirname(os.path.realpath(__file__))
dotenv_path = os.path.join(APP_DIR, ".env")
load_dotenv(dotenv_path=dotenv_path)

JINA_READER_URL = "https://r.jina.ai/"

# --- Logika LLM (streszczanie) ---

def _call_gemini(text: str, api_key: str) -> str | None:
    """Wysyła zapytanie do Google Gemini API."""
    print("Próbuję użyć Gemini do streszczenia...")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    prompt = f"Streszcz poniższy tekst w języku polskim w maksymalnie 5-7 zdaniach. Skup się na najważniejszych informacjach. Tekst do streszczenia:\n\n{text}"
    data = {"contents": [{"parts": [{"text": prompt}]}]}

    try:
        response = requests.post(url, headers=headers, json=data, timeout=45)
        response.raise_for_status()
        result = response.json()
        summary = result["candidates"][0]["content"]["parts"][0]["text"]
        return summary.strip()
    except Exception as e:
        print(f"Błąd Gemini (summarize): {e}", file=sys.stderr)
        return None

def _call_openai(text: str, api_key: str, model: str) -> str | None:
    """Wysyła zapytanie do OpenAI API."""
    print(f"Próbuję użyć OpenAI ({model}) do streszczenia...")
    # Tutaj logika dla OpenAI, na razie placeholder
    print("Logika dla OpenAI nie została jeszcze zaimplementowana.", file=sys.stderr)
    return None

def _call_deepseek(text: str, api_key: str, model: str) -> str | None:
    """Wysyła zapytanie do DeepSeek API."""
    print(f"Próbuję użyć DeepSeek ({model}) do streszczenia...")
    # Tutaj logika dla DeepSeek, na razie placeholder
    print("Logika dla DeepSeek nie została jeszcze zaimplementowana.", file=sys.stderr)
    return None
    
def _call_ollama(text: str, base_url: str, model: str) -> str | None:
    """Wysyła zapytanie do lokalnego serwera Ollama."""
    print(f"Próbuję użyć Ollama ({model}) do streszczenia...")
    # Tutaj logika dla Ollama, na razie placeholder
    print("Logika dla Ollama nie została jeszcze zaimplementowana.", file=sys.stderr)
    return None

def summarize_text(text: str) -> str | None:
    """Streszcza tekst używając modeli LLM zgodnie z kolejnością fallback."""
    fallback_order = os.getenv("LLM_FALLBACK_ORDER", "gemini,openai").split(',')
    
    for provider in fallback_order:
        summary = None
        if provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY")
            if api_key and api_key != "Twoj_klucz_api_gemini":
                summary = _call_gemini(text, api_key)
        elif provider == "openai":
            api_key = os.getenv("OPENAI_API_KEY")
            model = os.getenv("OPENAI_MODEL", "gpt-4o")
            if api_key and api_key != "Twoj_klucz_api_openai":
                summary = _call_openai(text, api_key, model)
        # ... (reszta providerów)

        if summary:
            print(f"Streszczenie wygenerowane przez: {provider}")
            return summary
            
    print("Nie udało się uzyskać streszczenia z żadnego skonfigurowanego modelu LLM.", file=sys.stderr)
    return None

# --- Przetwarzanie treści ---

def is_url(text: str) -> bool:
    """Sprawdza, czy podany tekst jest poprawnym adresem URL."""
    try:
        result = urlparse(text)
        return all([result.scheme, result.netloc])
    except ValueError:
        return False

def get_content_from_url(url: str) -> str:
    """Pobiera i zwraca główną treść strony, używając Jina AI Reader."""
    print(f"Pobieranie treści ze strony: {url} ...")
    try:
        response = requests.get(f"{JINA_READER_URL}{url}", timeout=30)
        response.raise_for_status()
        
        full_content = response.text
        print("\n--- Pobrana treść (pełna) ---")
        print(full_content)
        print("--- Koniec treści ---\n")

        lines = full_content.split('\n')
        meaningful_lines = [line.strip() for line in lines if len(line.strip()) > 40]
        potential_content = [line for line in meaningful_lines if len(line.split()) > 5 and line.endswith('.')]
        
        if not potential_content:
            parts = full_content.split('\n\n', 2)
            return max(parts, key=len) if len(parts) > 1 else full_content

        return "\n\n".join(potential_content)

    except requests.RequestException as e:
        return f"Błąd podczas pobierania strony: {e}"

# --- Logika TTS (Text-to-Speech) ---

def _tts_gemini(text: str, temp_filename: str) -> bool:
    """Generuje mowę za pomocą Google Cloud TTS API (traktowane jako Gemini TTS)."""
    api_key = os.getenv("GEMINI_API_KEY")
    model_name = os.getenv("GEMINI_TTS_MODEL", "tts-1") # Nazwa modelu może się różnić
    if not api_key or api_key == "Twoj_klucz_api_gemini":
        return False
        
    print("Próbuję użyć silnika TTS od Google (Gemini/Cloud)...")
    url = f"https://texttospeech.googleapis.com/v1/text:synthesize?key={api_key}"
    headers = {"Content-Type": "application/json"}
    
    # Notka: Używamy standardowego API Google Cloud TTS. Jeśli pojawi się dedykowany endpoint
    # dla Gemini TTS, logika powinna zostać zaktualizowana tutaj.
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
            print("Błąd Google TTS: Brak zawartości audio w odpowiedzi.", file=sys.stderr)
            return False

        with open(temp_filename, "wb") as f:
            f.write(base64.b64decode(audio_content))
        return True

    except Exception as e:
        print(f"Błąd Google TTS: {e}", file=sys.stderr)
        return False

def _tts_gtts(text: str, temp_filename: str) -> bool:
    """Generuje mowę za pomocą biblioteki gTTS (fallback)."""
    from gtts import gTTS
    print("Próbuję użyć silnika gTTS (fallback)...")
    try:
        tts = gTTS(text, lang='pl')
        tts.save(temp_filename)
        return True
    except Exception as e:
        print(f"Błąd gTTS: {e}", file=sys.stderr)
        return False

def read_aloud(text: str):
    """Konwertuje tekst na mowę i odtwarza go, używając skonfigurowanych silników TTS."""
    if not text.strip():
        print("Brak tekstu do przeczytania.")
        return

    print("Przygotowuję mowę...")
    fallback_order = os.getenv("TTS_FALLBACK_ORDER", "gemini,gtts").split(',')
    
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
            print("Odtwarzam...")
            player_command = ["mpg123", "-q", temp_file]
            subprocess.run(player_command, check=True, capture_output=True)
        else:
            print("Wszystkie skonfigurowane silniki TTS zawiodły.", file=sys.stderr)

    except Exception as e:
        print(f"Wystąpił błąd podczas generowania lub odtwarzania mowy: {e}", file=sys.stderr)
        print("Upewnij się, że masz zainstalowany program 'mpg123' (`sudo apt install mpg123`).", file=sys.stderr)
    finally:
        if temp_file and os.path.exists(temp_file):
            os.remove(temp_file)
            print("Plik tymczasowy został usunięty.")

def main():
    """Główna funkcja skryptu."""
    parser = argparse.ArgumentParser(
        description="Czyta na głos podany tekst lub treść strony internetowej, z opcją streszczenia."
    )
    parser.add_argument(
        "-s", "--summarize",
        action="store_true",
        help="Aktywuje streszczanie tekstu przed przeczytaniem przy użyciu LLM.",
    )
    parser.add_argument(
        "text_parts",
        nargs='+',
        type=str,
        help="Tekst do przeczytania lub adres URL. Wszystkie słowa zostaną połączone w jeden ciąg.",
    )
    args = parser.parse_args()

    # Łączenie wszystkich części tekstu w jeden ciąg
    content_to_process = " ".join(args.text_parts)
    
    # Sprawdzenie czy połączony tekst jest pojedynczym URL-em
    # len(args.text_parts) == 1 zapobiega próbie traktowania "https://onet.pl i coś jeszcze" jako URL
    if len(args.text_parts) == 1 and is_url(content_to_process):
        content_for_reading = get_content_from_url(content_to_process)
    else:
        content_for_reading = content_to_process

    if args.summarize:
        print("Aktywowano tryb streszczania.")
        summary = summarize_text(content_for_reading)
        if summary:
            read_aloud(summary)
        else:
            print("Streszczenie nie powiodło się. Czytam oryginalny tekst.", file=sys.stderr)
            read_aloud(content_for_reading)
    else:
        read_aloud(content_for_reading)

if __name__ == "__main__":
    main()
