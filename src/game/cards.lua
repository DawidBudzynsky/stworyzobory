-- Definicje wszystkich kart i postaci. Jedyne miejsce z danymi kart.
-- Pola `verified=false` oznaczają wartości odczytane niepewnie / uzupełnione duplikatami
-- (patrz docs/rules-spec.md §13). Logika efektów jest w rules.lua i odwołuje się do `kind`/`effect`.
local M = {}

M.COLORS = { "red", "green", "blue" }
M.COLOR_NAMES = { red = "plugawy", green = "leśny", blue = "magiczny" }
M.COLOR_LABEL = { red = "czerwony", green = "zielony", blue = "niebieski" }

-- Pierścień pól sławy na karcie statystyk (indeks 1..6), kolor każdego pola.
M.FAME_RING = { "red", "red", "green", "green", "blue", "blue" }
M.FAME_TO_WIN = 7
M.FAME_PRICE = 4
M.MAX_WEAPONS = 2
M.BASE_HP = 3

M.characters = {
  { id = "falgrim", name = "Falgrim", job = "Bimbrownik", bonus = { red = 1 },
    trait = "yellow_disguise_bonus", traitText = "Żółte karty przebrań także dają premię +1." },
  { id = "onufry", name = "Onufry", job = "Drwal", bonus = { green = 1 },
    trait = "hp4", traitText = "Na starcie masz 4 punkty zdrowia." },
  { id = "alojz", name = "Alojz", job = "Grabarz", bonus = { blue = 1 },
    trait = "coins3", traitText = "Zaczynasz grę z 3 miedziakami." },
  { id = "ruda", name = "Ruda", job = "Druidka", bonus = { green = 1 },
    trait = "hand6", traitText = "Na początku gry dobierasz 6 kart z talii Wioski." },
  { id = "fred", name = "Jednoręki Fred", job = "Górnik przodowy", bonus = { red = 1, green = 1 },
    trait = "one_weapon", traitText = "Możesz używać tylko jednej broni." },
  { id = "gienek", name = "Gienek", job = "Bamber", bonus = {},
    trait = "fame_instead_coin", traitText = "Na początku zamiast miedziaka dobierasz dodatkowy punkt sławy." },
  { id = "otto", name = "Otto", job = "Guślarz", bonus = {},
    trait = "reroll2", traitText = "Możesz przerzucić kość 2 razy na turę (każdy przerzut kosztuje 1 punkt sławy)." },
  { id = "szyszka", name = "Gajowy Szyszka", job = "Łowczy", bonus = { green = 1 },
    trait = "forest_hunter", traitText = "Jeśli pokonasz 2 leśne bestie, otrzymasz 1 dodatkowy punkt sławy." },
  { id = "natasza", name = "Natasza", job = "Złodziejka", bonus = { blue = 1 },
    trait = "magic_coins", traitText = "Za pokonanie magicznej bestii otrzymujesz 2 miedziaki więcej." },
  { id = "siergiej", name = "Siergiej", job = "Traper", bonus = { red = 1 }, verified = false,
    trait = "start_equipment", traitText = "Zaczynasz grę z 1 losową kartą ekwipunku." },
}

-- ---------------------------------------------------------------- Wioska (43)
-- kind: "bonus" (premia kolorowa), "disguise", "special" (żółta), "black"
local function bonus(name, color, flavor, n, verified)
  return { kind = "bonus", name = name, color = color, power = 1, flavor = flavor, count = n or 1, verified = verified ~= false }
end

M.village = {
  -- czerwone premie (7)
  bonus("Przepocone kalesony", "red", "Jeśli Twoje kalesony stoją, a jeszcze ich nie ubrałeś, wiedz, że coś się dzieje.", 2),
  bonus("Bomba gazowa", "red", "„Zjedz słuszną porcję grochu, zaś kiedy poczujesz moc, naprędce napełnij pęcherz”. – Poradnik małego alchemika", 2),
  bonus("Zatrute kolce", "red", "„Wystarczy jeden w rzyci i kaplica”. – Hans, cyrulik", 1, false),
  bonus("Porcja grochu", "red", "Paliwo do bomby gazowej.", 2, false),
  -- zielone premie (7)
  bonus("Esencja z capa", "green", "Zapach, który odstrasza wszystko, co żywe.", 4, false),
  bonus("Kiszonka", "green", "Wiaderko kiszonych ogórków. Moc!", 3, false),
  -- niebieskie premie (7)
  bonus("Piekielne ziele", "blue", "Silnie odurzająca mieszanka ziół, fermentowana pod pachami leśnych trolli.", 2),
  bonus("Gorejący bunclok", "blue", "Płonie i budzi grozę.", 2),
  bonus("Najczystszy szpirytus", "blue", "łac. spiritus – duch", 2),
  bonus("Lewoskrętna mana", "blue", "Dla wtajemniczonych.", 1, false),
  -- przebrania (6)
  { kind = "disguise", name = "Przebranie", color = "yellow", power = 0, count = 3,
    text = "Nikt nie walczy albo atakujący przegrywa? Zgarniasz pulę! Atakujący wygrywa? Tracisz życie." },
  { kind = "disguise", name = "Przebranie", color = "red", power = 1, count = 1,
    text = "Nikt nie walczy albo atakujący przegrywa? Zgarniasz pulę! Atakujący wygrywa? Tracisz życie." },
  { kind = "disguise", name = "Przebranie", color = "green", power = 1, count = 1,
    text = "Nikt nie walczy albo atakujący przegrywa? Zgarniasz pulę! Atakujący wygrywa? Tracisz życie." },
  { kind = "disguise", name = "Przebranie", color = "blue", power = 1, count = 1,
    text = "Nikt nie walczy albo atakujący przegrywa? Zgarniasz pulę! Atakujący wygrywa? Tracisz życie." },
  -- żółte specjalne (9)
  { kind = "special", effect = "crooked", name = "Na krzywy ryj", color = "yellow", power = 0, count = 3,
    text = "Jeśli atakujący wygra, dostajesz 1 punkt sławy." },
  { kind = "special", effect = "hyena", name = "Hiena", color = "yellow", power = 1, count = 3,
    text = "Jeśli atakujący przegra, zabierasz mu miedziaki lub 1 kartę ekwipunku." },
  { kind = "special", effect = "vampire", name = "Wampir", color = "yellow", power = 1, count = 3,
    text = "Jeśli atakujący przegra, zabierasz jego utracony punkt zdrowia." },
  -- czarne (7)
  { kind = "black", effect = "mine", name = "Mój ci on", color = "black", count = 2,
    text = "To Ty walczysz z potworem. Inni gracze nie mogą już dorzucać kart. Nie można dodać do zlecenia." },
  { kind = "black", effect = "brawl", name = "Ustawka", color = "black", count = 2,
    text = "Zamiast walki z potworem – walka między graczami. Wybierasz kolor walki. Rzut przeciw rzutowi, bez przerzutów. Wygrany zdobywa 1 punkt sławy i miedziaki przegranego." },
  { kind = "black", effect = "pig_coins", name = "Pazerna świnia", color = "black", count = 2,
    text = "Atakujący przegrywa, ale nie traci życia. Zamiast puli zabierasz przegranemu wszystkie miedziaki." },
  { kind = "black", effect = "pig_fame", name = "Sromotna świnia", color = "black", count = 1,
    text = "Atakujący przegrywa, ale nie traci życia. Zamiast puli zabierasz przegranemu 1 punkt sławy." },
}

-- ------------------------------------------------------------- Targowisko (18)
-- kind: "weapon" (bonus = {kolor=+1}), "potion" (effect)
M.market = {
  { kind = "weapon", name = "Kupa na patyku", bonus = { blue = 1 }, price = 1, flavor = "Przeraża nawet demony!", count = 2 },
  { kind = "weapon", name = "Kołek osikowy", bonus = { blue = 1 }, price = 1, flavor = "Ostry jak brzytwa, pachnie lasem.", count = 1, verified = false },
  { kind = "weapon", name = "Pała", bonus = { red = 1 }, price = 1, flavor = "Solidna pała rozwiązaniem na każdy kłopot!", count = 2 },
  { kind = "weapon", name = "Cep", bonus = { red = 1 }, price = 1, flavor = "Do młócenia zboża i plugastwa.", count = 1, verified = false },
  { kind = "weapon", name = "Kosa", bonus = { green = 1 }, price = 1, flavor = "Po pracy masz ochotę na szybką rebelię? Kosynier już dostępny.", count = 2 },
  { kind = "weapon", name = "Sierp", bonus = { green = 1 }, price = 1, flavor = "Mały, ale zakrzywiony.", count = 1, verified = false },
  { kind = "weapon", name = "Siekiera", bonus = { green = 1 }, price = 1, flavor = "Drwal poleca.", count = 1, verified = false },
  { kind = "weapon", name = "Widły", bonus = { green = 1, red = 1 }, price = 4, flavor = "Chwytaj za widły!", count = 1, verified = false },
  { kind = "weapon", name = "Posrebrzany miecz", bonus = { red = 1, blue = 1 }, price = 4, flavor = "Legendarny miecz cechu kuropatwy.", count = 1 },
  { kind = "potion", effect = "heal", name = "Potjon", price = 2, count = 3, verified = false,
    text = "Przywraca 1 punkt zdrowia. Można zużyć od razu po kupnie. JEDNORAZOWY" },
  { kind = "potion", effect = "extra_die", name = "Dzik", price = 2, count = 1,
    text = "Powiększ swój wynik o dodatkowy rzut kością. Ikona niszczenia karty to automatyczna wygrana. JEDNORAZOWA" },
  { kind = "potion", effect = "any_color", name = "Wilk", price = 2, count = 2,
    text = "W tej walce możesz użyć broni oraz premii wybranego przez Ciebie koloru. JEDNORAZOWA" },
}

-- -------------------------------------------------------------- Gościniec (36)
local function monster(name, color, str, fame, coins, flavor, n, verified)
  return { kind = "monster", name = name, color = color, strength = str, fame = fame, coins = coins,
    flavor = flavor, count = n or 1, verified = verified ~= false }
end
M.road = {
  -- plugawe (czerwone) 8
  monster("Szambiarka", "red", 5, 1, 1, "„Występowanie: stare, zastałe szamba większych aglomeracji”. – Fragment bestiariusza", 2),
  monster("Cmentarny dziad", "red", 4, 1, 1, "Siedzi na cmentarzu i ciumka kości.", 2),
  monster("Praszczur", "red", 6, 1, 2, "„Że niby mój pradziad?”", 1),
  monster("Utopiec", "red", 5, 1, 1, "„Nie chodź chłopu na groblę, bo cię utopiec zje”.", 2),
  monster("Wąpierz", "red", 4, 1, 1, "Nie lubi czosnku ani osiki.", 1, false),
  -- magiczne (niebieskie) 8
  monster("Bebok", "blue", 4, 1, 1, "„Tedy powiedz dziecku – nie zjesz, to cię bebok zeżre!” – Poradnik młodej matuli", 2),
  monster("Wilkołak", "blue", 4, 1, 1, "„Babciu, dlaczego masz takie wielkie zęby? I taki wielki… W nogi! To nie babcia!” – Zakończenie znanej bajki", 1),
  monster("Licho", "blue", 3, 0, 1, "„Wredotą przewyższa koty, krasnale i niewiasty w dniach owych”. – Fragment bestiariusza", 1),
  monster("Czort", "blue", 5, 1, 2, "„Toż mówiłem, że mojego capa piekło pochłonęło”. – Gienek, bamber", 1),
  monster("Nocnica", "blue", 4, 1, 1, "Osikowe okiennice z atestem IP-62 przeciw nocnicom. – Oferta manufaktury Marian Klepka i synowie", 1, false),
  monster("Poczwara", "blue", 6, 1, 1, "„Zachowałem larwę. Pewnie wyrośnie z tego piękny motyl”.", 1),
  monster("Zmora", "blue", 3, 0, 1, "Siada na piersi i dusi po nocach.", 1, false),
  -- leśne (zielone) 8
  monster("Bagiennik", "green", 4, 1, 0, "„…to nie był królewicz zaklęty w ropuchę”. – Zakończenie znanej bajki", 1),
  monster("Arachna", "green", 4, 1, 1, "„Żywi się ssakami leśnymi, nie pogardzi zbłąkanym człowiekiem”. – Fragment bestiariusza", 2),
  monster("Leśny troll", "green", 5, 1, 1, "Co to – duże i śmierdzi?", 2),
  monster("Bies", "green", 6, 1, 1, "„Gienek, to nie krowa! Uciekaj!” – Jadzia, dojarka", 1),
  monster("Borowy", "green", 6, 1, 2, "Pan lasu, nie lubi gości.", 1, false),
  monster("Purchwiel", "green", 3, 0, 2, "„Dej pozór. Jak dupnie, to yno…” – Fragment broszury „Nie baw się padliną”", 1),
  -- wydarzenia 12
  { kind = "event", effect = "fly", name = "Leci mucha", text = "Bzzz…", count = 2 },
  { kind = "event", effect = "healer", name = "Znachor", count = 2,
    text = "Jeśli chcesz, możesz sprzedać kilka narządów. Utracisz 1 punkt zdrowia, ale zyskasz 4 miedziaki. Wydarzenie nie może być wykorzystane, jeśli doprowadziłoby do śmierci postaci." },
  { kind = "event", effect = "lottery", name = "Loteria dożynkowa", count = 2,
    text = "Wygrałeś w wielkiej loterii dożynkowej. Ciągniesz jedną z wierzchu kartę ekwipunku." },
  { kind = "event", effect = "hog", name = "Wieprz!", count = 1,
    text = "Widziano Cię, jak śpisz i jadasz ze świniami. Tracisz 1 pkt sławy. Sława trafia do najsłabszego według Ciebie gracza." },
  { kind = "event", effect = "courage", name = "Gorzoła odwagi", count = 2,
    text = "Wypiłeś ciepły bimber i poczułeś niewysłowiony przypływ odwagi. Ciągnij kolejną kartę. Jeśli to potwór, musisz oznajmić innym graczom, że walczysz." },
  { kind = "event", effect = "guarded_coins", name = "Strzeżone miedziaki", count = 2,
    text = "Połóż kartę na polu walki. Pula za pokonanie najbliższego potwora wzrasta o 2 miedziaki. Ciągniesz kolejną kartę z talii Gościńca. Karta nie może zostać zniszczona przez rzut kością." },
  { kind = "event", effect = "seer", name = "Wiejski Dziad", count = 1, verified = false,
    text = "Spotkałeś Wiejskiego Dziada, który przepowiada Ci przyszłość. Podejrzyj 3 karty Gościńca, jedną odłóż na wierzch, resztę na stos kart odrzuconych." },
}

-- Rozwija definicje (count) do listy pojedynczych kart z unikalnymi id.
function M.buildDeck(defs, prefix)
  local deck, n = {}, 0
  for _, def in ipairs(defs) do
    for _ = 1, (def.count or 1) do
      n = n + 1
      local card = {}
      for k, v in pairs(def) do if k ~= "count" then card[k] = v end end
      card.id = prefix .. n
      card.deck = prefix
      deck[#deck + 1] = card
    end
  end
  return deck
end

function M.isSpecial(card) -- karta, której nie można użyć jako premii dla postaci
  return card.kind ~= "bonus"
end

function M.cardMatchesColor(card, color)
  return card.color == color or card.color == "yellow" or card.color == "black"
end

return M
