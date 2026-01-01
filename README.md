# Czytacz

Czytacz to proste narzędzie wiersza poleceń, które potrafi przeczytać na głos dowolny tekst lub treść wskazanej strony internetowej. Używa syntezatora mowy Google (gTTS) do generowania mowy.

Dodatkowo, posiada opcjonalną funkcję streszczania długich tekstów przy użyciu skonfigurowanego modelu językowego (LLM) przed ich przeczytaniem.

## Główne funkcje

- Czytanie tekstu na głos w języku polskim.
- Pobieranie i czytanie treści ze stron internetowych (za pomocą `r.jina.ai`).
- Opcjonalne streszczanie treści za pomocą modeli LLM (Gemini, OpenAI, DeepSeek, Ollama).
- Konfiguracja kluczy API i kolejności modeli poprzez plik `.env`.
- Prosta instalacja i integracja z terminalem za pomocą polecenia `czytaj`.

## Instalacja

Instalacja jest obsługiwana przez skrypt/agenta. Jeśli czytasz ten plik, narzędzie jest prawdopodobnie już zainstalowane. Główne kroki instalacji to:

1. Stworzenie dedykowanego katalogu w `~/.local/share/czytacz`.
2. Utworzenie wirtualnego środowiska Python (`venv`) i instalacja zależności (`gTTS`, `requests`, `python-dotenv`).
3. Instalacja systemowego odtwarzacza `mpg123`.
4. Dodanie funkcji `czytaj` do pliku `~/.bashrc`.

## Użycie

```bash
# Czytanie prostego tekstu
czytaj "To jest przykładowy tekst do przeczytania."

# Czytanie treści strony internetowej
czytaj https://example.com

# Streszczenie i przeczytanie treści strony
czytaj --summarize https://długi-artykuł.com
```

## Instalacja Strony Podręcznika (`man czytaj`)

Aby móc korzystać z pomocy systemowej `man czytaj`, należy zainstalować dołączony plik strony podręcznika. Plik `czytaj.1.gz` znajduje się w tym repozytorium.

1.  **Skopiuj plik `czytaj.1.gz` do katalogu systemowego:**
    ```bash
    sudo cp czytaj.1.gz /usr/local/share/man/man1/
    ```
    *Uwaga: Polecenie `cp` automatycznie nadpisze starą wersję pliku, jeśli już istnieje. Nie trzeba jej wcześniej usuwać.*

2.  **Zaktualizuj bazę danych stron podręcznika:**
    ```bash
    sudo mandb
    ```

Po wykonaniu tych kroków polecenie `man czytaj` powinno działać poprawnie.

---

## Deinstalacja (Jak całkowicie usunąć narzędzie)

Aby całkowicie usunąć `Czytacza` i wszystkie jego komponenty z systemu, wykonaj poniższe kroki.

### 1. Usunięcie funkcji z `.bashrc`

Otwórz plik `~/.bashrc` w edytorze tekstu (np. `nano ~/.bashrc` lub `gedit ~/.bashrc`) i usuń cały poniższy fragment:

```bash
# Function to read text or URL content aloud
function czytaj() {
    # ... cała zawartość tej funkcji ...
}
```

**Alternatywnie**, możesz użyć poniższej komendy, która automatycznie usunie ten blok za pomocą `sed`. Jest to szybsze, ale upewnij się, że masz kopię zapasową `~/.bashrc`, jeśli coś pójdzie nie tak.

```bash
# Utwórz kopię zapasową
cp ~/.bashrc ~/.bashrc.bak

# Usuń funkcję 'czytaj'
sed -i '/# Function to read text or URL content aloud/,/}/d' ~/.bashrc
```

### 2. Usunięcie katalogu z aplikacją

Usuń cały katalog, w którym znajduje się skrypt i jego wirtualne środowisko:

```bash
rm -rf ~/.local/share/czytacz
```

### 3. Odświeżenie terminala

Aby zmiany weszły w życie, otwórz nowy terminal lub odśwież bieżącą sesję poleceniem:

```bash
source ~/.bashrc
```

Po wykonaniu tych trzech kroków, polecenie `czytaj` zniknie, a wszystkie pliki związane z aplikacją zostaną usunięte. Jedyną potencjalną pozostałością może być program `mpg123`, jeśli nie był wcześniej zainstalowany. Możesz go usunąć poleceniem `sudo apt-get remove mpg123`.
