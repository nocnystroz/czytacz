#!/usr/bin/env python3
import argparse
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

# --- Logika LLM ---

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
        print(f"Błąd Gemini: {e}", file=sys.stderr)
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
        elif provider == "deepseek":
            api_key = os.getenv("DEEPSEEK_API_KEY")
            model = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
            if api_key and api_key != "Twoj_klucz_api_deepseek":
                summary = _call_deepseek(text, api_key, model)
        elif provider == "ollama":
            base_url = os.getenv("OLLAMA_BASE_URL")
            model = os.getenv("OLLAMA_MODEL")
            if base_url and model:
                summary = _call_ollama(text, base_url, model)

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

        # Ulepszona heurystyka do ekstrakcji treści
        lines = full_content.split('\n')
        # Usuń puste linie i linie z małą ilością tekstu (prawdopodobnie nagłówki/stopki)
        meaningful_lines = [line.strip() for line in lines if len(line.strip()) > 40]
        # Usuń linie które są prawdopodobnie tytułami (mało słów, bez kropki na końcu)
        potential_content = [line for line in meaningful_lines if len(line.split()) > 5 and line.endswith('.')]
        
        if not potential_content:
             # Fallback do starej, prostej metody jeśli nowa nic nie znajdzie
            parts = full_content.split('\n\n', 2)
            return max(parts, key=len) if len(parts) > 1 else full_content

        return "\n\n".join(potential_content)

    except requests.RequestException as e:
        return f"Błąd podczas pobierania strony: {e}"

def read_aloud(text: str, lang: str = 'pl'):
    """Konwertuje tekst na mowę i odtwarza go."""
    if not text.strip():
        print("Brak tekstu do przeczytania.")
        return

    print("Przygotowuję mowę...")
    temp_filename = None
    try:
        tts = gTTS(text, lang=lang)
        # Użyj tempfile do bezpiecznego stworzenia pliku w systemowym katalogu /tmp
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as fp:
            temp_filename = fp.name
            tts.save(temp_filename)

        print("Odtwarzam...")
        # Użycie -q (quiet) aby zminimalizować output odtwarzacza
        player_command = ["mpg123", "-q", temp_filename]
        subprocess.run(player_command, check=True, capture_output=True)

    except Exception as e:
        print(f"Wystąpił błąd podczas generowania lub odtwarzania mowy: {e}", file=sys.stderr)
        print("Upewnij się, że masz zainstalowany program 'mpg123' (`sudo apt install mpg123`).", file=sys.stderr)
    finally:
        # Gwarantowane usunięcie pliku tymczasowego po zakończeniu
        if temp_filename and os.path.exists(temp_filename):
            os.remove(temp_filename)
            print("Plik tymczasowy został usunięty.")

def main():
    """Główna funkcja skryptu."""
    parser = argparse.ArgumentParser(
        description="Czyta na głos podany tekst lub treść strony internetowej, z opcją streszczenia."
    )
    parser.add_argument(
        "text_or_url",
        type=str,
        help="Tekst do przeczytania lub adres URL strony.",
    )
    parser.add_argument(
        "-s", "--summarize",
        action="store_true",
        help="Aktywuje streszczanie tekstu przed przeczytaniem przy użyciu LLM.",
    )
    args = parser.parse_args()

    content_to_process = args.text_or_url
    
    if is_url(content_to_process):
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
