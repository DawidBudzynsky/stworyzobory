# Stwory z obory — specyfikacja zasad (na podstawie `stwory-z-obory-instrukcja.pdf`)

Dokument jest źródłem prawdy dla implementacji w `src/game/`. Każdy punkt ma oznaczenie:

- **[I s.N]** — wprost z instrukcji (strona N PDF),
- **[K]** — odczytane z tekstu konkretnej karty (ilustracje w instrukcji lub zdjęcia kart w recenzjach),
- **[Z]** — **założenie** (instrukcja nie rozstrzyga; patrz rozdział 12 — do potwierdzenia przez właściciela gry).

## 1. Elementy gry [I s.1]

| Element | Liczba |
|---|---|
| karty postaci | 10 |
| karty Targowiska | 18 |
| karty Wioski | 43 |
| karty Gościńca | 36 |
| karta zagrywki (WALKA / ZLECENIE) | 1 |
| kostka: oczka 1–5 + ikona „niszczenie karty” | 1 |
| żetony: zdrowie 24, sława 36, zwycięstwo (korona) 6, miedziaki 42 | — |

Liczba graczy: 2–5 (pudełko). Cel: **7 punktów sławy** [I s.1, s.12].

## 2. Przygotowanie [I s.2–3]

1. Trzy talie (Targowisko, Wioska, Gościniec) są tasowane osobno. Obok Targowiska leżą **3 odkryte karty** (rynek).
2. Każdy gracz losuje **2 karty postaci**, wybiera 1 do gry. Druga (odwrócona) jest kartą statystyk; po śmierci staje się nową postacią.
3. Karta statystyk: 3 żetony zdrowia (**Onufry: 4** [K]), 1 żeton sławy na dowolnym polu z gwiazdką (nie na koronie).
4. Każdy otrzymuje 1 miedziaka (**Alojz: 3**, **Gienek: zamiast miedziaka punkt sławy**, czyli 0 miedziaków i 2 sławy).
5. Każdy dobiera 4 karty Wioski (**Ruda: 6**). Może wymienić 1 kartę: odkłada ją na spód talii Wioski i dobiera 1 z wierzchu.
6. Ekwipunek: miejsce na 2 bronie + 1 zakryty eliksir (**Jednoręki Fred: 1 broń**). Start bez ekwipunku, wyjątek **Siergiej: 1 losowa karta ekwipunku** [K].
7. Limity: nieograniczona liczba miedziaków i kart na ręce; zdrowie nie może przekroczyć wartości startowej.
8. Rozpoczyna „gracz, który ogarnia zasady” [I s.4] → w grze cyfrowej rozpoczyna **host** [Z], dalej zgodnie z ruchem wskazówek zegara (kolejność w lobby).

## 3. Karta statystyk i sława [I s.2, s.15]

- 6 pól z gwiazdką: po 2 w kolorze czerwonym, zielonym, niebieskim, ułożone w pierścień wokół pola z koroną. Kolejność pierścienia: czerwony, czerwony, zielony, zielony, niebieski, niebieski (cyklicznie) [K, układ karty].
- Nowe punkty sławy dokłada się **obok już leżących — nie może powstać przerwa**; gracz wybiera pole, niezależnie od koloru pokonanego potwora.
- **2 punkty sławy w jednym kolorze = dodatkowa premia +1 w tym kolorze** (dopóki oba pola są zajęte).
- 7. żeton kładzie się na koronie = **natychmiastowe zwycięstwo**.
- Utrata punktu sławy: zdejmowany jest żeton z końca ciągu (aby nie powstała przerwa); jeśli oba końce leżą w różnych kolorach, gracz wybiera [Z].

## 4. Postacie [K — tekst kart]

| Postać | Zawód | Cecha | Premia stała |
|---|---|---|---|
| Falgrim | Bimbrownik | Żółte karty przebrań także dają premię +1. | +1 czerwony |
| Onufry | Drwal | Na starcie masz 4 punkty zdrowia. | +1 zielony |
| Alojz | Grabarz | Zaczynasz grę z 3 miedziakami. | +1 niebieski |
| Ruda | Druidka | Na początku gry dobierasz 6 kart z talii Wioski. | +1 zielony |
| Jednoręki Fred | Górnik przodowy | Możesz używać tylko jednej broni. | +1 czerwony, +1 zielony |
| Gienek | Bamber | Na początku zamiast miedziaka dobierasz dodatkowy punkt sławy. | brak |
| Otto | Guślarz | Możesz przerzucić kość 2 razy na turę (każdy przerzut kosztuje 1 punkt sławy). | brak |
| Gajowy Szyszka | Łowczy | Jeśli pokonasz 2 leśne bestie, otrzymasz 1 dodatkowy punkt sławy. | +1 zielony |
| Natasza | Złodziejka | Za pokonanie magicznej bestii otrzymujesz 2 miedziaki więcej. | +1 niebieski |
| Siergiej | Traper | Zaczynasz grę z 1 losową kartą ekwipunku. | +1 czerwony [Z — kolor odczytany z niewyraźnego zdjęcia] |

Premie postaci obowiązują całą grę [I s.13]. Szyszka: za **każde** 2 pokonane leśne bestie +1 sława [Z].

## 5. Kolory i rodzaje kart [I s.4]

- Potwory: **plugawe = czerwone**, **leśne = zielone**, **magiczne = niebieskie**. Bronie i premie w tych kolorach.
- Zagrywana karta musi pasować kolorem do potwora. Wyjątek: **żółte** i **czarne** karty specjalne — pasują do każdego koloru.
- Gdy zagrana zostaje czarna karta, pozostałe zagrane karty tracą ważność.
- Karty z ręki są jednorazowe. Bronie z Targowiska są stałe.
- Polecenia na karcie dotyczą osoby, która ją zagrywa. **Zasady na kartach mają pierwszeństwo przed instrukcją** [I s.12].

## 6. Tura gracza [I s.4–5]

Kolejność akcji:

1. **Targowisko** (opcjonalnie, wielokrotnie, póki starcza miedziaków):
   - kup 1 z 3 odkrytych kart; cena w prawym górnym rogu; po kupnie uzupełnij rynek z talii Targowiska;
   - kupiony ekwipunek musi zostać **natychmiast wyposażony**; przy pełnym ekwipunku trzeba najpierw odrzucić wyposażoną kartę (wyjątek: **Potjon** można zużyć od razu mimo pełnego ekwipunku);
   - odrzucaną broń można oddać/sprzedać innemu graczowi za umówioną kwotę (negocjacje — **nie są wymuszane przez program**; można to zrobić głosowo, w grze broń trafia na stos odrzuconych) [Z];
   - za **4 miedziaki** można kupić **1 punkt sławy** (maks. 1 na turę; **nie można kupić siódmego, zwycięskiego punktu**).
2. **Wioska**: dobierz 1 kartę Wioski na rękę (obowiązkowo, w ukryciu).
3. **Gościniec**: odkryj kartę z wierzchu Gościńca na Pole Walki, **albo** zamiast tego dobierz drugą kartę Wioski — wtedy tura się kończy.
   - **Wydarzenie**: odczytaj publicznie, zrealizuj; dotyczy gracza, który odkrył kartę; potem koniec tury.
   - **Potwór**: zdecyduj — **Walka** albo **Zlecenie** (karta zagrywki).

## 7. Walka [I s.6–9]

Atakujący = gracz, który ogłosił walkę (lub ochotnik ze zlecenia).

1. **Dorzucanie kart** (tylko w walce ogłoszonej przez gracza w jego turze; w zleceniu karty dodał już zleceniodawca [Z]): każdy inny gracz może zagrać **1 zakrytą kartę** do potwora.
2. Atakujący **wybiera dokładnie 1** z dorzuconych kart; jest odkrywana i uwzględniana. Pozostałe wracają do właścicieli.
3. Jeśli odkryta/ujawniona karta jest **czarna** — działa w pierwszej kolejności i jako jedyna (patrz §9).
4. Atakujący zagrywa z ręki **karty premii** w kolorze potwora, aby wzmocnić postać (jednorazowo, przed rzutem). Nie można użyć jako premii kart specjalnych (żółtych — w tym przebrań — ani czarnych).
5. Atakujący może użyć **eliksirów w dowolnym momencie walki**.
6. **Siła gracza** = premie postaci (stała + za 2 sławy w kolorze) + wyposażone bronie w kolorze + premie z ręki + rzut kością.
   **Siła potwora** = wartość z karty + premie kart dodanych (pasujących kolorem lub żółtych).
   Wygrana, gdy **siła gracza ≥ siła potwora**.
7. **Rzut kością**: 1–5 lub ikona niszczenia.
   - **Niszczenie karty**: najpierw odrzuca się **1 kartę dodaną do potwora** i rzuca ponownie. Jeśli nie ma dodanych kart (do zniszczenia) — **automatyczna wygrana**. Nie działa na karty czarne ani na „Strzeżone miedziaki” [K]. Którą kartę zniszczyć wybiera atakujący [Z].
8. **Przerzut kości**: każdy gracz (także atakujący) może anulować wynik rzutu, oddając **1 punkt sławy do puli nagród**. Każdy gracz maks. **1 raz na walkę** (Otto: 2 razy, płacąc za każdy). Wymaga posiadania punktu sławy. Zwycięzca zgarnia pulę razem z zastawionymi punktami.
9. **Wynik**: przegrana → atakujący traci 1 zdrowie. Wygrana → atakujący zgarnia całą pulę.
10. **Pula nagród** = ikony sławy i miedziaków ze wszystkich kart na Polu Walki + punkty sławy z zastawów (+2 miedziaki ze „Strzeżonych miedziaków”).
11. **Przebranie** w walce: wygrana atakującego → atakujący bierze pulę, właściciel przebrania traci 1 zdrowie; przegrana → atakujący traci zdrowie, właściciel przebrania zgarnia pulę.
12. Po walce wszystkie karty z Pola Walki i zagrane premie trafiają na odpowiednie stosy odrzuconych. Tura kończy się.

Szczegół: przerzut kości wymaga reakcji wszystkich graczy; w grze cyfrowej każdy gracz przy wyniku rzutu klika „Akceptuj” lub „Przerzuć (−1 sława)”; wynik jest ostateczny, gdy wszyscy zaakceptują [Z — implementacja].

## 8. Zlecenie [I s.10–12]

1. Zleceniodawca kładzie obok potwora **0–3 zakryte karty** z ręki. Karty niepasujące kolorem nie są brane pod uwagę (poza żółtymi i czarnymi). Nie można dodać 2 czarnych kart. Nie można dodać „Mój ci on”.
2. Pyta pozostałych graczy, czy walczą. Pierwszy zgłoszony podejmuje walkę; jeśli zgłosi się kilku — zleceniodawca wybiera. W grze cyfrowej wszyscy zgłaszają się równocześnie, po czym zleceniodawca wybiera [Z].
3. Gdy jest ochotnik: karty zostają **odkryte** i zaczyna się Walka (§7, od kroku 3; fazy dorzucania kart nie ma [Z]).
4. **Przebranie** → potwór staje się Stworem z Obory. Jeśli nikt nie walczy **albo** przebraniec wygra — zleceniodawca zgarnia pulę. Jeśli Stwór z Obory przegra — zleceniodawca traci 1 zdrowie. Do Stwora **nie dolicza się** premii ekwipunku ani postaci zleceniodawcy — liczą się tylko karty na Polu Walki.
5. **Świnia** (karta czarna) → walka się nie odbywa, atakujący automatycznie przegrywa (bez utraty zdrowia), realizowany jest efekt świni; inne dodane karty tracą ważność.
6. **Nikt nie walczy** → potwór i dodane karty na stos odrzuconych bez konsekwencji, chyba że było przebranie (pkt 4).
7. Jeśli nikt nie walczy i nie było przebrania, karty przepadają.

## 9. Karty specjalne Wioski [I s.14, K]

| Karta | Kolor | Premia dla potwora | Efekt |
|---|---|---|---|
| Przebranie (uniwersalne) | żółta | 0 (Falgrim: +1) | „Nikt nie walczy albo atakujący przegrywa? Zgarniasz pulę! Atakujący wygrywa? Tracisz życie.” |
| Przebranie czerwone / zielone / niebieskie | kolor | +1 w swoim kolorze (w innym kolorze liczy się tylko efekt przebrania [Z]) | jak wyżej |
| Na krzywy ryj | żółta | 0 [Z] | „Jeśli atakujący wygra, dostajesz 1 punkt sławy.” |
| Hiena | żółta | +1 | „Jeśli atakujący przegra, zabierasz mu miedziaki lub 1 kartę ekwipunku.” (wszystkie miedziaki; wybiera właściciel Hieny) |
| Wampir | żółta | +1 | „Jeśli atakujący przegra, zabierasz jego utracony punkt zdrowia.” (nie powyżej maksimum) |
| Mój ci on | czarna | — | Przejmujesz potwora: to Ty walczysz; inni gracze nie mogą już dorzucać kart. Nie można dodać do zlecenia. |
| Ustawka | czarna | — | Zamiast walki z potworem walka gracz kontra gracz (zagrywający vs atakujący). Zagrywający wybiera kolor walki. Przed rzutem obaj mogą dorzucić premię z ręki. Rzut przeciw rzutowi (siła = premie w kolorze + rzut). Pierwszy rzuca zagrywający. Ikona niszczenia = automatyczna wygrana, chyba że przeciwnik też ją wyrzuci (remis → powtórka). Bez przerzutów. Wygrany: +1 sława z puli gry i zabiera miedziaki przegranego. Potwór trafia na stos odrzuconych bez nagrody [Z]. |
| Pazerna świnia | czarna | — | „Atakujący przegrywa, ale nie traci życia. Zamiast puli zabierasz przegranemu wszystkie miedziaki.” |
| Sromotna świnia | czarna | — | „Atakujący przegrywa, ale nie traci życia. Zamiast puli zabierasz przegranemu 1 punkt sławy.” |

Efekty Hieny, Wampira, Na krzywy ryj dotyczą gracza, który zagrał kartę (w walce — gracz dorzucający, w zleceniu — zleceniodawca). Wymagają, aby karta była tą wybraną/odkrytą.

## 10. Targowisko [I s.5, s.13, K]

- Bronie: stała premia +1 w kolorze (lub w dwóch kolorach), maks. 2 wyposażone.
- Eliksiry: jednorazowe, 1 zakryty przy postaci; używa atakujący w dowolnym momencie walki (Potjon także poza walką przy kupnie).
  - **Potjon** — przywraca 1 punkt zdrowia [Z — treść karty odczytana z opisu ogólnego: „przywracają utracone punkty zdrowia”].
  - **Dzik** — „Powiększ swój wynik o dodatkowy rzut kością. Ikona niszczenia karty to automatyczna wygrana. JEDNORAZOWA” [K].
  - **Wilk** — „W tej walce możesz użyć broni oraz premii wybranego przez Ciebie koloru. JEDNORAZOWA” [K] (dodatkowy kolor liczony obok koloru potwora [Z]).
- Ceny odczytane z ikon monet: broń jednokolorowa 1, broń dwukolorowa 4, eliksir 2 [Z].

## 11. Gościniec [I s.15, K]

Potwory: kolor, siła, nagroda (gwiazdka = 1 sława, ikony monet = miedziaki). Wydarzenia:

| Wydarzenie | Efekt |
|---|---|
| Leci mucha | „Bzzz…” — utrata tury [I s.15]. |
| Znachor | Możesz sprzedać narządy: tracisz 1 zdrowie, zyskujesz 4 miedziaki. Nie można użyć, jeśli doprowadziłoby do śmierci [K]. |
| Loteria dożynkowa | Ciągniesz 1 kartę ekwipunku z wierzchu talii Targowiska (wyposażasz natychmiast, przy pełnym ekwipunku odrzucasz coś) [K]. |
| Wieprz! | Tracisz 1 punkt sławy; trafia on do najsłabszego według Ciebie gracza (wybierasz) [K]. |
| Gorzoła odwagi | Ciągnij kolejną kartę Gościńca. Jeśli to potwór, musisz walczyć [K]. |
| Strzeżone miedziaki | Zostaje na Polu Walki: pula za najbliższego potwora +2 miedziaki; ciągnij kolejną kartę Gościńca; karty nie można zniszczyć rzutem [K]. |
| Wiejski Dziad | Podejrzyj 3 wierzchnie karty Gościńca, 1 odłóż na wierzch, resztę odrzuć [Z — tekst karty tylko częściowo czytelny]. |

## 12. Pozostałe zasady [I s.12–13]

- **Śmierć**: 0 zdrowia → postać ginie; wszystkie punkty sławy i miedziaki wracają do puli; ekwipunek zostaje; druga karta postaci staje się nową postacią przygotowaną jak na początku (zdrowie, 1 sława, 1 miedziak; stosowane są cechy startowe nowej postaci poza wielkością ręki [Z]). Śmierć drugiej postaci = odpadnięcie z gry. Gdy zostaje 1 gracz, wygrywa [Z].
- **Zabrakło kart**: przetasować stos odrzuconych danej talii.
- **Zatargi** (przekupywanie) — poza programem.
- **Koniec gry**: 7. żeton sławy → zwycięzca („Król Pogromców Potworów”).

## 13. Skład talii — założenia wymagające potwierdzenia

Instrukcja podaje tylko łączne liczby kart. Z instrukcji i zdjęć znane są karty wymienione poniżej jako „potwierdzone”. Reszta talii została uzupełniona **duplikatami potwierdzonych kart** (bez wymyślania nowych efektów), aby liczby kart zgadzały się z instrukcją. Skład jest w jednym pliku `src/game/cards.lua` i można go poprawić bez dotykania logiki.

**Wioska (43)**: premie 7×czerwone, 7×zielone, 7×niebieskie; przebrania: 3 żółte + 3 kolorowe; Na krzywy ryj ×3, Hiena ×3, Wampir ×3; Mój ci on ×2, Ustawka ×2; Pazerna świnia ×2, Sromotna świnia ×1.
Potwierdzone nazwy premii: Przepocone kalesony (cz.), Bomba gazowa (cz.), Zatrute kolce, Porcja grochu, Esencja z capa, Piekielne ziele (nieb.), Gorejący bunclok (nieb.), Najczystszy szpirytus (nieb.), Lewoskrętna mana (nieb.). Kolor Zatrutych kolców, Porcji grochu, Esencji z capa i Kiszonki — założenie.

**Gościniec (36)**: 24 potwory (8 na kolor) + 12 wydarzeń. Potwierdzone: Szambiarka (cz. 5, 1★ 1¢), Cmentarny dziad (cz. 4, 1★ 1¢), Praszczur (cz. 6, 1★ 2¢), Utopiec (cz. 5, 1★ 1¢), Wąpierz (cz., wartości [Z]), Bebok (nieb. 4, 1★ 1¢), Wilkołak (nieb. 4, 1★ 1¢), Licho (nieb. 3, 1¢), Czort (nieb. 5, 1★ 2¢), Nocnica (nieb., wartości [Z]), Poczwara (nieb. 6, 1★ 1¢), Zmora (nieb. [Z]), Bagiennik (ziel. 4, 1★), Arachna (ziel. 4, 1★ 1¢), Leśny troll (ziel. 5, 1★ 1¢), Bies (ziel. 6, 1★ 1¢), Borowy (ziel. 6 [Z]), Purchwiel (ziel. 3, 2¢). Wydarzenia jak w §11, w liczbie 12 (duplikaty).

**Targowisko (18)**: 12 broni + 6 eliksirów. Potwierdzone: Kupa na patyku (nieb.), Pała (cz.), Cep (cz.), Kosa (ziel.), Sierp (ziel.), Siekiera (ziel.), Widły (ziel.+cz.), Kołek osikowy (nieb.), Posrebrzany miecz (cz.+nieb.), Potjon, Dzik, Wilk. Eliksir „Lis” istnieje, ale jego tekst nie jest znany — pominięty (zastąpiony duplikatem).

## 14. Niejednoznaczności rozstrzygnięte założeniem (lista do potwierdzenia)

1. Kto wybiera kartę niszczoną ikoną kostki → atakujący.
2. Czy w walce ze zlecenia inni gracze dorzucają kolejną kartę → nie.
3. Ustawka: co z potworem i jego nagrodą → odrzucany bez nagrody.
4. Kolorowe przebranie zagrane do potwora w innym kolorze → działa jako przebranie, bez +1.
5. Utrata sławy — który żeton → z końca ciągu (wybór gracza, gdy końce różnią się kolorem).
6. Nowa postać po śmierci → cechy startowe nowej postaci (Alojz 3¢, Gienek sława, Onufry 4 HP, Siergiej ekwipunek).
7. Gra 2-osobowa: gdy jeden gracz odpadnie, drugi wygrywa.
8. Wilk — wybrany kolor liczony dodatkowo do koloru potwora.
9. Ceny ekwipunku i skład talii — §13.
10. Gracz rozpoczynający → host.
