# Stwory z obory — cyfrowa adaptacja (Lua / LÖVE 11.5)

Nieoficjalna, cyfrowa wersja karcianki **„Stwory z obory”** (Tomasz Bolik, Muduko) do gry ze znajomymi przez LAN lub Tailscale, bez centralnego serwera. Zasady zaimplementowano na podstawie dołączonej instrukcji (`stwory-z-obory-instrukcja.pdf`); pełna specyfikacja i lista założeń: `docs/rules-spec.md`.

## Wymagania

- **LÖVE 11.5** (https://love2d.org) — Windows, macOS, Linux.
- Brak dodatkowych bibliotek do instalowania: LuaSocket jest wbudowany w LÖVE; `src/lib/flux.lua` (MIT) i `src/net/json.lua` (MIT) są dołączone.
- Czcionki: VT323, Pixelify Sans, Press Start 2P (licencja OFL, w `assets/fonts/`).
- Do testów silnika: dowolny interpreter Lua (`luajit` lub `lua` 5.4); test sieci wymaga LuaSocket dla tego interpretera.

## Uruchamianie

```
love .            # z katalogu projektu
love stwory.love  # ze spakowanego pliku (patrz „Pakowanie”)
```

Windows: przeciągnij folder projektu (albo plik `.love`) na `love.exe`, lub uruchom `"C:\Program Files\LOVE\love.exe" C:\sciezka\do\game`.

## Jak zagrać przez sieć

1. **Host**: menu → „Stwórz pokój (host)” → imię, port (domyślnie 29999) → „Utwórz pokój”. Lobby pokazuje adres LAN i adres Tailscale (jeśli wykryty) oraz port; przycisk „Kopiuj adres” kopiuje `adres:port`.
2. **Gracze**: „Dołącz do gry” → imię, adres hosta, port → „Połącz”.
3. Gdy w lobby jest 2–5 graczy, host klika „Rozpocznij grę”.
4. Host jest autorytatywny: klienci wysyłają żądania akcji, host je weryfikuje i rozsyła każdemu *tylko jego* widok (cudze karty na ręce i zakryte karty są ukryte).

**LAN**: host musi odblokować port TCP w zaporze (Windows Defender pyta przy pierwszym uruchomieniu — zezwól dla sieci prywatnych). Adres LAN to zwykle `192.168.x.x`.

**Tailscale**: wszyscy logują się do tej samej sieci Tailscale; host podaje adres `100.x.y.z` (komenda `tailscale ip -4`). Ruch Tailscale zwykle omija zaporę domową, ale lokalna zapora hosta nadal musi przepuszczać port. Jeśli połączenie nie dochodzi, sprawdź `tailscale status` i ping adresu hosta.

**Rozłączenia**: klient dostaje komunikat i przycisk „Połącz ponownie” (ponowne dołączenie tokenem — stan gry wraca). Gdy host zamknie grę, klienci widzą „Host zakończył grę”. Host może w panelu akcji „Pominąć” nieobecnego gracza (wykonywana jest akcja domyślna, np. pas), żeby nie blokował partii.

## Sterowanie

- Mysz: klik karty na ręce = zaznaczenie (ponowny klik odznacza); klik karty na Targowisku = kupno; przyciski w panelu po prawej / w arenie walki.
- Najechanie myszą: karta na ręce wysuwa się i pokazuje pełny podgląd; wachlarz przeciwnika → jego status (zdrowie, sława, miedziaki, sprzęt); talie → liczniki i ostatnio odrzucona karta; własny portret → pełny status.
- Klawisze: `Spacja`/`Enter` — główny przycisk (zielony/czerwony); `Esc` — ustawienia / wyjście do menu; `F11` — pełny ekran; `Tab`/`Enter` w formularzach.

## Struktura projektu

```
main.lua, conf.lua        – pętla LÖVE, ekrany, kanwa 640x360 (pixel-art)
src/game/cards.lua        – WSZYSTKIE karty i postacie (dane, nie wygląd)
src/game/rules.lua        – silnik zasad: stan, walidacja akcji, widoki graczy
src/game/rng.lua          – deterministyczny RNG
src/net/transport.lua     – TCP (LuaSocket), JSON po liniach, bez blokowania
src/net/host.lua          – serwer + autorytatywny stan; src/net/client.lua – klient
src/ui/theme.lua          – paleta, czcionki, kafelki pikselowe, skalowanie
src/ui/cardart.lua        – rysowanie kart (sprite'y 20x20, tekstury)
src/ui/screens/*.lua      – menu, host, join, lobby, game, settings, gameover, disconnected
src/ui/anim.lua, widgets  – animacje (flux), przyciski, pola, komunikaty
src/audio.lua             – dźwięki generowane proceduralnie
tests/                    – testy (patrz niżej); docs/rules-spec.md – specyfikacja zasad
```

## Testy

```
luajit tests/run.lua      # 33 testy zasad (każdy efekt karty, tury, koniec gry)
luajit tests/sim.lua      # 160 losowych pełnych partii (2–5 graczy): brak zakleszczeń
luajit tests/net_test.lua # host + 2 klientów na loopbacku: lobby, sync, ukrywanie, reconnect
STWORY_AUTOTEST=1 STWORY_BOTS=3 love .   # automatyczna partia w LÖVE sterowana przez UI, zrzuty w katalogu zapisu LÖVE (autotest/)
```

Wykonane w tym środowisku (Linux, LÖVE 11.5 pod Xvfb): wszystkie powyższe przechodzą. Nie wykonano: testu na dwóch fizycznych komputerach ani przez prawdziwą sieć Tailscale.

## Pakowanie

```
./build.sh     # tworzy dist/stwory.love (zip katalogu bez testów i PDF)
```

Plik `.love` uruchamia się na każdym systemie z LÖVE 11.5. Wersję `.exe` robi się przez `copy /b love.exe+stwory.love stwory.exe` w katalogu LÖVE dla Windows (wraz z dll-kami).

## Znane ograniczenia

- Skład talii poza kartami potwierdzonymi z instrukcji/zdjęć uzupełniono duplikatami; 10 niejasności zasad rozstrzygnięto założeniami opisanymi w `docs/rules-spec.md` §13–14 — do potwierdzenia przez właściciela gry.
- Ilustracje są proceduralnymi sprite'ami pixel-art (brak licencji na oryginalne grafiki).
- Negocjacje/przekupstwa między graczami („Zatargi”) odbywają się poza programem.
- Gra 2-osobowa: gdy jeden gracz odpadnie, drugi wygrywa.
- Brak muzyki (tylko efekty dźwiękowe).
