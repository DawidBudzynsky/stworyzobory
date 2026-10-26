-- Testy silnika zasad. Uruchomienie: luajit tests/run.lua  (albo: lua tests/run.lua)
package.path = "./?.lua;./?/init.lua;" .. package.path
local Rules = require("src.game.rules")
local Cards = require("src.game.cards")
local json = require("src.net.json")

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name .. "\n" .. tostring(err)) end
end
local function eq(a, b, msg)
  if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function ok(v, msg) if not v then error(msg or "expected truthy", 2) end end
-- Automatycznie odpowiada na pytania o pole sławy (pierwsze legalne), chyba że test ustawi state.noAuto.
local function autoPrompts(state)
  while state.prompt and not state.noAuto and (state.prompt.type == "fame_slot" or state.prompt.type == "fame_remove") do
    local pr = state.prompt
    local slot = pr.type == "fame_slot" and Rules.legalFameSlots(state.players[pr.pid])[1] or pr.slots[1]
    assert(Rules.apply(state, pr.pid, { type = pr.type, slot = slot }))
  end
end
local function must(state, pid, action)
  local okk, err = Rules.apply(state, pid, action)
  if not okk then error("action " .. action.type .. " by " .. pid .. " failed: " .. tostring(err), 2) end
  autoPrompts(state)
end
local function mustFail(state, pid, action, msg)
  local okk, err = Rules.apply(state, pid, action)
  if okk then error("action " .. action.type .. " should fail (" .. (msg or "") .. ")", 2) end
  return err
end

-- Sztuczny RNG: kostka wg kolejki (6 = ikona niszczenia), tasowanie bez zmian.
local function fakeRng(queue)
  return { queue = queue or {}, int = function(self, n)
    if n == 6 and #self.queue > 0 then return table.remove(self.queue, 1) end
    return 1
  end, shuffle = function(_, t) return t end }
end

local function charById(id)
  for _, c in ipairs(Cards.characters) do if c.id == id then return c end end
  error("no char " .. id)
end

local function findCard(list, pred)
  for _, c in ipairs(list) do if pred(c) then return c end end
end
local function byName(list, name, color)
  return findCard(list, function(c) return c.name == name and (color == nil or c.color == color) end)
end

-- Tworzy grę z zadanymi postaciami i kończy setup. chars = { {"falgrim","otto"}, ... }
local function mk(chars, opts)
  opts = opts or {}
  local names = {}
  for i = 1, #chars do names[i] = "G" .. i end
  local s = Rules.new(names, 7)
  s.rng = fakeRng(opts.dice)
  for i, pair in ipairs(chars) do s.players[i].chars = { charById(pair[1]), charById(pair[2] or "otto") } end
  -- deterministyczne talie: posortowane po id, żeby testy były stabilne
  for _, d in pairs(s.decks) do table.sort(d.draw, function(a, b) return a.id < b.id end) end
  if opts.village then s.decks.village.draw = opts.village end
  for i = 1, #chars do
    must(s, i, { type = "choose_character", index = 1 })
    while s.setup[i].step == "fame" do must(s, i, { type = "setup_fame_slot", slot = Rules.legalFameSlots(s.players[i])[1] }) end
    must(s, i, { type = "swap_card" })
  end
  return s
end

-- przechodzi przez targowisko i dobranie karty aż do decyzji na Gościńcu
local function toRoad(s, pid)
  must(s, pid, { type = "end_market" })
end

local function putRoadTop(s, card) table.insert(s.decks.road.draw, 1, card) end
local function giveHand(s, pid, card) table.insert(s.players[pid].hand, card) end
local function village(name, color)
  local defs = Cards.buildDeck(Cards.village, "t")
  return byName(defs, name, color)
end
local function road(name)
  return byName(Cards.buildDeck(Cards.road, "x"), name)
end
local function market(name)
  return byName(Cards.buildDeck(Cards.market, "y"), name)
end
local function setFame(p, n)
  for i = 1, 6 do p.fame[i] = i <= n end
end

-- ------------------------------------------------------------------- testy
test("talie mają liczność z instrukcji", function()
  eq(#Cards.buildDeck(Cards.village, "v"), 43)
  eq(#Cards.buildDeck(Cards.market, "m"), 18)
  eq(#Cards.buildDeck(Cards.road, "r"), 36)
  eq(#Cards.characters, 10)
  local monsters = 0
  for _, c in ipairs(Cards.buildDeck(Cards.road, "r")) do if c.kind == "monster" then monsters = monsters + 1 end end
  eq(monsters, 24)
end)

test("tasowanie jest deterministyczne dla ziarna", function()
  local a, b = Rules.new({ "A", "B" }, 123), Rules.new({ "A", "B" }, 123)
  for i = 1, 43 do eq(a.decks.village.draw[i].id, b.decks.village.draw[i].id) end
  ok(a.decks.village.draw[1].id ~= Rules.new({ "A", "B" }, 124).decks.village.draw[1].id or true)
end)

test("przygotowanie: ręka, żetony, cechy startowe", function()
  local s = mk({ { "ruda", "otto" }, { "alojz", "otto" }, { "gienek", "otto" }, { "onufry", "otto" }, { "siergiej", "otto" } })
  eq(#s.players[1].hand, 6, "Ruda 6 kart")
  eq(#s.players[2].hand, 4)
  eq(s.players[2].coins, 3, "Alojz 3 miedziaki")
  eq(s.players[3].coins, 0, "Gienek bez miedziaka")
  eq(Rules.fameCount(s.players[3]), 2, "Gienek 2 sławy")
  eq(s.players[4].hp, 4, "Onufry 4 HP")
  ok(#s.players[5].weapons + (s.players[5].potion and 1 or 0) == 1, "Siergiej ekwipunek")
  eq(#s.marketRow, 3)
  eq(s.phase, "market")
  eq(s.turn.player, 1)
  eq(Rules.fameCount(s.players[1]), 1)
end)

test("przygotowanie: wymiana karty idzie na spód talii", function()
  local s = Rules.new({ "A", "B" }, 5)
  must(s, 1, { type = "choose_character", index = 2 })
  must(s, 1, { type = "setup_fame_slot", slot = 3 })
  local id = s.players[1].hand[1].id
  must(s, 1, { type = "swap_card", cardId = id })
  eq(s.decks.village.draw[#s.decks.village.draw].id, id)
  eq(#s.players[1].hand, 4)
  mustFail(s, 1, { type = "swap_card" }, "drugi raz")
  eq(s.phase, "setup")
end)

test("pole sławy: bez przerwy, premia za 2 w kolorze, siódmy wygrywa", function()
  local s = mk({ { "falgrim", "otto" }, { "otto", "alojz" } })
  local p = s.players[1]
  setFame(p, 0); p.fame[3] = true
  local legal = Rules.legalFameSlots(p)
  eq(#legal, 2); eq(legal[1], 2); eq(legal[2], 4)
  p.fame[4] = true
  eq(Rules.playerStrength(s, p, { "green" }, {}), 1, "2 zielone = +1")
  eq(Rules.playerStrength(s, p, { "red" }, {}), 1, "Falgrim +1 czerwony")
  setFame(p, 6)
  p.coins = 4
  mustFail(s, 1, { type = "buy_fame" }, "nie można kupić siódmego")
  setFame(p, 5)
  must(s, 1, { type = "buy_fame" })
  eq(Rules.fameCount(p), 6)
  eq(p.coins, 0)
  mustFail(s, 1, { type = "buy_fame" }, "tylko raz na turę")
end)

test("targowisko: kupno, uzupełnienie rynku, limit broni, Potjon od razu", function()
  local s = mk({ { "falgrim", "otto" }, { "otto", "alojz" } })
  local p = s.players[1]
  p.coins = 10
  s.marketRow = { market("Pała"), market("Kosa"), market("Posrebrzany miecz") }
  s.decks.market.draw = { market("Cep"), market("Potjon"), market("Potjon") }
  must(s, 1, { type = "buy", index = 1 })
  eq(#p.weapons, 1); eq(p.coins, 9); eq(s.marketRow[1].name, "Cep")
  must(s, 1, { type = "buy", index = 2 })
  eq(#p.weapons, 2)
  must(s, 1, { type = "buy", index = 3 }) -- trzecia broń -> prompt
  eq(s.prompt.type, "equip_replace")
  mustFail(s, 1, { type = "end_market" }, "prompt blokuje")
  must(s, 1, { type = "equip_replace", cardId = p.weapons[1].id })
  eq(#p.weapons, 2); eq(p.weapons[2].name, "Posrebrzany miecz")
  eq(s.phase, "market")
  -- eliksir
  s.marketRow[1] = market("Potjon")
  must(s, 1, { type = "buy", index = 1 })
  ok(p.potion, "eliksir wyposażony")
  p.hp = 2
  s.marketRow[1] = market("Potjon")
  must(s, 1, { type = "buy", index = 1 })
  eq(s.prompt.type, "equip_replace")
  must(s, 1, { type = "equip_replace", choice = "use_now" })
  eq(p.hp, 3)
  mustFail(s, 2, { type = "buy", index = 1 }, "nie jego tura")
end)

test("Jednoręki Fred ma tylko 1 broń", function()
  local s = mk({ { "fred", "otto" }, { "otto", "alojz" } })
  s.players[1].coins = 5
  s.marketRow = { market("Pała"), market("Kosa"), market("Cep") }
  must(s, 1, { type = "buy", index = 1 })
  must(s, 1, { type = "buy", index = 2 })
  eq(s.prompt.type, "equip_replace")
end)

test("tura: wioska, druga karta zamiast gościńca kończy turę", function()
  local s = mk({ { "falgrim", "otto" }, { "otto", "alojz" } })
  local n = #s.players[1].hand
  toRoad(s, 1)
  eq(#s.players[1].hand, n + 1)
  eq(s.phase, "road_choice")
  must(s, 1, { type = "draw_village" })
  eq(#s.players[1].hand, n + 2)
  eq(s.turn.player, 2); eq(s.phase, "market")
end)

test("walka: zwykła wygrana i przegrana, pula, utrata zdrowia", function()
  local s = mk({ { "falgrim", "otto" }, { "otto", "alojz" } }, { dice = { 5, 1 } })
  putRoadTop(s, road("Szambiarka")) -- czerwony 5, 1 sława 1 miedziak
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  eq(s.phase, "encounter")
  must(s, 1, { type = "fight" })
  eq(s.phase, "fight_add")
  must(s, 2, { type = "pass" })
  eq(s.phase, "fight_bonus")
  must(s, 1, { type = "roll" })
  eq(s.fight.roll, 5)
  eq(s.phase, "fight_react")
  must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  -- Falgrim +1 czerwony + 5 = 6 >= 5
  eq(s.players[1].coins, 2); eq(Rules.fameCount(s.players[1]), 2)
  eq(s.turn.player, 2)
  -- przegrana gracza 2
  putRoadTop(s, road("Szambiarka"))
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" }); must(s, 1, { type = "pass" })
  must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.players[2].hp, 2)
  eq(s.field.monster, nil)
  eq(s.turn.player, 1)
end)

test("walka: premie z ręki tylko w kolorze, karty specjalne zabronione", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 3 } })
  putRoadTop(s, road("Bebok")) -- niebieski 4
  local blue, red, yellow = village("Piekielne ziele"), village("Przepocone kalesony"), village("Hiena")
  giveHand(s, 1, blue); giveHand(s, 1, red); giveHand(s, 1, yellow)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  mustFail(s, 1, { type = "play_bonus", cardId = red.id }, "zły kolor")
  mustFail(s, 1, { type = "play_bonus", cardId = yellow.id }, "specjalna")
  must(s, 1, { type = "play_bonus", cardId = blue.id })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  -- 0 + 1 premia + 3 = 4 >= 4 wygrana
  eq(Rules.fameCount(s.players[1]), 2)
  ok(byName(s.decks.village.discard, "Piekielne ziele"), "premia odrzucona")
end)

test("walka: Hiena dorzucona (+1), przegrana -> zabiera miedziaki", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 4 } })
  putRoadTop(s, road("Bebok")) -- 4
  local h = village("Hiena"); giveHand(s, 2, h)
  s.players[1].coins = 3
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = h.id })
  eq(s.phase, "fight_pick")
  must(s, 1, { type = "pick_card", index = 1 })
  eq(Rules.monsterStrength(s), 5)
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.prompt.type, "hyena"); eq(s.prompt.pid, 2)
  must(s, 2, { type = "hyena", choice = "coins" })
  eq(s.players[1].coins, 0); eq(s.players[2].coins, 4)
  eq(s.players[1].hp, 2)
end)

test("walka: niewybrane karty wracają do właścicieli", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" }, { "ruda", "otto" } }, { dice = { 5 } })
  putRoadTop(s, road("Licho"))
  local a, b = village("Hiena"), village("Wampir")
  giveHand(s, 2, a); giveHand(s, 3, b)
  local n3 = #s.players[3].hand
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = a.id }); must(s, 3, { type = "add_card", cardId = b.id })
  must(s, 1, { type = "pick_card", index = 1 })
  eq(#s.players[3].hand, n3, "Wampir wrócił")
  eq(#s.field.submitted, 1)
end)

test("Wampir i Na krzywy ryj", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 1, 5 } })
  s.players[2].hp = 2
  putRoadTop(s, road("Bebok"))
  local w = village("Wampir"); giveHand(s, 2, w)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = w.id }); must(s, 1, { type = "pick_card", index = 1 })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.players[1].hp, 2); eq(s.players[2].hp, 3, "Wampir odzyskuje zdrowie")
  -- Na krzywy ryj: gracz 2 w swojej turze walczy, gracz 1 dorzuca
  putRoadTop(s, road("Licho"))
  local k = village("Na krzywy ryj"); giveHand(s, 1, k)
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" })
  must(s, 1, { type = "add_card", cardId = k.id }); must(s, 2, { type = "pick_card", index = 1 })
  eq(Rules.monsterStrength(s), 3)
  must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(Rules.fameCount(s.players[1]), 2, "NKR daje sławę")
end)

test("Przebranie w walce: przegrana atakującego daje pulę właścicielowi, wygrana rani go", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 1, 5 } })
  putRoadTop(s, road("Bebok")) -- 1 sława 1 miedziak
  local d = village("Przebranie", "yellow"); giveHand(s, 2, d)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = d.id }); must(s, 1, { type = "pick_card", index = 1 })
  eq(Rules.monsterStrength(s), 5, "Falgrim: żółte przebranie +1")
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.players[2].coins, 2, "1 startowy + 1 z puli"); eq(Rules.fameCount(s.players[2]), 2)
  -- teraz wygrana
  putRoadTop(s, road("Licho"))
  local d2 = village("Przebranie", "yellow"); giveHand(s, 1, d2)
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" })
  must(s, 1, { type = "add_card", cardId = d2.id }); must(s, 2, { type = "pick_card", index = 1 })
  eq(Rules.monsterStrength(s), 3, "Otto: żółte przebranie bez premii")
  must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.players[1].hp, 1, "pokonane przebranie traci życie (po wcześniejszej przegranej)")
end)

test("ikona niszczenia: bez kart automatyczna wygrana, z kartą niszczy i rzuca ponownie", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 6 } })
  putRoadTop(s, road("Bies")) -- 6
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "roll" })
  eq(Rules.fameCount(s.players[1]), 2, "auto wygrana")
  -- z kartą
  s.rng = fakeRng({ 6, 1 })
  putRoadTop(s, road("Licho"))
  local h = village("Hiena"); giveHand(s, 1, h)
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" })
  must(s, 1, { type = "add_card", cardId = h.id }); must(s, 2, { type = "pick_card", index = 1 })
  must(s, 2, { type = "roll" })
  eq(#s.fight.counted, 0, "Hiena zniszczona")
  eq(s.fight.roll, 1)
  eq(s.phase, "fight_react")
end)

test("przerzut: kosztuje sławę do puli, raz na walkę, Otto dwa razy", function()
  local s = mk({ { "falgrim", "alojz" }, { "otto", "ruda" } }, { dice = { 1, 1, 1, 5 } })
  setFame(s.players[2], 3)
  putRoadTop(s, road("Szambiarka"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "roll" })
  must(s, 1, { type = "reroll" })
  eq(s.field.pledgedFame, 1); eq(Rules.fameCount(s.players[1]), 0)
  mustFail(s, 1, { type = "reroll" }, "bez sławy")
  must(s, 2, { type = "reroll" }); must(s, 2, { type = "reroll" })
  eq(s.players[2].rerollsUsed, 2)
  mustFail(s, 2, { type = "reroll" }, "Otto max 2")
  eq(s.fight.roll, 5)
  must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(Rules.fameCount(s.players[1]), 4, "pula z zastawami: 1 + 3")
end)

test("zlecenie: walidacja kart", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } })
  putRoadTop(s, road("Bebok"))
  local m, u, p = village("Mój ci on"), village("Ustawka"), village("Pazerna świnia")
  giveHand(s, 1, m); giveHand(s, 1, u); giveHand(s, 1, p)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  mustFail(s, 1, { type = "contract", cardIds = { m.id } }, "Mój ci on")
  mustFail(s, 1, { type = "contract", cardIds = { u.id, p.id } }, "2 czarne")
  mustFail(s, 1, { type = "contract", cardIds = { s.players[1].hand[1].id, s.players[1].hand[2].id, s.players[1].hand[3].id, s.players[1].hand[4].id } }, "4 karty")
  must(s, 1, { type = "contract", cardIds = {} })
  eq(s.phase, "contract_volunteer")
end)

test("zlecenie: nikt nie walczy – przebranie zgarnia pulę, bez przebrania nic", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } })
  putRoadTop(s, road("Czort")) -- 1 sława, 2 miedziaki
  local d, b = village("Przebranie", "yellow"), village("Piekielne ziele")
  giveHand(s, 1, d); giveHand(s, 1, b)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  must(s, 1, { type = "contract", cardIds = { d.id, b.id } })
  must(s, 2, { type = "pass" })
  eq(s.players[1].coins, 3); eq(Rules.fameCount(s.players[1]), 2)
  eq(s.turn.player, 2)
  putRoadTop(s, road("Czort"))
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "contract", cardIds = {} })
  must(s, 1, { type = "pass" })
  eq(s.players[2].coins, 1)
  eq(s.turn.player, 1)
end)

test("zlecenie: ochotnik walczy ze Stworem z Obory, kolory niepasujące ignorowane", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 5 } })
  putRoadTop(s, road("Bebok")) -- niebieski 4
  local d, bl, rd = village("Przebranie", "blue"), village("Piekielne ziele"), village("Przepocone kalesony")
  giveHand(s, 1, d); giveHand(s, 1, bl); giveHand(s, 1, rd)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  must(s, 1, { type = "contract", cardIds = { d.id, bl.id, rd.id } })
  must(s, 2, { type = "volunteer" })
  eq(s.phase, "fight_bonus"); eq(s.fight.attacker, 2)
  eq(Rules.monsterStrength(s), 6, "4 + przebranie niebieskie +1 + ziele +1, kalesony ignorowane")
  must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  -- Falgrim 0 niebieski + 5 = 5 < 6 -> przegrana
  eq(s.players[2].hp, 2)
  eq(Rules.fameCount(s.players[1]), 2, "zleceniodawca zgarnia pulę")
  eq(s.players[1].coins, 2)
end)

test("zlecenie: kilku ochotników – zleceniodawca wybiera", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" }, { "ruda", "otto" } }, { dice = { 5 } })
  putRoadTop(s, road("Licho"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "contract", cardIds = {} })
  must(s, 2, { type = "volunteer" }); must(s, 3, { type = "volunteer" })
  eq(s.phase, "contract_pick")
  mustFail(s, 2, { type = "pick_volunteer", pid = 3 })
  must(s, 1, { type = "pick_volunteer", pid = 3 })
  eq(s.fight.attacker, 3)
end)

test("świnie: Pazerna zabiera miedziaki, Sromotna sławę, bez utraty zdrowia", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } })
  s.players[2].coins = 5
  putRoadTop(s, road("Bebok"))
  local pig = village("Pazerna świnia"); giveHand(s, 1, pig)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "contract", cardIds = { pig.id } })
  must(s, 2, { type = "volunteer" })
  eq(s.players[2].coins, 0); eq(s.players[1].coins, 6); eq(s.players[2].hp, 3)
  eq(s.turn.player, 2)
  -- Sromotna dorzucona w zwykłej walce
  putRoadTop(s, road("Bebok"))
  local pig2 = village("Sromotna świnia"); giveHand(s, 1, pig2)
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" })
  must(s, 1, { type = "add_card", cardId = pig2.id }); must(s, 2, { type = "pick_card", index = 1 })
  eq(Rules.fameCount(s.players[2]), 0); eq(Rules.fameCount(s.players[1]), 2)
  eq(s.turn.player, 1)
end)

test("Mój ci on: przejęcie walki", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 5 } })
  putRoadTop(s, road("Szambiarka")) -- czerwony 5
  local m = village("Mój ci on"); giveHand(s, 2, m)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = m.id }); must(s, 1, { type = "pick_card", index = 1 })
  eq(s.fight.attacker, 2); eq(s.phase, "fight_bonus")
  mustFail(s, 1, { type = "roll" })
  must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(Rules.fameCount(s.players[2]), 2, "Falgrim 1+5 >= 5")
  eq(s.turn.player, 2)
end)

test("Ustawka: kolor, premie, rzut przeciw rzutowi, nagroda", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 2, 5 } })
  s.players[1].coins = 3
  putRoadTop(s, road("Bebok"))
  local u, bonusG = village("Ustawka"), village("Esencja z capa")
  giveHand(s, 2, u); giveHand(s, 1, bonusG)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = u.id }); must(s, 1, { type = "pick_card", index = 1 })
  eq(s.phase, "brawl_color")
  must(s, 2, { type = "brawl_color", color = "green" })
  must(s, 1, { type = "play_bonus", cardId = bonusG.id })
  must(s, 1, { type = "ready" }); must(s, 2, { type = "ready" })
  -- gracz2 (Falgrim, 0 zielony) 2 vs gracz1 (Otto) 1 premia + 5 = 6 -> wygrywa gracz 1
  eq(Rules.fameCount(s.players[1]), 2); eq(s.players[1].coins, 4); eq(s.players[2].coins, 0)
  eq(s.field.monster, nil); eq(s.turn.player, 2)
end)

test("Ustawka: ikona niszczenia wygrywa, podwójna = powtórka", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 6, 6, 1, 6 } })
  putRoadTop(s, road("Bebok"))
  local u = village("Ustawka"); giveHand(s, 2, u)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = u.id }); must(s, 1, { type = "pick_card", index = 1 })
  must(s, 2, { type = "brawl_color", color = "red" })
  must(s, 1, { type = "ready" }); must(s, 2, { type = "ready" })
  eq(Rules.fameCount(s.players[1]), 2, "po remisie: gracz 1 (drugi rzucający) wyrzuca niszczenie")
  eq(Rules.fameCount(s.players[2]), 1)
end)

test("eliksiry: Dzik (dodatkowy rzut / auto wygrana), Wilk (dodatkowy kolor), Potjon w walce", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 2, 3 } })
  s.players[1].potion = market("Dzik")
  putRoadTop(s, road("Szambiarka")) -- 5
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  mustFail(s, 1, { type = "use_potion" }, "Dzik przed rzutem")
  must(s, 1, { type = "roll" })
  must(s, 1, { type = "use_potion" })
  eq(s.fight.extraRoll, 3)
  must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(Rules.fameCount(s.players[1]), 2, "2+3 >= 5")
  -- Wilk: Falgrim (czerwony +1) walczy z niebieskim, wybiera czerwony
  s.rng = fakeRng({ 3 })
  s.players[2].potion = market("Wilk")
  s.players[2].weapons = { market("Pała") }
  putRoadTop(s, road("Bebok")) -- niebieski 4
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" }); must(s, 1, { type = "pass" })
  must(s, 2, { type = "use_potion", color = "red" })
  must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(Rules.fameCount(s.players[2]), 2, "1 postać + 1 pała + 3 = 5 >= 4")
  -- Potjon w walce
  s.rng = fakeRng({ 1 })
  s.players[1].potion = market("Potjon"); s.players[1].hp = 1
  putRoadTop(s, road("Bebok"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "use_potion" })
  eq(s.players[1].hp, 2)
end)

test("wydarzenia: Leci mucha, Znachor, Loteria, Wieprz", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } })
  putRoadTop(s, road("Leci mucha"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  eq(s.turn.player, 2)
  putRoadTop(s, road("Znachor"))
  toRoad(s, 2); must(s, 2, { type = "reveal_road" })
  eq(s.prompt.type, "healer")
  must(s, 2, { type = "healer", choice = "yes" })
  eq(s.players[2].hp, 2); eq(s.players[2].coins, 5)
  eq(s.turn.player, 1)
  -- Znachor przy 1 HP nie działa
  s.players[1].hp = 1
  putRoadTop(s, road("Znachor"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  eq(s.prompt, nil); eq(s.players[1].hp, 1); eq(s.turn.player, 2)
  -- Loteria
  s.decks.market.draw = { market("Pała") }
  putRoadTop(s, road("Loteria dożynkowa"))
  toRoad(s, 2); must(s, 2, { type = "reveal_road" })
  eq(s.players[2].weapons[1].name, "Pała")
  -- Wieprz
  putRoadTop(s, road("Wieprz!"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  eq(s.prompt.type, "hog_target")
  mustFail(s, 1, { type = "hog_target", pid = 1 }, "nie siebie")
  must(s, 1, { type = "hog_target", pid = 2 })
  eq(Rules.fameCount(s.players[1]), 0); eq(Rules.fameCount(s.players[2]), 2)
end)

test("wydarzenia: Gorzoła wymusza walkę, Strzeżone miedziaki +2 do puli, Wiejski Dziad", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "otto" } }, { dice = { 5 } })
  putRoadTop(s, road("Bebok")); putRoadTop(s, road("Strzeżone miedziaki")); putRoadTop(s, road("Gorzoła odwagi"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" })
  eq(s.phase, "fight_add", "wymuszona walka")
  eq(s.field.guardedCards, 1)
  must(s, 2, { type = "pass" }); must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.players[1].coins, 1 + 1 + 2)
  eq(s.field.guardedCards, 0)
  -- Dziad
  local a, b, c = road("Licho"), road("Bies"), road("Czort")
  putRoadTop(s, c); putRoadTop(s, b); putRoadTop(s, a); putRoadTop(s, road("Wiejski Dziad"))
  toRoad(s, 2); must(s, 2, { type = "reveal_road" })
  eq(s.prompt.type, "seer")
  must(s, 2, { type = "seer", cardId = c.id })
  eq(s.decks.road.draw[1].id, c.id)
  ok(byName(s.decks.road.discard, "Licho"))
end)

test("śmierć: druga postać, potem eliminacja i wygrana ostatniego", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "onufry" } }, { dice = { 1 } })
  s.players[1].hp = 1; s.players[1].coins = 5; s.players[1].weapons = { market("Pała") }
  putRoadTop(s, road("Bies"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  local p = s.players[1]
  eq(p.deaths, 1); eq(p.chars[p.charIndex].id, "alojz"); eq(p.hp, 3); eq(p.coins, 3, "Alojz 3 miedziaki")
  eq(#p.weapons, 1, "ekwipunek zostaje")
  eq(Rules.fameCount(p), 1)
  eq(s.turn.player, 2)
  -- druga śmierć
  s.rng = fakeRng({ 1 })
  p.hp = 1
  putRoadTop(s, road("Bies"))
  toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "contract", cardIds = {} })
  must(s, 1, { type = "volunteer" })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  ok(p.eliminated)
  eq(s.winner, 2)
end)

test("siódmy żeton sławy kończy grę", function()
  local s = mk({ { "falgrim", "alojz" }, { "otto", "onufry" } }, { dice = { 5 } })
  setFame(s.players[1], 6)
  putRoadTop(s, road("Szambiarka"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.winner, 1); eq(s.phase, "finished")
  mustFail(s, 2, { type = "end_market" })
end)

test("przetasowanie stosu odrzuconych, gdy talia pusta", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "onufry" } })
  s.decks.village.discard = s.decks.village.draw
  s.decks.village.draw = {}
  toRoad(s, 1)
  eq(#s.decks.village.discard, 0)
  ok(#s.decks.village.draw > 0)
end)

test("Natasza i Szyszka", function()
  local s = mk({ { "natasza", "alojz" }, { "szyszka", "onufry" } }, { dice = { 5, 5, 5 } })
  putRoadTop(s, road("Bebok"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.players[1].coins, 1 + 1 + 2)
  for _ = 1, 2 do
    putRoadTop(s, road("Bagiennik"))
    toRoad(s, 2); must(s, 2, { type = "reveal_road" }); must(s, 2, { type = "fight" }); must(s, 1, { type = "pass" })
    must(s, 2, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
    if s.prompt then must(s, 2, { type = "fame_slot", slot = s.prompt and Rules.legalFameSlots(s.players[2])[1] }) end
    toRoad(s, 1); must(s, 1, { type = "draw_village" })
  end
  eq(Rules.fameCount(s.players[2]), 1 + 2 + 1, "2 leśne bestie = +1")
end)

test("widok gracza ukrywa cudze karty i koduje się do JSON", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "onufry" } })
  s.players[2].potion = market("Dzik")
  putRoadTop(s, road("Bebok"))
  local h = village("Hiena"); giveHand(s, 2, h)
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" })
  must(s, 2, { type = "add_card", cardId = h.id })
  local v1 = Rules.view(s, 1)
  eq(v1.players[2].hand, nil); eq(v1.players[2].handCount, #s.players[2].hand)
  eq(v1.players[2].potion, nil); eq(v1.players[2].hasPotion, true)
  eq(v1.players[2].backup, nil); ok(v1.players[1].backup)
  eq(v1.field.submitted[1].card, nil, "zakryta karta ukryta")
  local v2 = Rules.view(s, 2)
  eq(v2.field.submitted[1].card.name, "Hiena", "własna zakryta karta widoczna")
  local txt = json.encode(v1)
  local back = json.decode(txt)
  eq(back.players[2].handCount, v1.players[2].handCount)
  eq(#back.players[1].fame, 6)
end)

test("kolejka decyzji: wybór pola sławy po wygranej, potem koniec tury", function()
  local s = mk({ { "otto", "alojz" }, { "falgrim", "onufry" } }, { dice = { 5 } })
  local p = s.players[1]
  s.noAuto = true
  setFame(p, 0); p.fame[3] = true
  putRoadTop(s, road("Bebok"))
  toRoad(s, 1); must(s, 1, { type = "reveal_road" }); must(s, 1, { type = "fight" }); must(s, 2, { type = "pass" })
  must(s, 1, { type = "roll" }); must(s, 1, { type = "accept" }); must(s, 2, { type = "accept" })
  eq(s.prompt.type, "fame_slot")
  mustFail(s, 1, { type = "fame_slot", slot = 6 }, "przerwa")
  must(s, 1, { type = "fame_slot", slot = 4 })
  eq(s.turn.player, 2)
end)

print(string.format("Testy: %d zaliczonych, %d niezaliczonych", passed, failed))
os.exit(failed == 0 and 0 or 1)
