-- Silnik zasad „Stwory z obory”. Czysta logika: brak zależności od LÖVE.
-- Stan jest zwykłą tabelą (serializowalną do JSON), zmieniany wyłącznie przez Rules.apply.
-- Numeracja faz i podfaz („prompt”) opisana w docs/rules-spec.md.
local Cards = require("src.game.cards")
local Rng = require("src.game.rng")

local Rules = {}
local unpack = unpack or table.unpack

local DIE = { 1, 2, 3, 4, 5, "destroy" }

-- ---------------------------------------------------------------- narzędzia
local function log(state, text) state.log[#state.log + 1] = text end
local function event(state, ev) state.events[#state.events + 1] = ev end

local function findIndex(list, pred)
  for i, v in ipairs(list) do if pred(v) then return i end end
end

local function removeById(list, id)
  local i = findIndex(list, function(c) return c.id == id end)
  if i then return table.remove(list, i) end
end

local function alive(state)
  local t = {}
  for _, p in ipairs(state.players) do if not p.eliminated then t[#t + 1] = p end end
  return t
end

local function char(p) return p.chars[p.charIndex] end

local function fameCount(p)
  local n = 0
  for i = 1, 6 do if p.fame[i] then n = n + 1 end end
  return n
end
Rules.fameCount = fameCount

-- pola sławy, na które można położyć nowy żeton (bez przerwy w ciągu)
local function legalFameSlots(p)
  local n = fameCount(p)
  local out = {}
  for i = 1, 6 do
    if not p.fame[i] then
      local prev, nxt = (i - 2) % 6 + 1, i % 6 + 1
      if n == 0 or p.fame[prev] or p.fame[nxt] then out[#out + 1] = i end
    end
  end
  return out
end
Rules.legalFameSlots = legalFameSlots

-- końce ciągu żetonów sławy (pola, które można zdjąć bez robienia przerwy)
local function fameArcEnds(p)
  local n = fameCount(p)
  if n == 0 then return {} end
  if n == 6 then return { 1, 2, 3, 4, 5, 6 } end
  local start
  for i = 1, 6 do
    local prev = (i - 2) % 6 + 1
    if p.fame[i] and not p.fame[prev] then start = i end
  end
  local last = start
  for k = 1, n - 1 do last = (start + k - 1) % 6 + 1 end
  if start == last then return { start } end
  return { start, last }
end
Rules.fameArcEnds = fameArcEnds

-- premia +1 za 2 punkty sławy w kolorze
local function fameColorBonus(p, color)
  for i = 1, 6, 2 do
    if Cards.FAME_RING[i] == color and p.fame[i] and p.fame[i + 1] then return 1 end
  end
  return 0
end

local function characterBonus(p, color)
  return (char(p).bonus[color] or 0) + fameColorBonus(p, color)
end

local function weaponBonus(p, color)
  local s = 0
  for _, w in ipairs(p.weapons) do s = s + (w.bonus[color] or 0) end
  return s
end

local function playerStrength(state, p, colors, bonusCards)
  local s = 0
  for _, color in ipairs(colors) do
    s = s + characterBonus(p, color) + weaponBonus(p, color)
    for _, c in ipairs(bonusCards or {}) do
      if c.color == color then s = s + (c.power or 0) end
    end
  end
  return s
end
Rules.playerStrength = playerStrength

local function colorsFor(fight)
  local t = { fight.color }
  if fight.extraColor and fight.extraColor ~= fight.color then t[#t + 1] = fight.extraColor end
  return t
end

-- siła karty dodanej do potwora
local function fieldCardPower(state, entry, monsterColor)
  local c = entry.card
  if c.kind == "black" then return 0 end
  if c.color == "yellow" then
    if c.kind == "disguise" and char(state.players[entry.owner]).trait == "yellow_disguise_bonus" then return 1 end
    return c.power or 0
  end
  if c.color == monsterColor then return c.power or 0 end
  return 0
end

local function monsterStrength(state)
  local f = state.fight
  local s = state.field.monster.strength
  for _, e in ipairs(f.counted) do s = s + fieldCardPower(state, e, f.color) end
  return s
end
Rules.monsterStrength = monsterStrength

local function maxWeapons(p)
  return char(p).trait == "one_weapon" and 1 or Cards.MAX_WEAPONS
end

local function rerollLimit(p)
  return char(p).trait == "reroll2" and 2 or 1
end

-- ----------------------------------------------------------------- talie
local function draw(state, deckName)
  local d = state.decks[deckName]
  if #d.draw == 0 then
    if #d.discard == 0 then return nil end
    d.draw, d.discard = d.discard, {}
    state.rng:shuffle(d.draw)
    log(state, "Przetasowano stos odrzuconych talii " .. deckName .. ".")
  end
  return table.remove(d.draw, 1)
end

local function discard(state, deckName, card)
  if card then table.insert(state.decks[deckName].discard, card) end
end

local function refillMarket(state)
  for i = 1, 3 do
    if not state.marketRow[i] then
      local c = draw(state, "market")
      if c then state.marketRow[i] = c end
    end
  end
end

-- --------------------------------------------------------------- prompty
-- Prompt = pytanie do jednego gracza przerywające główny przebieg (wybór pola sławy itd.)
local function pushPrompt(state, prompt)
  if state.winner then return end
  state.prompts[#state.prompts + 1] = prompt
end

local continueFlow, nextPrompt -- forward

-- ------------------------------------------------------------ sława/zdrowie
local function setWinner(state, pid)
  state.winner = pid
  state.phase = "finished"
  state.prompt, state.prompts = nil, {}
  log(state, state.players[pid].name .. " zdobywa siódmy żeton sławy i zostaje Królem Pogromców Potworów!")
  event(state, { type = "winner", pid = pid })
end

local function placeFame(state, pid, slot)
  local p = state.players[pid]
  p.fame[slot] = true
  event(state, { type = "fame", pid = pid, delta = 1, slot = slot })
end

-- Dodaje n punktów sławy. Jeśli jest wybór pola, tworzy prompt.
local function gainFame(state, pid, n, reason)
  local p = state.players[pid]
  for _ = 1, n do
    if state.winner then return end
    if fameCount(p) >= 6 then
      log(state, p.name .. " zdobywa punkt sławy (" .. reason .. ").")
      setWinner(state, pid)
      return
    end
    local legal = legalFameSlots(p)
    log(state, p.name .. " zdobywa punkt sławy (" .. reason .. ").")
    if #legal == 1 then
      placeFame(state, pid, legal[1])
    else
      pushPrompt(state, { type = "fame_slot", pid = pid })
    end
  end
end

local function removeFame(state, pid, slot, reason)
  local p = state.players[pid]
  p.fame[slot] = false
  log(state, p.name .. " traci punkt sławy (" .. reason .. ").")
  event(state, { type = "fame", pid = pid, delta = -1, slot = slot })
end

-- Odejmuje 1 punkt sławy (z końca ciągu); przy niejednoznaczności tworzy prompt.
local function loseFame(state, pid, reason)
  local p = state.players[pid]
  local ends = fameArcEnds(p)
  if #ends == 0 then return false end
  if #ends == 1 then
    removeFame(state, pid, ends[1], reason)
  elseif #ends == 2 and Cards.FAME_RING[ends[1]] == Cards.FAME_RING[ends[2]] then
    removeFame(state, pid, ends[2], reason)
  else
    pushPrompt(state, { type = "fame_remove", pid = pid, reason = reason, slots = ends })
  end
  return true
end

-- Pobiera kolejny prompt; pytania, które stały się trywialne (1 możliwość) rozstrzyga od razu.
nextPrompt = function(state)
  while true do
    local pr = table.remove(state.prompts, 1)
    if not pr then
      state.prompt = nil
      return continueFlow(state)
    end
    local p = state.players[pr.pid]
    if p.eliminated or state.winner then
      -- pomiń
    elseif pr.type == "fame_slot" then
      if fameCount(p) >= 6 then return setWinner(state, pr.pid) end
      local legal = legalFameSlots(p)
      if #legal == 1 then placeFame(state, pr.pid, legal[1]) else state.prompt = pr; return end
    elseif pr.type == "fame_remove" then
      local ends = fameArcEnds(p)
      if #ends == 0 then
        -- nic do zdjęcia
      elseif #ends == 1 or Cards.FAME_RING[ends[1]] == Cards.FAME_RING[ends[2]] then
        removeFame(state, pr.pid, ends[#ends], pr.reason)
      else
        pr.slots = ends
        state.prompt = pr
        return
      end
    else
      state.prompt = pr
      return
    end
  end
end

local function giveCoins(state, pid, n)
  local p = state.players[pid]
  p.coins = p.coins + n
  if n ~= 0 then event(state, { type = "coins", pid = pid, delta = n }) end
end

local function setupCharacterStart(state, p)
  local c = char(p)
  p.maxHp = (c.trait == "hp4") and 4 or Cards.BASE_HP
  p.hp = p.maxHp
  p.coins = (c.trait == "coins3") and 3 or ((c.trait == "fame_instead_coin") and 0 or 1)
  p.startFame = (c.trait == "fame_instead_coin") and 2 or 1
  p.forestKills = 0
  if c.trait == "start_equipment" then
    local card = draw(state, "market")
    if card then
      if card.kind == "weapon" and #p.weapons < maxWeapons(p) then
        p.weapons[#p.weapons + 1] = card
      elseif card.kind == "potion" and not p.potion then
        p.potion = card
      else
        discard(state, "market", card)
      end
      log(state, p.name .. " zaczyna z ekwipunkiem: " .. card.name .. ".")
    end
  end
end

local function checkLastStanding(state)
  local a = alive(state)
  if #a == 1 and #state.players > 1 then
    state.winner = a[1].id
    state.phase = "finished"
    state.prompt, state.prompts = nil, {}
    log(state, a[1].name .. " jako jedyny pozostaje w grze i wygrywa.")
    event(state, { type = "winner", pid = a[1].id })
    return true
  end
end

local function damage(state, pid, n, reason)
  local p = state.players[pid]
  if p.eliminated then return end
  p.hp = math.max(0, p.hp - n)
  log(state, p.name .. " traci " .. n .. " punkt zdrowia (" .. reason .. ").")
  event(state, { type = "hp", pid = pid, delta = -n })
  if p.hp > 0 then return end
  -- śmierć postaci
  p.fame = { false, false, false, false, false, false }
  p.coins = 0
  p.deaths = p.deaths + 1
  if p.deaths >= 2 then
    p.eliminated = true
    log(state, p.name .. " traci drugą postać i odpada z gry.")
    event(state, { type = "eliminated", pid = pid })
    checkLastStanding(state)
    return
  end
  p.charIndex = 2
  setupCharacterStart(state, p)
  log(state, p.name .. " ginie. Do gry wkracza " .. char(p).name .. ".")
  event(state, { type = "death", pid = pid })
  gainFame(state, pid, p.startFame, "nowa postać")
end

local function heal(state, pid, n)
  local p = state.players[pid]
  local before = p.hp
  p.hp = math.min(p.maxHp, p.hp + n)
  if p.hp ~= before then event(state, { type = "hp", pid = pid, delta = p.hp - before }) end
  return p.hp - before
end

-- ----------------------------------------------------------- ekwipunek
-- Wyposażenie karty (po kupnie / loterii). Może utworzyć prompt przy pełnym ekwipunku.
local function equip(state, pid, card)
  local p = state.players[pid]
  if card.kind == "weapon" then
    if #p.weapons < maxWeapons(p) then
      p.weapons[#p.weapons + 1] = card
      log(state, p.name .. " wyposaża: " .. card.name .. ".")
    else
      pushPrompt(state, { type = "equip_replace", pid = pid, card = card })
    end
  else
    if not p.potion then
      p.potion = card
      log(state, p.name .. " zdobywa eliksir.")
    else
      pushPrompt(state, { type = "equip_replace", pid = pid, card = card })
    end
  end
end

-- ----------------------------------------------------------------- tury
local function nextPlayerIndex(state, from)
  local n = #state.players
  for k = 1, n do
    local idx = (from - 1 + k - 1) % n + 1
    if not state.players[idx].eliminated then return idx end
  end
end

local function startTurn(state, pid)
  state.turn = { player = pid, fameBought = false }
  for _, p in ipairs(state.players) do p.rerollsUsed = 0 end
  state.phase = "market"
  log(state, "— Tura: " .. state.players[pid].name .. " —")
  event(state, { type = "turn", pid = pid })
end

local function endTurn(state)
  if state.winner then return end
  state.fight = nil
  startTurn(state, nextPlayerIndex(state, state.turn.player + 1))
end

-- --------------------------------------------------------- pole walki
local function clearField(state, keepGuarded)
  local f = state.field
  if f.monster then discard(state, "road", f.monster); f.monster = nil end
  for _, e in ipairs(f.submitted) do discard(state, "village", e.card) end
  f.submitted = {}
  if not keepGuarded then f.guardedCards = 0 end
  f.pledgedFame = 0
end

local function poolOf(state)
  local m = state.field.monster
  return { fame = m.fame + state.field.pledgedFame, coins = m.coins + 2 * state.field.guardedCards }
end

local function awardPool(state, pid, reason)
  local pool = poolOf(state)
  local p = state.players[pid]
  if state.fight and state.fight.attacker == pid and state.field.monster.color == "blue" and char(p).trait == "magic_coins" then
    pool.coins = pool.coins + 2
  end
  giveCoins(state, pid, pool.coins)
  log(state, p.name .. " zgarnia pulę: " .. pool.fame .. " sławy, " .. pool.coins .. " miedziaków (" .. reason .. ").")
  event(state, { type = "pool", pid = pid, fame = pool.fame, coins = pool.coins })
  state.field.guardedCards = 0 -- pula wykorzystana
  gainFame(state, pid, pool.fame, reason)
end

-- ----------------------------------------------------------- walka
local function returnUnchosen(state)
  local f = state.field
  local keep = {}
  for i, e in ipairs(f.submitted) do
    if e.revealed then keep[#keep + 1] = e
    else table.insert(state.players[e.owner].hand, e.card) end
  end
  f.submitted = keep
end

local function beginBonusPhase(state)
  state.phase = "fight_bonus"
  local f = state.fight
  log(state, state.players[f.attacker].name .. " walczy z " .. state.field.monster.name .. " (siła potwora " .. monsterStrength(state) .. ").")
end

local function finishFight(state) -- sprzątanie i koniec tury
  local f = state.fight
  for _, c in ipairs(f.bonuses) do discard(state, "village", c) end
  clearField(state)
  state.afterPrompts = "end_turn"
  nextPrompt(state)
end

local function resolveFight(state, attackerWins, how)
  local f = state.fight
  local attacker = state.players[f.attacker]
  local m = state.field.monster
  f.result = attackerWins and "win" or "lose"
  event(state, { type = "fight_result", win = attackerWins, pid = f.attacker })
  if attackerWins then
    log(state, attacker.name .. " pokonuje " .. m.name .. (how and (" (" .. how .. ")") or "") .. ".")
    awardPool(state, f.attacker, "wygrana walka")
    if m.color == "green" and char(attacker).trait == "forest_hunter" then
      attacker.forestKills = attacker.forestKills + 1
      if attacker.forestKills % 2 == 0 then gainFame(state, f.attacker, 1, "Gajowy Szyszka: 2 leśne bestie") end
    end
    for _, e in ipairs(f.counted) do
      if e.card.effect == "crooked" then gainFame(state, e.owner, 1, "Na krzywy ryj") end
      if e.card.kind == "disguise" then damage(state, e.owner, 1, "pokonane przebranie") end
    end
  else
    log(state, attacker.name .. " przegrywa z " .. m.name .. (how and (" (" .. how .. ")") or "") .. ".")
    damage(state, f.attacker, 1, "przegrana walka")
    local disguiseOwner
    for _, e in ipairs(f.counted) do
      if e.card.kind == "disguise" then disguiseOwner = e.owner end
      if e.card.effect == "vampire" then
        if heal(state, e.owner, 1) > 0 then log(state, state.players[e.owner].name .. " odzyskuje punkt zdrowia (Wampir).") end
      end
      if e.card.effect == "hyena" then
        pushPrompt(state, { type = "hyena", pid = e.owner, victim = f.attacker })
      end
    end
    if disguiseOwner then awardPool(state, disguiseOwner, "Stwór z Obory wygrywa") end
  end
  finishFight(state)
end

local function allResponded(state)
  for _, p in ipairs(alive(state)) do
    if not state.pending.responses[p.id] then return false end
  end
  return true
end

local function resetResponses(state, except)
  state.pending.responses = {}
  if except then state.pending.responses[except] = true end
end

local function evaluateRoll(state)
  local f = state.fight
  local total = playerStrength(state, state.players[f.attacker], colorsFor(f), f.bonuses) + f.roll + (f.extraRoll or 0)
  return total, monsterStrength(state)
end
Rules.evaluateRoll = evaluateRoll

local function rollDie(state)
  return DIE[state.rng:int(6)]
end

local function destructibleIndices(state)
  local out = {}
  for i, e in ipairs(state.fight.counted) do
    if e.card.kind ~= "black" then out[#out + 1] = i end
  end
  return out
end

local function destroyCounted(state, idx)
  local f = state.fight
  local e = table.remove(f.counted, idx)
  removeById(state.field.submitted, e.card.id)
  discard(state, "village", e.card)
  log(state, "Ikona niszczenia: karta " .. e.card.name .. " zostaje odrzucona.")
  event(state, { type = "destroy", card = e.card })
end

local function doRoll(state)
  local f = state.fight
  local r = rollDie(state)
  event(state, { type = "roll", pid = f.attacker, value = r })
  if r == "destroy" then
    log(state, state.players[f.attacker].name .. " wyrzuca ikonę niszczenia karty.")
    local d = destructibleIndices(state)
    if #d == 0 then
      f.roll = "destroy"
      return resolveFight(state, true, "automatyczna wygrana")
    elseif #d == 1 then
      destroyCounted(state, d[1])
      return doRoll(state)
    else
      state.phase = "fight_destroy"
      return
    end
  end
  f.roll = r
  f.extraRoll = nil
  log(state, state.players[f.attacker].name .. " wyrzuca " .. r .. ".")
  state.phase = "fight_react"
  resetResponses(state)
end

-- czarna karta po odkryciu: zwraca true, jeśli przejęła przebieg walki
local function applyBlack(state, entry, opponentPid)
  local f = state.fight
  local c = entry.card
  if c.effect == "mine" then
    f.attacker = entry.owner
    log(state, state.players[entry.owner].name .. " zagrywa „Mój ci on” i przejmuje walkę!")
    event(state, { type = "black", card = c, pid = entry.owner })
    f.counted = {}
    beginBonusPhase(state)
    return true
  elseif c.effect == "brawl" then
    event(state, { type = "black", card = c, pid = entry.owner })
    log(state, state.players[entry.owner].name .. " zagrywa „Ustawkę”! Walka między graczami.")
    state.brawl = { a = entry.owner, b = opponentPid, bonuses = { [entry.owner] = {}, [opponentPid] = {} }, ready = {} }
    state.phase = "brawl_color"
    return true
  elseif c.effect == "pig_coins" or c.effect == "pig_fame" then
    event(state, { type = "black", card = c, pid = entry.owner })
    local victim = state.players[opponentPid]
    local owner = state.players[entry.owner]
    log(state, owner.name .. " podkłada świnię: " .. c.name .. "! " .. victim.name .. " przegrywa walkę bez utraty zdrowia.")
    if c.effect == "pig_coins" then
      local n = victim.coins
      giveCoins(state, opponentPid, -n)
      giveCoins(state, entry.owner, n)
      log(state, owner.name .. " zabiera " .. n .. " miedziaków.")
    else
      if loseFame(state, opponentPid, "Sromotna świnia") then
        gainFame(state, entry.owner, 1, "Sromotna świnia")
      end
    end
    f.result = "pig"
    finishFight(state)
    return true
  end
end

-- Walka ze zlecenia: odkrycie kart i start
local function startContractFight(state, volunteerPid)
  local f = state.fight
  f.attacker = volunteerPid
  f.counted = {}
  local black
  for _, e in ipairs(state.field.submitted) do
    e.revealed = true
    event(state, { type = "reveal", card = e.card, pid = e.owner })
    if e.card.kind == "black" then black = e
    elseif Cards.cardMatchesColor(e.card, f.color) or e.card.kind == "disguise" then f.counted[#f.counted + 1] = e
    else log(state, "Karta " .. e.card.name .. " nie pasuje kolorem i nie jest brana pod uwagę.") end
  end
  if black then
    f.counted = {}
    if applyBlack(state, black, volunteerPid) then return end
  end
  beginBonusPhase(state)
end

local function resolveNoVolunteer(state)
  local f = state.fight
  local disguise
  for _, e in ipairs(state.field.submitted) do
    e.revealed = true
    event(state, { type = "reveal", card = e.card, pid = e.owner })
    if e.card.kind == "disguise" then disguise = e end
  end
  if disguise then
    log(state, "Nikt nie walczy. Stwór z Obory (" .. state.players[f.contractor].name .. ") zgarnia pulę.")
    awardPool(state, f.contractor, "nikt nie walczy ze Stworem z Obory")
  else
    log(state, "Nikt nie walczy. Tchórze! Karty trafiają na stos odrzuconych.")
  end
  for _, c in ipairs(f.bonuses) do discard(state, "village", c) end
  clearField(state, not disguise)
  state.afterPrompts = "end_turn"
  nextPrompt(state)
end

-- ----------------------------------------------------------- ustawka
local function brawlStrength(state, pid)
  local b = state.brawl
  return playerStrength(state, state.players[pid], { b.color }, b.bonuses[pid])
end

local function resolveBrawl(state)
  local b = state.brawl
  local ra, rb = rollDie(state), rollDie(state)
  event(state, { type = "roll", pid = b.a, value = ra })
  event(state, { type = "roll", pid = b.b, value = rb })
  local pa, pb = state.players[b.a], state.players[b.b]
  log(state, pa.name .. " wyrzuca " .. tostring(ra) .. ", " .. pb.name .. " wyrzuca " .. tostring(rb) .. ".")
  local winner
  if ra == "destroy" and rb == "destroy" then
    log(state, "Remis – powtórka rzutów.")
    return resolveBrawl(state)
  elseif ra == "destroy" then winner = b.a
  elseif rb == "destroy" then winner = b.b
  else
    local sa, sb = brawlStrength(state, b.a) + ra, brawlStrength(state, b.b) + rb
    log(state, "Siła: " .. pa.name .. " " .. sa .. " vs " .. pb.name .. " " .. sb .. ".")
    if sa == sb then
      log(state, "Remis – powtórka rzutów.")
      return resolveBrawl(state)
    end
    winner = sa > sb and b.a or b.b
  end
  local loser = winner == b.a and b.b or b.a
  local w, l = state.players[winner], state.players[loser]
  log(state, w.name .. " wygrywa Ustawkę, zabiera miedziaki (" .. l.coins .. ") i zdobywa punkt sławy.")
  event(state, { type = "fight_result", win = true, pid = winner })
  local n = l.coins
  giveCoins(state, loser, -n)
  giveCoins(state, winner, n)
  gainFame(state, winner, 1, "Ustawka")
  for _, pid in ipairs({ b.a, b.b }) do
    for _, c in ipairs(b.bonuses[pid]) do discard(state, "village", c) end
  end
  for _, c in ipairs(state.fight.bonuses) do discard(state, "village", c) end
  state.brawl = nil
  clearField(state, true)
  state.afterPrompts = "end_turn"
  nextPrompt(state)
end

-- ------------------------------------------------------------ wydarzenia
local revealRoad -- forward

local function resolveEvent(state, card, pid)
  local p = state.players[pid]
  log(state, p.name .. " odkrywa wydarzenie: " .. card.name .. ".")
  event(state, { type = "event_card", card = card, pid = pid })
  local e = card.effect
  if e == "fly" then
    discard(state, "road", card)
    log(state, "Leci mucha… " .. p.name .. " traci turę.")
    state.afterPrompts = "end_turn"
    return nextPrompt(state)
  elseif e == "healer" then
    discard(state, "road", card)
    if p.hp > 1 then
      pushPrompt(state, { type = "healer", pid = pid })
    else
      log(state, "Znachor: za mało zdrowia, by sprzedać narządy.")
    end
    state.afterPrompts = "end_turn"
    return nextPrompt(state)
  elseif e == "lottery" then
    discard(state, "road", card)
    local c = draw(state, "market")
    if c then
      log(state, p.name .. " wygrywa na loterii: " .. c.name .. ".")
      equip(state, pid, c)
    end
    state.afterPrompts = "end_turn"
    return nextPrompt(state)
  elseif e == "hog" then
    discard(state, "road", card)
    if fameCount(p) > 0 then
      pushPrompt(state, { type = "hog_target", pid = pid })
    else
      log(state, "Wieprz! " .. p.name .. " nie ma sławy do stracenia.")
    end
    state.afterPrompts = "end_turn"
    return nextPrompt(state)
  elseif e == "courage" then
    discard(state, "road", card)
    state.forcedFight = true
    return revealRoad(state, pid)
  elseif e == "guarded_coins" then
    discard(state, "road", card)
    state.field.guardedCards = state.field.guardedCards + 1
    log(state, "Strzeżone miedziaki: pula za najbliższego potwora rośnie o 2.")
    return revealRoad(state, pid)
  elseif e == "seer" then
    discard(state, "road", card)
    local cards = {}
    for _ = 1, 3 do
      local c = draw(state, "road")
      if c then cards[#cards + 1] = c end
    end
    if #cards > 0 then
      pushPrompt(state, { type = "seer", pid = pid, cards = cards })
    end
    state.afterPrompts = "end_turn"
    return nextPrompt(state)
  end
end

revealRoad = function(state, pid)
  local card = draw(state, "road")
  if not card then
    log(state, "Talia Gościńca jest pusta.")
    state.afterPrompts = "end_turn"
    return nextPrompt(state)
  end
  if card.kind == "event" then return resolveEvent(state, card, pid) end
  state.field.monster = card
  state.field.submitted = {}
  state.field.pledgedFame = 0
  event(state, { type = "monster", card = card })
  log(state, state.players[pid].name .. " napotyka: " .. card.name .. " (" .. Cards.COLOR_NAMES[card.color] .. ", siła " .. card.strength .. ").")
  state.fight = { color = card.color, attacker = pid, bonuses = {}, counted = {}, mode = "fight" }
  if state.forcedFight then
    state.forcedFight = nil
    log(state, "Gorzoła odwagi: " .. state.players[pid].name .. " musi walczyć!")
    state.phase = "fight_add"
    resetResponses(state, pid)
    if allResponded(state) then beginBonusPhase(state) end
  else
    state.phase = "encounter"
  end
end

-- kontynuacja głównego przebiegu po opróżnieniu kolejki promptów
continueFlow = function(state)
  local what = state.afterPrompts
  state.afterPrompts = nil
  if state.winner then return end
  if what == "end_turn" then endTurn(state)
  elseif what == "market" then state.phase = "market"
  elseif what == "start_game" then startTurn(state, state.turn.player)
  elseif what == "reroll" then doRoll(state)
  end
end

-- ------------------------------------------------------------- setup
local function allSetupDone(state)
  for _, p in ipairs(state.players) do
    if state.setup[p.id].step ~= "done" then return false end
  end
  return true
end

local function setupAdvance(state, pid)
  local s = state.setup[pid]
  local p = state.players[pid]
  if s.step == "character" then
    s.step = "fame"
    s.fameLeft = p.startFame
  end
  if s.step == "fame" and s.fameLeft == 0 then s.step = "swap" end
  if s.step == "done" and allSetupDone(state) then
    state.afterPrompts = "start_game"
    nextPrompt(state)
  end
end

-- ------------------------------------------------------------- tworzenie
function Rules.new(playerNames, seed)
  local state = {
    seq = 0, log = {}, events = {}, prompts = {}, prompt = nil,
    rng = Rng.new(seed), seed = seed,
    players = {}, setup = {},
    decks = {
      village = { draw = Cards.buildDeck(Cards.village, "v"), discard = {} },
      market = { draw = Cards.buildDeck(Cards.market, "m"), discard = {} },
      road = { draw = Cards.buildDeck(Cards.road, "r"), discard = {} },
    },
    marketRow = {},
    field = { monster = nil, submitted = {}, guardedCards = 0, pledgedFame = 0 },
    turn = { player = 1, fameBought = false },
    phase = "setup",
    pending = { responses = {} },
  }
  for _, d in pairs(state.decks) do state.rng:shuffle(d.draw) end
  local charPool = {}
  for _, c in ipairs(Cards.characters) do charPool[#charPool + 1] = c end
  state.rng:shuffle(charPool)
  for i, name in ipairs(playerNames) do
    state.players[i] = {
      id = i, name = name, chars = { table.remove(charPool), table.remove(charPool) }, charIndex = 1,
      hp = 3, maxHp = 3, coins = 0, fame = { false, false, false, false, false, false }, hand = {}, weapons = {}, potion = nil,
      eliminated = false, deaths = 0, forestKills = 0, rerollsUsed = 0, startFame = 1,
    }
    state.setup[i] = { step = "character", fameLeft = 1 }
  end
  refillMarket(state)
  log(state, "Rozpoczyna się gra. Każdy gracz wybiera postać.")
  return state
end

-- -------------------------------------------------------------- akcje
local handlers = {}

local function requirePlayerTurn(state, pid)
  if state.turn.player ~= pid then return false, "Nie Twoja tura." end
  return true
end

local function handCard(p, id)
  for _, c in ipairs(p.hand) do if c.id == id then return c end end
end

-- ---- setup
handlers.choose_character = function(state, pid, a)
  if state.phase ~= "setup" or state.setup[pid].step ~= "character" then return false, "Nie można teraz wybrać postaci." end
  local p = state.players[pid]
  if a.index ~= 1 and a.index ~= 2 then return false, "Zły indeks." end
  if a.index == 2 then p.chars[1], p.chars[2] = p.chars[2], p.chars[1] end
  setupCharacterStart(state, p)
  local n = (char(p).trait == "hand6") and 6 or 4
  for _ = 1, n do table.insert(p.hand, draw(state, "village")) end
  log(state, p.name .. " gra postacią: " .. char(p).name .. ".")
  setupAdvance(state, pid)
  return true
end

handlers.setup_fame_slot = function(state, pid, a)
  if state.phase ~= "setup" or state.setup[pid].step ~= "fame" then return false, "Nie można teraz położyć sławy." end
  local p = state.players[pid]
  local ok = false
  for _, s in ipairs(legalFameSlots(p)) do if s == a.slot then ok = true end end
  if not ok then return false, "Niedozwolone pole sławy." end
  placeFame(state, pid, a.slot)
  state.setup[pid].fameLeft = state.setup[pid].fameLeft - 1
  setupAdvance(state, pid)
  return true
end

handlers.swap_card = function(state, pid, a)
  if state.phase ~= "setup" or state.setup[pid].step ~= "swap" then return false, "Nie można teraz wymienić karty." end
  local p = state.players[pid]
  if a.cardId then
    local c = removeById(p.hand, a.cardId)
    if not c then return false, "Nie masz tej karty." end
    table.insert(state.decks.village.draw, c) -- na spód talii
    table.insert(p.hand, draw(state, "village"))
    log(state, p.name .. " wymienia 1 kartę.")
  end
  state.setup[pid].step = "done"
  setupAdvance(state, pid)
  return true
end

-- ---- targowisko
handlers.buy = function(state, pid, a)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "market" then return false, "Targowisko jest dostępne tylko na początku tury." end
  local card = state.marketRow[a.index or 0]
  if not card then return false, "Brak karty." end
  local p = state.players[pid]
  if p.coins < card.price then return false, "Za mało miedziaków." end
  giveCoins(state, pid, -card.price)
  state.marketRow[a.index] = nil
  refillMarket(state)
  log(state, p.name .. " kupuje " .. card.name .. " za " .. card.price .. ".")
  event(state, { type = "buy", pid = pid, card = card })
  equip(state, pid, card)
  state.afterPrompts = "market"
  nextPrompt(state)
  return true
end

handlers.buy_fame = function(state, pid)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "market" then return false, "Sławę można kupić tylko na początku tury." end
  local p = state.players[pid]
  if state.turn.fameBought then return false, "Tylko 1 punkt sławy na turę." end
  if p.coins < Cards.FAME_PRICE then return false, "Potrzebujesz 4 miedziaków." end
  if fameCount(p) >= 6 then return false, "Nie można kupić zwycięskiego punktu." end
  giveCoins(state, pid, -Cards.FAME_PRICE)
  state.turn.fameBought = true
  gainFame(state, pid, 1, "przekupiony motłoch")
  state.afterPrompts = "market"
  nextPrompt(state)
  return true
end

handlers.end_market = function(state, pid)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "market" then return false, "Nie jesteś na Targowisku." end
  local p = state.players[pid]
  local c = draw(state, "village")
  if c then
    table.insert(p.hand, c)
    event(state, { type = "draw", pid = pid, deck = "village" })
  end
  log(state, p.name .. " dobiera kartę Wioski.")
  state.phase = "road_choice"
  return true
end

handlers.draw_village = function(state, pid)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "road_choice" then return false, "Nie można teraz dobrać karty." end
  local p = state.players[pid]
  local c = draw(state, "village")
  if c then
    table.insert(p.hand, c)
    event(state, { type = "draw", pid = pid, deck = "village" })
  end
  log(state, p.name .. " dobiera drugą kartę Wioski zamiast iść na Gościniec.")
  state.afterPrompts = "end_turn"
  nextPrompt(state)
  return true
end

handlers.reveal_road = function(state, pid)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "road_choice" then return false, "Nie można teraz odkryć Gościńca." end
  revealRoad(state, pid)
  return true
end

-- ---- spotkanie z potworem
handlers.fight = function(state, pid)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "encounter" then return false, "Nie ma potwora do walki." end
  log(state, state.players[pid].name .. " ogłasza WALKĘ! Inni gracze mogą dorzucić po 1 zakrytej karcie.")
  event(state, { type = "announce", mode = "fight", pid = pid })
  state.fight.mode = "fight"
  state.phase = "fight_add"
  resetResponses(state, pid)
  if allResponded(state) then beginBonusPhase(state) end
  return true
end

handlers.contract = function(state, pid, a)
  local ok, err = requirePlayerTurn(state, pid); if not ok then return ok, err end
  if state.phase ~= "encounter" then return false, "Nie ma potwora do zlecenia." end
  local p = state.players[pid]
  local ids = a.cardIds or {}
  if #ids > 3 then return false, "Maksymalnie 3 karty." end
  local blacks, seen = 0, {}
  for _, id in ipairs(ids) do
    if seen[id] then return false, "Powtórzona karta." end
    seen[id] = true
    local c = handCard(p, id)
    if not c then return false, "Nie masz tej karty." end
    if c.kind == "black" then
      blacks = blacks + 1
      if c.effect == "mine" then return false, "„Mój ci on” nie może być dodane do zlecenia." end
    end
  end
  if blacks > 1 then return false, "Do zlecenia nie można dodać 2 czarnych kart." end
  for _, id in ipairs(ids) do
    local c = removeById(p.hand, id)
    table.insert(state.field.submitted, { owner = pid, card = c, revealed = false })
  end
  state.fight.mode = "contract"
  state.fight.contractor = pid
  state.fight.attacker = nil
  log(state, p.name .. " ogłasza ZLECENIE na " .. state.field.monster.name .. " (" .. #ids .. " zakrytych kart). Kto walczy?")
  event(state, { type = "announce", mode = "contract", pid = pid, n = #ids })
  state.phase = "contract_volunteer"
  state.pending.volunteers = {}
  resetResponses(state, pid)
  if allResponded(state) then resolveNoVolunteer(state) end
  return true
end

-- ---- walka: dorzucanie
handlers.add_card = function(state, pid, a)
  if state.phase ~= "fight_add" then return false, "Nie można teraz dorzucać kart." end
  if state.pending.responses[pid] then return false, "Już odpowiedziałeś." end
  local p = state.players[pid]
  if p.eliminated then return false, "Odpadłeś z gry." end
  local c = removeById(p.hand, a.cardId)
  if not c then return false, "Nie masz tej karty." end
  table.insert(state.field.submitted, { owner = pid, card = c, revealed = false })
  state.pending.responses[pid] = true
  log(state, p.name .. " dorzuca zakrytą kartę do potwora.")
  event(state, { type = "submit", pid = pid })
  if allResponded(state) then
    if #state.field.submitted == 0 then beginBonusPhase(state) else state.phase = "fight_pick" end
  end
  return true
end

handlers.pass = function(state, pid)
  if state.phase == "fight_add" then
    if state.pending.responses[pid] then return false, "Już odpowiedziałeś." end
    state.pending.responses[pid] = true
    if allResponded(state) then
      if #state.field.submitted == 0 then beginBonusPhase(state) else state.phase = "fight_pick" end
    end
    return true
  elseif state.phase == "contract_volunteer" then
    if state.pending.responses[pid] then return false, "Już odpowiedziałeś." end
    state.pending.responses[pid] = true
    if allResponded(state) then
      local v = state.pending.volunteers
      if #v == 0 then resolveNoVolunteer(state)
      elseif #v == 1 then startContractFight(state, v[1])
      else state.phase = "contract_pick" end
    end
    return true
  end
  return false, "Nie ma na co pasować."
end

handlers.pick_card = function(state, pid, a)
  if state.phase ~= "fight_pick" then return false, "Nie można teraz wybierać karty." end
  if state.fight.attacker ~= pid then return false, "Wybiera atakujący." end
  local e = state.field.submitted[a.index or 0]
  if not e then return false, "Brak karty." end
  e.revealed = true
  returnUnchosen(state)
  event(state, { type = "reveal", card = e.card, pid = e.owner })
  log(state, "Odkryta karta: " .. e.card.name .. " (" .. state.players[e.owner].name .. ").")
  if e.card.kind == "black" then
    if applyBlack(state, e, pid) then return true end
  elseif Cards.cardMatchesColor(e.card, state.fight.color) or e.card.kind == "disguise" then
    state.fight.counted = { e }
  else
    log(state, "Karta nie pasuje kolorem i nie jest brana pod uwagę.")
  end
  beginBonusPhase(state)
  return true
end

-- ---- zlecenie: ochotnicy
handlers.volunteer = function(state, pid)
  if state.phase ~= "contract_volunteer" then return false, "Nie ma zlecenia." end
  if state.pending.responses[pid] then return false, "Już odpowiedziałeś." end
  if state.players[pid].eliminated then return false, "Odpadłeś z gry." end
  state.pending.responses[pid] = true
  table.insert(state.pending.volunteers, pid)
  log(state, state.players[pid].name .. " zgłasza się do walki.")
  if allResponded(state) then
    local v = state.pending.volunteers
    if #v == 1 then startContractFight(state, v[1]) else state.phase = "contract_pick" end
  end
  return true
end

handlers.pick_volunteer = function(state, pid, a)
  if state.phase ~= "contract_pick" then return false, "Nie można teraz wybrać ochotnika." end
  if state.fight.contractor ~= pid then return false, "Wybiera zleceniodawca." end
  local found
  for _, v in ipairs(state.pending.volunteers) do if v == a.pid then found = true end end
  if not found then return false, "Ten gracz się nie zgłosił." end
  startContractFight(state, a.pid)
  return true
end

-- ---- walka: premie, eliksiry, rzut
handlers.play_bonus = function(state, pid, a)
  if state.phase == "brawl_bonus" then
    local b = state.brawl
    if pid ~= b.a and pid ~= b.b then return false, "Nie bierzesz udziału w Ustawce." end
    if b.ready[pid] then return false, "Już jesteś gotowy." end
    local p = state.players[pid]
    local c = handCard(p, a.cardId)
    if not c then return false, "Nie masz tej karty." end
    if c.kind ~= "bonus" or c.color ~= b.color then return false, "Premia musi być w kolorze Ustawki." end
    removeById(p.hand, a.cardId)
    table.insert(b.bonuses[pid], c)
    log(state, p.name .. " zagrywa premię: " .. c.name .. ".")
    event(state, { type = "bonus", pid = pid, card = c })
    return true
  end
  if state.phase ~= "fight_bonus" then return false, "Nie można teraz zagrać premii." end
  local f = state.fight
  if f.attacker ~= pid then return false, "Premie zagrywa atakujący." end
  local p = state.players[pid]
  local c = handCard(p, a.cardId)
  if not c then return false, "Nie masz tej karty." end
  if c.kind ~= "bonus" then return false, "Kart specjalnych nie można użyć jako premii dla postaci." end
  local okColor = false
  for _, col in ipairs(colorsFor(f)) do if col == c.color then okColor = true end end
  if not okColor then return false, "Premia nie pasuje kolorem do potwora." end
  removeById(p.hand, a.cardId)
  table.insert(f.bonuses, c)
  log(state, p.name .. " zagrywa premię: " .. c.name .. ".")
  event(state, { type = "bonus", pid = pid, card = c })
  return true
end

handlers.use_potion = function(state, pid, a)
  local p = state.players[pid]
  if not p.potion then return false, "Nie masz eliksiru." end
  local pot = p.potion
  local f = state.fight
  local inFight = f and f.attacker == pid and (state.phase == "fight_bonus" or state.phase == "fight_react")
  if pot.effect == "heal" then
    if not (inFight or (state.phase == "market" and state.turn.player == pid)) then return false, "Eliksir można wypić w walce lub na Targowisku." end
    if p.hp >= p.maxHp then return false, "Masz pełne zdrowie." end
    p.potion = nil
    discard(state, "market", pot)
    heal(state, pid, 1)
    log(state, p.name .. " wypija Potjon i odzyskuje zdrowie.")
    event(state, { type = "potion", pid = pid, card = pot })
    return true
  end
  if not inFight then return false, "Ten eliksir działa tylko w Twojej walce." end
  if pot.effect == "any_color" then
    if state.phase ~= "fight_bonus" then return false, "Wilka trzeba wypić przed rzutem." end
    local col = a.color
    if col ~= "red" and col ~= "green" and col ~= "blue" then return false, "Wybierz kolor." end
    p.potion = nil
    discard(state, "market", pot)
    f.extraColor = col
    log(state, p.name .. " wypija Wilka: w tej walce liczy się też kolor " .. Cards.COLOR_LABEL[col] .. ".")
    event(state, { type = "potion", pid = pid, card = pot })
    return true
  end
  if pot.effect == "extra_die" then
    if state.phase ~= "fight_react" then return false, "Dzika pij po rzucie kością." end
    p.potion = nil
    discard(state, "market", pot)
    event(state, { type = "potion", pid = pid, card = pot })
    local r = rollDie(state)
    event(state, { type = "roll", pid = pid, value = r })
    if r == "destroy" then
      log(state, p.name .. " wypija Dzika i wyrzuca ikonę niszczenia: automatyczna wygrana!")
      resolveFight(state, true, "Dzik")
      return true
    end
    f.extraRoll = r
    log(state, p.name .. " wypija Dzika: dodatkowy rzut " .. r .. ".")
    resetResponses(state)
    return true
  end
  return false, "Nieznany eliksir."
end

handlers.roll = function(state, pid)
  if state.phase ~= "fight_bonus" then return false, "Nie można teraz rzucać." end
  if state.fight.attacker ~= pid then return false, "Rzuca atakujący." end
  doRoll(state)
  return true
end

handlers.destroy_card = function(state, pid, a)
  if state.phase ~= "fight_destroy" then return false, "Nie ma karty do zniszczenia." end
  if state.fight.attacker ~= pid then return false, "Wybiera atakujący." end
  local okIdx = false
  for _, i in ipairs(destructibleIndices(state)) do if i == a.index then okIdx = true end end
  if not okIdx then return false, "Tej karty nie można zniszczyć." end
  destroyCounted(state, a.index)
  doRoll(state)
  return true
end

handlers.accept = function(state, pid)
  if state.phase ~= "fight_react" then return false, "Nie ma rzutu do zaakceptowania." end
  if state.pending.responses[pid] then return false, "Już odpowiedziałeś." end
  state.pending.responses[pid] = true
  if allResponded(state) then
    local total, ms = evaluateRoll(state)
    resolveFight(state, total >= ms, "siła " .. total .. " vs " .. ms)
  end
  return true
end

handlers.reroll = function(state, pid)
  if state.phase ~= "fight_react" then return false, "Nie ma rzutu do przerzucenia." end
  local p = state.players[pid]
  if p.eliminated then return false, "Odpadłeś z gry." end
  if p.rerollsUsed >= rerollLimit(p) then return false, "Wykorzystałeś już przerzut w tej walce." end
  if fameCount(p) == 0 then return false, "Przerzut kosztuje punkt sławy, którego nie masz." end
  p.rerollsUsed = p.rerollsUsed + 1
  state.field.pledgedFame = state.field.pledgedFame + 1
  log(state, p.name .. " anuluje rzut, oddając punkt sławy do puli.")
  event(state, { type = "reroll", pid = pid })
  loseFame(state, pid, "zastaw za przerzut")
  state.afterPrompts = "reroll"
  if #state.prompts > 0 then
    nextPrompt(state)
  else
    state.afterPrompts = nil
    doRoll(state)
  end
  return true
end

-- ---- ustawka
handlers.brawl_color = function(state, pid, a)
  if state.phase ~= "brawl_color" then return false, "Nie wybierasz teraz koloru." end
  local b = state.brawl
  if pid ~= b.a then return false, "Kolor wybiera gracz, który zagrał Ustawkę." end
  if a.color ~= "red" and a.color ~= "green" and a.color ~= "blue" then return false, "Wybierz kolor." end
  b.color = a.color
  log(state, state.players[pid].name .. " wybiera kolor Ustawki: " .. Cards.COLOR_LABEL[a.color] .. ".")
  state.phase = "brawl_bonus"
  return true
end

handlers.ready = function(state, pid)
  if state.phase ~= "brawl_bonus" then return false, "Nie ma na co być gotowym." end
  local b = state.brawl
  if pid ~= b.a and pid ~= b.b then return false, "Nie bierzesz udziału w Ustawce." end
  b.ready[pid] = true
  if b.ready[b.a] and b.ready[b.b] then resolveBrawl(state) end
  return true
end

-- ---- prompty
local promptHandlers = {}

promptHandlers.fame_slot = function(state, pid, a, pr)
  local p = state.players[pid]
  for _, s in ipairs(legalFameSlots(p)) do
    if s == a.slot then
      placeFame(state, pid, a.slot)
      return true
    end
  end
  return false, "Niedozwolone pole sławy."
end

promptHandlers.fame_remove = function(state, pid, a, pr)
  for _, s in ipairs(pr.slots) do
    if s == a.slot then
      removeFame(state, pid, s, pr.reason)
      return true
    end
  end
  return false, "Nie można zdjąć tego żetonu."
end

promptHandlers.equip_replace = function(state, pid, a, pr)
  local p = state.players[pid]
  local card = pr.card
  if a.choice == "discard_new" then
    discard(state, "market", card)
    log(state, p.name .. " odkłada " .. card.name .. " na stos odrzuconych.")
    return true
  end
  if card.kind == "potion" then
    if a.choice == "use_now" then
      if card.effect ~= "heal" then return false, "Tylko Potjon można zużyć od razu." end
      discard(state, "market", card)
      if heal(state, pid, 1) > 0 then log(state, p.name .. " od razu wypija Potjon.") end
      return true
    end
    if a.choice == "replace" then
      discard(state, "market", p.potion)
      p.potion = card
      log(state, p.name .. " wymienia eliksir.")
      return true
    end
    return false, "Wybierz: użyj, zastąp albo odrzuć."
  end
  local old = removeById(p.weapons, a.cardId)
  if not old then return false, "Wybierz broń do odrzucenia." end
  discard(state, "market", old)
  p.weapons[#p.weapons + 1] = card
  log(state, p.name .. " odrzuca " .. old.name .. " i wyposaża " .. card.name .. ".")
  return true
end

promptHandlers.hyena = function(state, pid, a, pr)
  local victim = state.players[pr.victim]
  local owner = state.players[pid]
  if a.choice == "coins" then
    local n = victim.coins
    giveCoins(state, pr.victim, -n)
    giveCoins(state, pid, n)
    log(state, owner.name .. " (Hiena) zabiera " .. n .. " miedziaków.")
    return true
  elseif a.choice == "equipment" then
    local card = removeById(victim.weapons, a.cardId)
    if not card and victim.potion and victim.potion.id == a.cardId then
      card = victim.potion
      victim.potion = nil
    end
    if not card then return false, "Nie ma takiego ekwipunku." end
    log(state, owner.name .. " (Hiena) zabiera " .. card.name .. ".")
    equip(state, pid, card)
    return true
  elseif a.choice == "nothing" then
    return true
  end
  return false, "Wybierz miedziaki albo kartę ekwipunku."
end

promptHandlers.healer = function(state, pid, a)
  local p = state.players[pid]
  if a.choice == "yes" then
    if p.hp <= 1 then return false, "To by Cię zabiło." end
    damage(state, pid, 1, "Znachor")
    giveCoins(state, pid, 4)
    log(state, p.name .. " sprzedaje narządy za 4 miedziaki.")
  else
    log(state, p.name .. " odmawia Znachorowi.")
  end
  return true
end

promptHandlers.hog_target = function(state, pid, a)
  local target = state.players[a.pid or 0]
  if not target or target.id == pid or target.eliminated then return false, "Wybierz innego gracza." end
  loseFame(state, pid, "Wieprz!")
  gainFame(state, a.pid, 1, "Wieprz! – sława od " .. state.players[pid].name)
  return true
end

promptHandlers.seer = function(state, pid, a, pr)
  local chosen
  for _, c in ipairs(pr.cards) do if c.id == a.cardId then chosen = c end end
  if not chosen then return false, "Wybierz jedną z podejrzanych kart." end
  for _, c in ipairs(pr.cards) do if c ~= chosen then discard(state, "road", c) end end
  table.insert(state.decks.road.draw, 1, chosen)
  log(state, state.players[pid].name .. " zostawia na wierzchu Gościńca jedną z trzech kart.")
  return true
end

-- ---- główny punkt wejścia
-- Zwraca ok, err. Po powodzeniu state.seq rośnie, a state.events/log zawiera nowe wpisy.
function Rules.apply(state, pid, action)
  state.events = {}
  if state.winner then return false, "Gra zakończona." end
  if type(action) ~= "table" or type(action.type) ~= "string" then return false, "Zła akcja." end
  if not state.players[pid] then return false, "Nieznany gracz." end
  local pr = state.prompt
  if pr then
    if pr.pid ~= pid then return false, "Czekamy na decyzję gracza " .. state.players[pr.pid].name .. "." end
    if action.type ~= pr.type then return false, "Najpierw odpowiedz na pytanie: " .. pr.type .. "." end
    local ok, err = promptHandlers[pr.type](state, pid, action, pr)
    if not ok then return false, err end
    state.prompt = nil
    state.seq = state.seq + 1
    if state.winner then return true end
    if state.afterPrompts == "reroll" and #state.prompts == 0 then
      state.afterPrompts = nil
      doRoll(state)
    else
      nextPrompt(state)
    end
    return true
  end
  local h = handlers[action.type]
  if not h then return false, "Nieznana akcja: " .. action.type end
  local ok, err = h(state, pid, action)
  if ok then state.seq = state.seq + 1 end
  return ok, err
end

-- Czyja decyzja jest teraz oczekiwana (lista pid) – do podświetlania w UI.
function Rules.waitingFor(state)
  if state.winner then return {} end
  if state.prompt then return { state.prompt.pid } end
  local ph = state.phase
  if ph == "setup" then
    local t = {}
    for _, p in ipairs(state.players) do if state.setup[p.id].step ~= "done" then t[#t + 1] = p.id end end
    return t
  elseif ph == "fight_add" or ph == "contract_volunteer" or ph == "fight_react" then
    local t = {}
    for _, p in ipairs(alive(state)) do if not state.pending.responses[p.id] then t[#t + 1] = p.id end end
    return t
  elseif ph == "fight_pick" or ph == "fight_bonus" or ph == "fight_destroy" then
    return { state.fight.attacker }
  elseif ph == "contract_pick" then
    return { state.fight.contractor }
  elseif ph == "brawl_color" then
    return { state.brawl.a }
  elseif ph == "brawl_bonus" then
    local t = {}
    if not state.brawl.ready[state.brawl.a] then t[#t + 1] = state.brawl.a end
    if not state.brawl.ready[state.brawl.b] then t[#t + 1] = state.brawl.b end
    return t
  end
  return { state.turn.player }
end

-- --------------------------------------------------------------- widok
local function copyCard(c) local t = {}; for k, v in pairs(c) do t[k] = v end; return t end
local function copyList(l) local t = {}; for i, c in ipairs(l) do t[i] = copyCard(c) end; return t end

-- Widok stanu dla gracza `pid` – bez informacji ukrytych.
function Rules.view(state, pid)
  local v = {
    seq = state.seq, phase = state.phase, winner = state.winner, events = state.events,
    log = { unpack(state.log, math.max(1, #state.log - 80), #state.log) },
    turn = state.turn, marketRow = copyList({ state.marketRow[1] or false, state.marketRow[2] or false, state.marketRow[3] or false }),
    waitingFor = Rules.waitingFor(state), me = pid,
    decks = {}, players = {}, field = {}, fight = nil, brawl = nil, prompt = nil, setup = {},
  }
  for i = 1, 3 do if not state.marketRow[i] then v.marketRow[i] = false end end
  for name, d in pairs(state.decks) do
    v.decks[name] = { draw = #d.draw, discard = #d.discard, top = d.discard[#d.discard] and copyCard(d.discard[#d.discard]) or nil }
  end
  for _, p in ipairs(state.players) do
    local mine = p.id == pid
    v.players[p.id] = {
      id = p.id, name = p.name, char = p.chars[p.charIndex], backup = mine and p.chars[3 - p.charIndex] or nil,
      hp = p.hp, maxHp = p.maxHp, coins = p.coins, fame = p.fame, fameCount = fameCount(p),
      handCount = #p.hand, hand = mine and copyList(p.hand) or nil,
      weapons = copyList(p.weapons), hasPotion = p.potion ~= nil, potion = mine and p.potion or nil,
      eliminated = p.eliminated, deaths = p.deaths, rerollsUsed = p.rerollsUsed, rerollLimit = rerollLimit(p),
      legalFameSlots = legalFameSlots(p), maxWeapons = maxWeapons(p), forestKills = p.forestKills,
    }
    v.setup[p.id] = state.setup[p.id] and state.setup[p.id].step or "done"
  end
  local f = state.field
  v.field = { monster = f.monster and copyCard(f.monster) or nil, guardedCards = f.guardedCards, pledgedFame = f.pledgedFame, submitted = {} }
  for i, e in ipairs(f.submitted) do
    v.field.submitted[i] = { owner = e.owner, revealed = e.revealed, card = (e.revealed or e.owner == pid) and copyCard(e.card) or nil }
  end
  if state.fight then
    local ft = state.fight
    v.fight = { color = ft.color, attacker = ft.attacker, contractor = ft.contractor, mode = ft.mode, bonuses = copyList(ft.bonuses),
      extraColor = ft.extraColor, roll = ft.roll, extraRoll = ft.extraRoll, result = ft.result }
    if f.monster then
      v.fight.monsterStrength = monsterStrength(state)
      v.fight.counted = {}
      for i, e in ipairs(ft.counted) do v.fight.counted[i] = { owner = e.owner, card = copyCard(e.card), power = fieldCardPower(state, e, ft.color) } end
      if ft.attacker then
        v.fight.attackerBase = playerStrength(state, state.players[ft.attacker], colorsFor(ft), ft.bonuses)
      end
    end
  end
  if state.brawl then
    local b = state.brawl
    v.brawl = { a = b.a, b = b.b, color = b.color, readyA = b.ready[b.a] or false, readyB = b.ready[b.b] or false,
      bonusesA = copyList(b.bonuses[b.a]), bonusesB = copyList(b.bonuses[b.b]) }
    if b.color then v.brawl.strengthA, v.brawl.strengthB = brawlStrength(state, b.a), brawlStrength(state, b.b) end
  end
  v.responses = {}
  for _, p in ipairs(state.players) do v.responses[p.id] = state.pending.responses[p.id] or false end
  v.volunteers = state.pending.volunteers or {}
  if state.prompt then
    local pr = state.prompt
    v.prompt = { type = pr.type, pid = pr.pid, reason = pr.reason, slots = pr.slots, victim = pr.victim,
      card = pr.card and copyCard(pr.card) or nil, cards = (pr.pid == pid and pr.cards) and copyList(pr.cards) or nil }
  end
  return v
end


-- ------------------------------------------------- akcje domyślne / kandydaci
-- Lista sensownych akcji dla gracza w bieżącym stanie (do pomijania nieobecnych
-- graczy przez hosta i do symulacji w testach). Nie jest wyczerpująca.
local function others(state, pid)
  local t = {}
  for _, p in ipairs(alive(state)) do if p.id ~= pid then t[#t + 1] = p.id end end
  return t
end

function Rules.candidateActions(state, pid)
  local p = state.players[pid]
  local out = {}
  local function add(a) out[#out + 1] = a end
  if state.winner then return out end
  local pr = state.prompt
  if pr then
    if pr.pid ~= pid then return out end
    if pr.type == "fame_slot" then
      for _, s in ipairs(legalFameSlots(p)) do add({ type = "fame_slot", slot = s }) end
    elseif pr.type == "fame_remove" then
      for _, s in ipairs(pr.slots) do add({ type = "fame_remove", slot = s }) end
    elseif pr.type == "equip_replace" then
      add({ type = "equip_replace", choice = "discard_new" })
      if pr.card.kind == "potion" then
        add({ type = "equip_replace", choice = "replace" })
        if pr.card.effect == "heal" and p.hp < p.maxHp then add({ type = "equip_replace", choice = "use_now" }) end
      else
        for _, w in ipairs(p.weapons) do add({ type = "equip_replace", cardId = w.id }) end
      end
    elseif pr.type == "hyena" then
      local v = state.players[pr.victim]
      if v.coins > 0 then add({ type = "hyena", choice = "coins" }) end
      for _, w in ipairs(v.weapons) do add({ type = "hyena", choice = "equipment", cardId = w.id }) end
      if v.potion then add({ type = "hyena", choice = "equipment", cardId = v.potion.id }) end
      add({ type = "hyena", choice = "nothing" })
    elseif pr.type == "healer" then
      add({ type = "healer", choice = "no" }); add({ type = "healer", choice = "yes" })
    elseif pr.type == "hog_target" then
      for _, o in ipairs(others(state, pid)) do add({ type = "hog_target", pid = o }) end
    elseif pr.type == "seer" then
      for _, c in ipairs(pr.cards) do add({ type = "seer", cardId = c.id }) end
    end
    return out
  end
  local ph = state.phase
  if ph == "setup" then
    local step = state.setup[pid].step
    if step == "character" then add({ type = "choose_character", index = 1 }); add({ type = "choose_character", index = 2 })
    elseif step == "fame" then for _, s in ipairs(legalFameSlots(p)) do add({ type = "setup_fame_slot", slot = s }) end
    elseif step == "swap" then add({ type = "swap_card" }); if p.hand[1] then add({ type = "swap_card", cardId = p.hand[1].id }) end end
    return out
  end
  local myTurn = state.turn.player == pid
  if ph == "market" and myTurn then
    add({ type = "end_market" })
    for i = 1, 3 do if state.marketRow[i] and p.coins >= state.marketRow[i].price then add({ type = "buy", index = i }) end end
    if p.coins >= Cards.FAME_PRICE and not state.turn.fameBought and fameCount(p) < 6 then add({ type = "buy_fame" }) end
    if p.potion and p.potion.effect == "heal" and p.hp < p.maxHp then add({ type = "use_potion" }) end
  elseif ph == "road_choice" and myTurn then
    add({ type = "reveal_road" }); add({ type = "draw_village" })
  elseif ph == "encounter" and myTurn then
    add({ type = "fight" }); add({ type = "contract", cardIds = {} })
    local ids = {}
    for _, c in ipairs(p.hand) do
      if #ids < 3 and not (c.kind == "black" and (c.effect == "mine" or ids.black)) then
        ids[#ids + 1] = c.id
        if c.kind == "black" then ids.black = true end
      end
    end
    ids.black = nil
    if #ids > 0 then add({ type = "contract", cardIds = ids }) end
  elseif ph == "fight_add" and not state.pending.responses[pid] and not p.eliminated then
    add({ type = "pass" })
    for _, c in ipairs(p.hand) do add({ type = "add_card", cardId = c.id }) end
  elseif ph == "fight_pick" and state.fight.attacker == pid then
    for i = 1, #state.field.submitted do add({ type = "pick_card", index = i }) end
  elseif ph == "contract_volunteer" and not state.pending.responses[pid] and not p.eliminated then
    add({ type = "pass" }); add({ type = "volunteer" })
  elseif ph == "contract_pick" and state.fight.contractor == pid then
    for _, v in ipairs(state.pending.volunteers) do add({ type = "pick_volunteer", pid = v }) end
  elseif ph == "fight_bonus" and state.fight.attacker == pid then
    add({ type = "roll" })
    for _, c in ipairs(p.hand) do
      if c.kind == "bonus" then
        for _, col in ipairs(colorsFor(state.fight)) do if col == c.color then add({ type = "play_bonus", cardId = c.id }) end end
      end
    end
    if p.potion then
      if p.potion.effect == "any_color" then for _, col in ipairs(Cards.COLORS) do add({ type = "use_potion", color = col }) end
      elseif p.potion.effect == "heal" and p.hp < p.maxHp then add({ type = "use_potion" }) end
    end
  elseif ph == "fight_destroy" and state.fight.attacker == pid then
    for _, i in ipairs(destructibleIndices(state)) do add({ type = "destroy_card", index = i }) end
  elseif ph == "fight_react" and not state.pending.responses[pid] and not p.eliminated then
    add({ type = "accept" })
    if p.rerollsUsed < rerollLimit(p) and fameCount(p) > 0 then add({ type = "reroll" }) end
    if state.fight.attacker == pid and p.potion and p.potion.effect == "extra_die" then add({ type = "use_potion" }) end
  elseif ph == "brawl_color" and state.brawl.a == pid then
    for _, col in ipairs(Cards.COLORS) do add({ type = "brawl_color", color = col }) end
  elseif ph == "brawl_bonus" and (state.brawl.a == pid or state.brawl.b == pid) and not state.brawl.ready[pid] then
    add({ type = "ready" })
    for _, c in ipairs(p.hand) do if c.kind == "bonus" and c.color == state.brawl.color then add({ type = "play_bonus", cardId = c.id }) end end
  end
  return out
end

-- Pierwsza (najbardziej neutralna) akcja – używana, gdy host pomija nieobecnego gracza.
function Rules.defaultAction(state, pid)
  return Rules.candidateActions(state, pid)[1]
end

return Rules
