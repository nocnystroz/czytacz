# Czytacz

Czytacz to proste narzędzie wiersza poleceń, które potrafi przeczytać na głos dowolny tekst lub treść wskazanej strony internetowej. Używa syntezatora mowy Google (gTTS) do generowania mowy.

Dodatkowo, posiada opcjonalną funkcję streszczania długich tekstów przy użyciu skonfigurowanego modelu językowego (LLM) przed ich przeczytaniem.

## Główne funkcje

- Czytanie tekstu na głos w języku polskim.
- Pobieranie i czytanie treści ze stron internetowych (za pomocą `r.jina.ai`).
- Opcjonalne streszczanie treści za pomocą modeli LLM (Gemini, OpenAI, DeepSeek, Ollama).
- Konfiguracja kluczy API, kolejności modeli LLM oraz silników TTS poprzez plik `.env`.
- Prosta instalacja i integracja z terminalem za pomocą polecenia `czytaj`.

## Instalacja

Główną i zalecaną metodą instalacji jest użycie dołączonego skryptu `install.sh`.

```bash
# Upewnij się, że skrypt ma uprawnienia do wykonania
chmod +x installator/install.sh

# Uruchom instalator z głównego katalogu repozytorium
bash installator/install.sh
```

Skrypt automatycznie:
1.  Wykryje menedżera pakietów i zainstaluje `mpg123`.
2.  Stworzy katalog `~/.local/share/czytacz` i skopiuje tam pliki aplikacji.
3.  Stworzy wirtualne środowisko Python i zainstaluje zależności z `requirements.txt`.
4.  Doda polecenie `czytaj` do Twojej powłoki (`.bashrc` lub `.zshrc`).

Po zakończeniu instalacji, uruchom ponownie terminal lub odśwież sesję poleceniem `source ~/.bashrc` (lub `source ~/.zshrc`).

## Użycie

```bash
# Czytanie prostego tekstu (cudzysłowy nie są już wymagane)
czytaj To jest przykładowy tekst do przeczytania.

# Czytanie treści strony internetowej
czytaj https://example.com

# Streszczenie i przeczytanie długiego tekstu
czytaj -s To jest bardzo długi tekst, który chcemy streścić...
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

Zalecaną metodą deinstalacji jest użycie skryptu `uninstall.sh`.

```bash
# Upewnij się, że skrypt ma uprawnienia do wykonania
chmod +x installator/uninstall.sh

# Uruchom deinstalator
bash installator/uninstall.sh
```

Skrypt poprosi o potwierdzenie, a następnie automatycznie usunie funkcję `czytaj` z konfiguracji powłoki oraz skasuje cały katalog aplikacji `~/.local/share/czytacz`.

### Ręczna deinstalacja

Jeśli z jakiegoś powodu wolisz usunąć narzędzie ręcznie, poniżej znajdują się kroki, które wykonuje skrypt:

#### 1. Usunięcie funkcji z `.bashrc` / `.zshrc`
Użyj poniższej komendy, aby automatycznie usunąć blok funkcji `czytaj` (zalecane utworzenie kopii zapasowej `cp ~/.bashrc ~/.bashrc.bak`).
```bash
sed -i '/# --- Funkcja dla narzędzia Czytacz ---/,/}/d' ~/.bashrc
sed -i '/# --- Funkcja dla narzędzia Czytacz ---/,/}/d' ~/.zshrc
```

#### 2. Usunięcie katalogu z aplikacją
```bash
rm -rf ~/.local/share/czytacz
```

#### 3. Odświeżenie terminala
```bash
source ~/.bashrc 
# lub
source ~/.zshrc
```
