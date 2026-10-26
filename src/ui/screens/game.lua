-- Ekran rozgrywki (pixel-art, 640x360). Czyta wyłącznie widok (view) z sesji i wysyła akcje
-- przez session:localAct. Zasada: stół jest czysty – na środku talie i Targowisko, przeciwnicy
-- jako wachlarze rewersów po bokach, własna ręka w wachlarzu na dole. Szczegóły pokazują dymki
-- po najechaniu myszą, a decyzje (walka, zlecenie, wybory) toczą się w modalach nad stołem.
local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local Art = require("src.ui.cardart")
local Anim = require("src.ui.anim")
local Audio = require("src.audio")
local Cards = require("src.game.cards")
local lg = love.graphics
local C = Theme.colors
local floor = math.floor

local G = {}
G.__index = G

local L = {
  top = 14,
  seat = { w = 112, h = 70, slots = { { 8, 20 }, { 520, 20 }, { 8, 96 }, { 520, 96 } } },
  decks = { y = 26, w = 52, h = 72, xs = { 220, 294, 368 }, names = { { "village", "Wioska" }, { "road", "Gościniec" }, { "market", "Targ" } } },
  market = { y = 138, w = 52, h = 72, xs = { 220, 294, 368 }, titleY = 124 },
  fameBtn = { x = 258, y = 230, w = 124, h = 16 },
  own = { x = 8, y = 284, w = 112, h = 70 },
  actions = { x = 520, y = 172, w = 112, h = 128 },
  arena = { x = 128, y = 20, w = 384, h = 272 },
  hand = { cw = 52, ch = 72, baseY = 322, hoverY = 238, selY = 284, cx = 320, maxSpread = 330 },
  preview = { w = 120, h = 166 },
  modal = { x = 120, y = 52, w = 400, h = 256 },
}
local DICE_X, DICE_Y = L.arena.x + 338, L.arena.y + 80
local FIGHT_PHASES = { encounter = true, fight_add = true, fight_pick = true, contract_volunteer = true, contract_pick = true,
  fight_bonus = true, fight_destroy = true, fight_react = true, brawl_color = true, brawl_bonus = true }

local function me(v) return v.players[v.me] end
local function nameOf(v, pid) return v.players[pid] and v.players[pid].name or "?" end
local function contains(list, val) for _, x in ipairs(list or {}) do if x == val then return true end end return false end

function G.new()
  local g = setmetatable({
    name = "game", lastSeq = -1, sel = {}, selOrder = {}, buttons = {}, modalButtons = {}, modalHit = {}, hover = nil, tip = nil,
    seenHand = {}, t = 0, actionsKey = nil, colorPick = nil, lingerUntil = 0, arenaSnap = nil, banner = nil,
    marketHit = {}, handHit = {}, fieldHit = {}, seatRects = {},
  }, G)
  Anim.reset()
  return g
end

function G:view() return App.session and App.session.view end

function G:act(action)
  local sess = App.session
  if not sess then return end
  local ok, err = sess:localAct(action)
  if ok == false and err then W.toast(err, "error") end
  self.sel, self.selOrder = {}, {}
  self.actionsKey = nil
end

function G:seatOf(v, pid)
  if pid == v.me then return L.own.x, L.own.y end
  local idx = 0
  for _, p in ipairs(v.players) do
    if p.id ~= v.me then
      idx = idx + 1
      if p.id == pid then local s = L.seat.slots[idx]; return s[1], s[2] end
    end
  end
  return 320, 160
end

-- ---------------------------------------------------------------- zdarzenia
function G:processEvents(v)
  for _, e in ipairs(v.events or {}) do
    local sx, sy = self:seatOf(v, e.pid or 0)
    local px, py = sx + 56, sy + 44
    if e.type == "roll" then
      Anim.rollDice(DICE_X, DICE_Y, e.value, e.pid); Audio.play("dice")
    elseif e.type == "fame" then
      Anim.float((e.delta > 0 and "+" or "−") .. "SŁAWA", px, py, C.gold, "smallB"); Audio.play(e.delta > 0 and "fame" or "hurt")
    elseif e.type == "coins" then
      Anim.float((e.delta > 0 and "+" or "") .. e.delta .. "¢", px, py + 10, C.coin, "smallB"); if e.delta > 0 then Audio.play("coin") end
    elseif e.type == "hp" then
      Anim.float((e.delta > 0 and "+" or "") .. e.delta .. "♥", px, py + 20, C.heart, "smallB")
      if e.delta < 0 then Audio.play("hurt"); Anim.shake = 4 end
    elseif e.type == "monster" or e.type == "reveal" or e.type == "event_card" or e.type == "black" then
      Audio.play("flip")
      if e.type == "monster" then Anim.pop("monster", 1.25); self.banner = nil end
    elseif e.type == "submit" or e.type == "bonus" or e.type == "draw" or e.type == "buy" then
      Audio.play("card")
      if e.type == "bonus" then Anim.pop("attacker") end
    elseif e.type == "fight_result" then
      Audio.play(e.win and "win" or "lose")
      self.banner = { text = e.win and "WYGRANA!" or "PRZEGRANA", color = e.win and C.gold or C.red, untilT = self.t + 2.4 }
    elseif e.type == "pool" then Anim.pop("pool")
    elseif e.type == "winner" then Audio.play("win")
    elseif e.type == "death" or e.type == "eliminated" then Audio.play("lose")
    elseif e.type == "destroy" then Audio.play("hurt"); Anim.shake = 3
    end
  end
  for _, c in ipairs(me(v).hand or {}) do
    if not self.seenHand[c.id] then
      self.seenHand[c.id] = true
      Anim.spawnAt(c.id, L.decks.xs[1], L.decks.y, 0.6)
    end
  end
end

function G:update(dt)
  self.t = self.t + dt
  local sess = App.session
  if not sess then App.setScreen("menu"); return end
  local v = self:view()
  if not v then return end
  if v.seq ~= self.lastSeq then
    self.lastSeq = v.seq
    self:processEvents(v)
    self.actionsKey = nil
    self.sel, self.selOrder = {}, {}
    self.colorPick = nil
  end
  if v.field.monster or v.brawl then
    self.arenaSnap = { fight = v.fight, field = v.field, brawl = v.brawl, seq = v.seq }
    self.lingerUntil = self.t + 2.4
  end
  if sess.lastError then W.toast(sess.lastError, "error"); sess.lastError = nil end
  if v.winner and not Anim.dice and self.t > self.lingerUntil then App.setScreen("gameover", v); return end
  if not sess:isHost() and sess.status == "error" then
    if not App.overlay or App.overlay.name ~= "disconnected" then App.openOverlay("disconnected") end
  end
  self:rebuildActions(v)
end

-- ------------------------------------------------------------- akcje
local function selectedCards(self, v)
  local out = {}
  for _, id in ipairs(self.selOrder) do
    for _, c in ipairs(me(v).hand or {}) do if c.id == id then out[#out + 1] = c end end
  end
  return out
end

function G:arenaActive(v)
  return FIGHT_PHASES[v.phase] and (v.field.monster ~= nil or v.brawl ~= nil)
end

function G:rebuildActions(v)
  local key = v.seq .. "|" .. table.concat(self.selOrder, ",") .. "|" .. tostring(self.colorPick)
  if self.actionsKey == key then return end
  self.actionsKey = key
  self.buttons, self.modalButtons, self.hint = {}, {}, nil
  local m = me(v)
  local myTurn = v.turn.player == v.me
  local sel = selectedCards(self, v)
  local one = sel[1]
  local function withSel(fn)
    return function()
      local c = selectedCards(self, self:view())[1]
      if not c then W.toast("Najpierw zaznacz kartę na ręce.", "error") return end
      fn(c)
    end
  end
  local inArena = self:arenaActive(v)
  local count = 0
  local function add(label, style, fn, enabled)
    local x, y
    if inArena then x = L.arena.x + 8 + (count % 3) * 124; y = L.arena.y + 212 + floor(count / 3) * 22
    else
      local hintH = self.hint and (Theme.textHeight(self.hint, "small", L.actions.w - 8) + 8) or 4
      x = L.actions.x + 4; y = L.actions.y + 4 + hintH + count * 22
    end
    count = count + 1
    local b = W.button({ x = x, y = y, w = inArena and 118 or 104, h = 16, label = label, style = style, onClick = fn, enabled = enabled ~= false })
    self.buttons[#self.buttons + 1] = b
    return b
  end
  local pr = v.prompt
  if pr and pr.pid == v.me then
    local mcount = 0
    local function madd(label, style, fn, enabled)
      local x = L.modal.x + 8 + (mcount % 3) * 130
      local y = L.modal.y + L.modal.h - 50 + floor(mcount / 3) * 22
      mcount = mcount + 1
      self.modalButtons[#self.modalButtons + 1] = W.button({ x = x, y = y, w = 124, h = 16, label = label, style = style, onClick = fn, enabled = enabled ~= false })
    end
    if pr.type == "equip_replace" then
      if pr.card.kind == "potion" then
        madd("Zastąp eliksir", "ok", function() self:act({ type = "equip_replace", choice = "replace" }) end)
        if pr.card.effect == "heal" then madd("Wypij od razu", "secondary", function() self:act({ type = "equip_replace", choice = "use_now" }) end, m.hp < m.maxHp) end
      else
        for _, w in ipairs(m.weapons) do madd("Odrzuć " .. w.name, "secondary", function() self:act({ type = "equip_replace", cardId = w.id }) end) end
      end
      madd("Odrzuć nową kartę", "danger", function() self:act({ type = "equip_replace", choice = "discard_new" }) end)
    elseif pr.type == "hyena" then
      local victim = v.players[pr.victim]
      madd("Miedziaki (" .. victim.coins .. ")", "ok", function() self:act({ type = "hyena", choice = "coins" }) end, victim.coins > 0)
      for _, w in ipairs(victim.weapons) do madd("Weź: " .. w.name, "secondary", function() self:act({ type = "hyena", choice = "equipment", cardId = w.id }) end) end
      if victim.hasPotion then madd("Zabierz eliksir", "secondary", function() self:act({ type = "hyena", choice = "equipment", cardId = "potion" }) end) end
      madd("Nic nie biorę", "danger", function() self:act({ type = "hyena", choice = "nothing" }) end)
    elseif pr.type == "healer" then
      madd("Sprzedaj (−1♥ +4¢)", "ok", function() self:act({ type = "healer", choice = "yes" }) end)
      madd("Odmów", "secondary", function() self:act({ type = "healer", choice = "no" }) end)
    elseif pr.type == "hog_target" then
      for _, p in ipairs(v.players) do
        if p.id ~= v.me and not p.eliminated then madd(p.name .. " (sława " .. p.fameCount .. ")", "secondary", function() self:act({ type = "hog_target", pid = p.id }) end) end
      end
    end
    return
  end
  if pr then self.hint = "Czekamy na decyzję: " .. nameOf(v, pr.pid) .. "…"; return end
  local ph = v.phase
  if ph == "setup" then
    local step = v.setup[v.me]
    if step == "swap" then
      self.hint = "Możesz wymienić 1 kartę: zaznacz ją na ręce i potwierdź, albo pomiń."
      add("Wymień zaznaczoną", "secondary", withSel(function(c) self:act({ type = "swap_card", cardId = c.id }) end), one ~= nil)
      add("Nie wymieniam", "ok", function() self:act({ type = "swap_card" }) end)
    elseif step == "done" then self.hint = "Czekamy, aż pozostali przygotują postacie…" end
    return
  end
  if ph == "market" and myTurn then
    self.hint = "Targowisko: kliknij kartę na środku, aby ją kupić. Potem dobierz kartę Wioski."
    add("Dobierz z Wioski", "ok", function() self:act({ type = "end_market" }) end)
    if m.potion and m.potion.effect == "heal" then add("Potjon (+1♥)", "secondary", function() self:act({ type = "use_potion" }) end, m.hp < m.maxHp) end
  elseif ph == "road_choice" and myTurn then
    self.hint = "Odkryj kartę Gościńca albo dobierz drugą kartę Wioski (koniec tury)."
    add("Odkryj Gościniec", "ok", function() self:act({ type = "reveal_road" }) end)
    add("2. karta Wioski", "secondary", function() self:act({ type = "draw_village" }) end)
  elseif ph == "encounter" and myTurn then
    self.hint = "Walczysz sam czy tworzysz zlecenie? Do zlecenia zaznacz 0–3 zakryte karty z ręki."
    add("WALKA!", "danger", function() self:act({ type = "fight" }) end)
    local ids = {}
    for _, c in ipairs(sel) do ids[#ids + 1] = c.id end
    add("ZLECENIE (" .. #ids .. ")", "primary", function() self:act({ type = "contract", cardIds = ids }) end, #ids <= 3)
  elseif ph == "fight_add" then
    if v.fight.attacker == v.me then self.hint = "Inni gracze decydują, czy dorzucić zakrytą kartę do potwora…"
    elseif not v.responses[v.me] and not m.eliminated then
      self.hint = nameOf(v, v.fight.attacker) .. " walczy. Dorzuć 1 zakrytą kartę (zaznacz na ręce) albo spasuj."
      add("Dorzuć kartę", "primary", withSel(function(c) self:act({ type = "add_card", cardId = c.id }) end), one ~= nil)
      add("Pas", "secondary", function() self:act({ type = "pass" }) end)
    else self.hint = "Czekamy na pozostałych graczy…" end
  elseif ph == "fight_pick" then
    if v.fight.attacker == v.me then self.hint = "Wybierz JEDNĄ z dorzuconych kart (kliknij ją). Reszta wraca do właścicieli."
    else self.hint = nameOf(v, v.fight.attacker) .. " wybiera jedną z dorzuconych kart…" end
  elseif ph == "contract_volunteer" then
    if v.fight.contractor == v.me then self.hint = "Czekamy, czy ktoś podejmie zlecenie…"
    elseif not v.responses[v.me] and not m.eliminated then
      self.hint = "Zlecenie od " .. nameOf(v, v.fight.contractor) .. ": " .. #v.field.submitted .. " zakrytych kart przy potworze. Walczysz?"
      add("Walczę!", "danger", function() self:act({ type = "volunteer" }) end)
      add("Pas", "secondary", function() self:act({ type = "pass" }) end)
    else self.hint = "Czekamy na pozostałych graczy…" end
  elseif ph == "contract_pick" then
    if v.fight.contractor == v.me then
      self.hint = "Kilku chętnych – wybierz, kto walczy:"
      for _, pid in ipairs(v.volunteers) do add(nameOf(v, pid), "primary", function() self:act({ type = "pick_volunteer", pid = pid }) end) end
    else self.hint = nameOf(v, v.fight.contractor) .. " wybiera ochotnika…" end
  elseif ph == "fight_bonus" then
    if v.fight.attacker == v.me then
      self.hint = "Zagraj premie z ręki (w kolorze potwora), użyj eliksiru i rzuć kością."
      add("RZUĆ KOŚCIĄ", "danger", function() self:act({ type = "roll" }) end)
      local okBonus = one and one.kind == "bonus" and (one.color == v.fight.color or one.color == v.fight.extraColor)
      add("Zagraj premię", "primary", withSel(function(c) self:act({ type = "play_bonus", cardId = c.id }) end), okBonus)
      if m.potion then
        if m.potion.effect == "any_color" then add("Wypij Wilka", "secondary", function() self.colorPick = "wilk"; self.actionsKey = nil end)
        elseif m.potion.effect == "heal" then add("Potjon (+1♥)", "secondary", function() self:act({ type = "use_potion" }) end, m.hp < m.maxHp) end
      end
    else self.hint = nameOf(v, v.fight.attacker) .. " przygotowuje się do rzutu…" end
  elseif ph == "fight_destroy" then
    if v.fight.attacker == v.me then self.hint = "Ikona niszczenia! Kliknij kartę przy potworze, którą niszczysz."
    else self.hint = nameOf(v, v.fight.attacker) .. " wybiera kartę do zniszczenia…" end
  elseif ph == "fight_react" then
    if not v.responses[v.me] and not m.eliminated then
      self.hint = "Wynik: " .. tostring(v.fight.roll) .. (v.fight.extraRoll and (" + " .. v.fight.extraRoll) or "") .. ". Akceptujesz, czy anulujesz rzut za punkt sławy?"
      add("Akceptuj rzut", "ok", function() self:act({ type = "accept" }) end)
      add("Przerzuć (−1★)", "danger", function() self:act({ type = "reroll" }) end, m.rerollsUsed < m.rerollLimit and m.fameCount > 0)
      if v.fight.attacker == v.me and m.potion and m.potion.effect == "extra_die" then add("Dzik (+kość)", "secondary", function() self:act({ type = "use_potion" }) end) end
    else self.hint = "Czekamy, czy ktoś anuluje rzut…" end
  elseif ph == "brawl_color" then
    if v.brawl.a == v.me then
      self.hint = "Ustawka! Wybierz kolor walki między graczami."
      for _, col in ipairs(Cards.COLORS) do add(Cards.COLOR_LABEL[col], "secondary", function() self:act({ type = "brawl_color", color = col }) end) end
    else self.hint = nameOf(v, v.brawl.a) .. " wybiera kolor Ustawki…" end
  elseif ph == "brawl_bonus" then
    local inBrawl = v.brawl.a == v.me or v.brawl.b == v.me
    local ready = (v.brawl.a == v.me and v.brawl.readyA) or (v.brawl.b == v.me and v.brawl.readyB)
    if inBrawl and not ready then
      self.hint = "Ustawka w kolorze " .. Cards.COLOR_LABEL[v.brawl.color] .. ". Dorzuć premie z ręki i kliknij „Gotowy”."
      add("Zagraj premię", "primary", withSel(function(c) self:act({ type = "play_bonus", cardId = c.id }) end), one and one.kind == "bonus" and one.color == v.brawl.color)
      add("Gotowy!", "ok", function() self:act({ type = "ready" }) end)
    else self.hint = "Ustawka: " .. nameOf(v, v.brawl.a) .. " vs " .. nameOf(v, v.brawl.b) .. "…" end
  elseif not contains(v.waitingFor, v.me) then
    local names = {}
    for _, pid in ipairs(v.waitingFor) do names[#names + 1] = nameOf(v, pid) end
    self.hint = "Czekamy na: " .. table.concat(names, ", ")
  end
  local sess = App.session
  if sess and sess:isHost() then
    for _, pid in ipairs(v.waitingFor) do
      local hp = sess.players[pid]
      if hp and not hp.connected then add("Pomiń: " .. hp.name, "danger", function() local ok, err = sess:skipPlayer(pid); if not ok and err then W.toast(err, "error") end end) end
    end
  end
  if self.colorPick == "wilk" then
    self.buttons, count = {}, 0
    self.hint = "Wilk: który dodatkowy kolor ma się liczyć w tej walce?"
    for _, col in ipairs(Cards.COLORS) do add(Cards.COLOR_LABEL[col], "secondary", function() self.colorPick = nil; self:act({ type = "use_potion", color = col }) end) end
    add("Anuluj", "danger", function() self.colorPick = nil; self.actionsKey = nil end)
  end
end

-- ------------------------------------------------------------ rysowanie
local PHASE_LABEL = {
  market = "Targowisko", road_choice = "Wioska / Gościniec", encounter = "Spotkanie", fight_add = "Walka – dorzucanie",
  fight_pick = "Walka – wybór karty", contract_volunteer = "Zlecenie – kto walczy?", contract_pick = "Zlecenie – wybór",
  fight_bonus = "Walka – premie", fight_destroy = "Niszczenie karty", fight_react = "Walka – rzut", brawl_color = "Ustawka – kolor",
  brawl_bonus = "Ustawka – premie", finished = "Koniec gry", setup = "Przygotowanie",
}

function G:drawTopBar(v)
  lg.setColor(C.panel); lg.rectangle("fill", 0, 0, Theme.VW, L.top)
  lg.setColor(C.panelEdge); lg.line(0, L.top + 0.5, Theme.VW, L.top + 0.5)
  local s = (v.phase == "setup") and "Przygotowanie: wybór postaci" or ("Tura: " .. nameOf(v, v.turn.player) .. "  •  " .. (PHASE_LABEL[v.phase] or v.phase))
  Theme.text(s, 6, 1, { font = "body", color = C.cream })
  local last = v.log and v.log[#v.log] or ""
  Theme.text(Theme.fit(last, "small", 300), 190, 1, { font = "small", color = C.creamDark })
  local sess = App.session
  local netTxt = sess:isHost() and ("HOST :" .. sess.port) or ("klient • " .. (sess.status == "game" and "ok" or sess.status))
  Theme.text(netTxt, 500, 1, { font = "small", color = C.inkSoft, width = 134, align = "right" })
end

-- miejsce przeciwnika: wachlarz rewersów + plakietka z imieniem
function G:drawSeat(v, p, x, y, mx, my)
  local w, h = L.seat.w, L.seat.h
  local waiting = contains(v.waitingFor, p.id)
  local active = v.turn.player == p.id
  local n = p.handCount
  local cw, ch = 26, 36
  local step = n > 1 and math.min(12, (w - cw - 8) / (n - 1)) or 0
  local total = cw + step * math.max(0, n - 1)
  local x0 = x + (w - total) / 2
  for i = 1, n do
    local off = i - (n + 1) / 2
    local cx, cy = floor(x0 + (i - 1) * step), y + 4 + floor(math.abs(off) * 0.8)
    lg.push(); lg.translate(cx + cw / 2, cy + ch / 2); lg.rotate(off * 0.06)
    Art.drawBack("village", -cw / 2, -ch / 2, cw, ch, {})
    lg.pop()
  end
  if n == 0 then Theme.centerText("(bez kart)", x + w / 2, y + 22, { font = "small", color = C.creamDark }) end
  -- plakietka
  local tagW = w - 8
  local tagX, tagY = x + 4, y + h - 18
  lg.setColor(C.shadow); lg.rectangle("fill", tagX, tagY + 2, tagW, 16, 3, 3)
  lg.setColor(waiting and C.highlight or (active and C.gold or C.panel)); lg.rectangle("fill", tagX, tagY, tagW, 16, 3, 3)
  lg.setColor(C.ink); lg.rectangle("line", tagX + 0.5, tagY + 0.5, tagW - 1, 15, 3, 3)
  local label = p.name
  if p.eliminated then label = label .. " ✕" end
  local lcol = (waiting or active) and C.ink or C.cream
  Theme.text(Theme.fit(label, "tinyB", tagW - 22), tagX + 4, tagY + 3, { font = "tinyB", color = lcol, shadow = false })
  -- mały status po prawej: serca jako kropki
  for i = 1, p.maxHp do
    lg.setColor(i <= p.hp and C.heart or Theme.rgb("#4a3a3a")); lg.rectangle("fill", tagX + tagW - 4 - (p.maxHp - i + 1) * 4, tagY + 6, 3, 3)
  end
  if waiting then Theme.text("…", tagX + tagW - 22, tagY + 1, { font = "smallB", color = C.ink, shadow = false }) end
  local sess = App.session
  if sess:isHost() and sess.players[p.id] and not sess.players[p.id].connected then
    Theme.text("OFFLINE", x + w - 44, y + 2, { font = "tinyB", color = C.btnDanger })
  end
  self.seatRects[#self.seatRects + 1] = { x = x, y = y, w = w, h = h, p = p }
  if Theme.hit(mx, my, x, y, w, h) then self.tip = { kind = "player", p = p, x = (x < 320) and (x + w + 4) or (x - 154), y = y } end
end

local function strengthChips(v, p, x, y)
  for _, colName in ipairs(Cards.COLORS) do
    local b = (p.char.bonus[colName] or 0)
    for i = 1, 6, 2 do if Cards.FAME_RING[i] == colName and p.fame[i] and p.fame[i + 1] then b = b + 1 end end
    for _, w in ipairs(p.weapons) do b = b + (w.bonus[colName] or 0) end
    lg.setColor(Theme.colorOf[colName]); lg.rectangle("fill", x, y, 12, 12, 2, 2)
    lg.setColor(C.ink); lg.rectangle("line", x + 0.5, y + 0.5, 11, 11, 2, 2)
    Theme.centerText(tostring(b), x + 6, y + 6, { font = "small", color = C.white })
    x = x + 14
  end
end

local function equipChips(p, x, y, mx, my, self)
  for _, wpn in ipairs(p.weapons) do
    local cols = {}
    for _, c in ipairs(Cards.COLORS) do if wpn.bonus[c] then cols[#cols + 1] = c end end
    for k, c in ipairs(cols) do lg.setColor(Theme.colorOf[c]); lg.rectangle("fill", x + (k - 1) * floor(12 / #cols), y, floor(12 / #cols), 8) end
    lg.setColor(C.ink); lg.rectangle("line", x + 0.5, y + 0.5, 11, 7)
    if mx and Theme.hit(mx, my, x, y, 12, 8) then self.hover = { card = wpn, x = x + 14, y = y - 80 } end
    x = x + 15
  end
  if p.hasPotion then
    lg.setColor(C.purple); lg.circle("fill", x + 4, y + 4, 4, 6); lg.setColor(C.ink); lg.circle("line", x + 4, y + 4, 4, 6)
    if mx and p.potion and Theme.hit(mx, my, x, y, 9, 9) then self.hover = { card = p.potion, x = x + 14, y = y - 80 } end
    x = x + 13
  end
  return x
end

-- własny panel: portret + serca + sława + miedziaki (szczegóły w dymku)
function G:drawOwn(v, mx, my)
  local p = me(v)
  local o = L.own
  local waiting = contains(v.waitingFor, p.id)
  Theme.panel(o.x, o.y, o.w, o.h, { fill = C.panelLight, border = waiting and C.highlight or (v.turn.player == p.id and C.gold or C.panelEdge), lineWidth = waiting and 2 or 1 })
  Art.drawPortrait(p.char, o.x + 4, o.y + 4, 2)
  Theme.text(Theme.fit(p.name, "tinyB", 66), o.x + 44, o.y + 4, { font = "tinyB", color = C.gold })
  Theme.text(Theme.fit(p.char.name, "small", 66), o.x + 44, o.y + 15, { font = "small", color = C.creamDark })
  for i = 1, p.maxHp do Theme.heart(o.x + 49 + (i - 1) * 9, o.y + 31, 3, i <= p.hp and C.heart or Theme.rgb("#4a3a3a")) end
  Theme.star(o.x + 49, o.y + 46, 4, C.star); Theme.text(tostring(p.fameCount), o.x + 55, o.y + 40, { font = "body", color = C.cream })
  Theme.coin(o.x + 74, o.y + 46, 3); Theme.text(tostring(p.coins), o.x + 80, o.y + 40, { font = "body", color = C.cream })
  equipChips(p, o.x + 6, o.y + 44 + 12, mx, my, self)
  strengthChips(v, p, o.x + 46, o.y + 54)
  if Theme.hit(mx, my, o.x, o.y, 44, 44) then self.tip = { kind = "player", p = p, x = o.x + o.w + 4, y = o.y - 40 } end
end

function G:drawCenter(v, mx, my)
  -- talie
  for i, d in ipairs(L.decks.names) do
    local x = L.decks.xs[i]
    local info = v.decks[d[1]]
    local hov = Theme.hit(mx, my, x, L.decks.y, L.decks.w, L.decks.h)
    for k = math.min(3, math.max(1, floor(info.draw / 12))), 1, -1 do
      Art.drawBack(d[1], x + k - 1, L.decks.y - (k - 1) * 2, L.decks.w, L.decks.h, { highlight = (hov and k == 1) and C.highlight or nil })
    end
    Theme.centerText(d[2] .. " " .. info.draw, x + L.decks.w / 2, L.decks.y + L.decks.h + 8, { font = "small", color = C.creamDark })
    if hov then self.tip = { kind = "deck", name = d[2], info = info, x = x + L.decks.w + 6, y = L.decks.y } end
  end
  -- targowisko
  Theme.centerText("TARGOWISKO", 320, L.market.titleY, { font = "tinyB", color = C.gold })
  local m = me(v)
  local myTurn = v.turn.player == v.me and v.phase == "market" and not v.prompt
  self.marketHit = {}
  for i = 1, 3 do
    local card = v.marketRow[i]
    local x, y = L.market.xs[i], L.market.y
    self.marketHit[i] = { x = x, y = y, w = L.market.w, h = L.market.h }
    if card then
      local hov = Theme.hit(mx, my, x, y, L.market.w, L.market.h)
      local can = myTurn and m.coins >= card.price
      Art.draw(card, x, y - (hov and 3 or 0), L.market.w, L.market.h, { dim = myTurn and not can, highlight = (hov and can) and C.highlight or nil })
      Theme.centerText(card.price .. " ¢", x + L.market.w / 2, y + L.market.h + 8, { font = "body", color = C.gold })
      if hov then self.hover = { card = card, x = x + L.market.w + 6, y = y - 50 } end
    else
      lg.setColor(C.inkSoft); lg.rectangle("line", x + 0.5, y + 0.5, L.market.w - 1, L.market.h - 1, 4, 4)
    end
  end
  if not self.fameButton then
    self.fameButton = W.button({ x = L.fameBtn.x, y = L.fameBtn.y, w = L.fameBtn.w, h = L.fameBtn.h, label = "Kup 1 sławę (4¢)", style = "primary", onClick = function() self:act({ type = "buy_fame" }) end })
  end
  self.fameButton.enabled = myTurn and m.coins >= Cards.FAME_PRICE and not v.turn.fameBought and m.fameCount < 6
  self.fameButton:draw()
  if v.field.guardedCards > 0 then Theme.centerText("Strzeżone miedziaki ×" .. v.field.guardedCards .. " czekają na potwora", 320, L.fameBtn.y + 26, { font = "small", color = C.gold }) end
end

function G:drawRight(v)
  local a = L.actions
  Theme.panel(a.x, a.y, a.w, a.h, { fill = C.panel })
  if not self:arenaActive(v) then
    if self.hint then Theme.text(self.hint, a.x + 4, a.y + 4, { font = "small", color = C.cream, width = a.w - 8 }) end
    for _, b in ipairs(self.buttons) do b:draw() end
  else
    Theme.text("Trwa walka – decyzje w arenie.", a.x + 4, a.y + 4, { font = "small", color = C.creamDark, width = a.w - 8 })
  end
end

function G:drawArena(v, snap, live, mx, my)
  local a = L.arena
  local ft, field, brawl = snap.fight, snap.field, snap.brawl
  local mon = field.monster
  lg.setColor(C.dim); lg.rectangle("fill", 0, L.top, Theme.VW, Theme.VH - L.top)
  Theme.panel(a.x, a.y, a.w, a.h, { fill = Theme.rgb("#1c2130"), border = C.gold, radius = 6, shadow = 3 })
  local title = brawl and "USTAWKA" or (ft and ft.mode == "contract" and "ZLECENIE" or "WALKA")
  if mon then title = title .. "  •  " .. nameOf(v, ft and (ft.attacker or ft.contractor) or v.turn.player) .. " vs " .. mon.name end
  Theme.text(title, a.x + 8, a.y + 4, { font = "smallB", color = C.gold })
  self.fieldHit = {}
  if mon then
    local mx0, my0, mw, mh = a.x + 10, a.y + 24, 84, 116
    local ps = Anim.popScale("monster")
    lg.push(); lg.translate(mx0 + mw / 2, my0 + mh / 2); lg.scale(ps, ps)
    Art.draw(mon, -mw / 2, -mh / 2, mw, mh, {})
    lg.pop()
    if Theme.hit(mx, my, mx0, my0, mw, mh) then self.hover = { card = mon, x = mx0 + mw + 6, y = my0 } end
    if ft and ft.monsterStrength then
      local sp = Anim.popScale("attacker")
      Theme.text("SIŁA", a.x + 10, a.y + 144, { font = "tinyB", color = Theme.colorOf[mon.color] })
      Theme.text(tostring(ft.monsterStrength), a.x + 40, a.y + 138, { font = "titleB", color = Theme.colorOf[mon.color] })
      if ft.attacker and ft.attackerBase then
        local total = ft.attackerBase + (type(ft.roll) == "number" and ft.roll or 0) + (ft.extraRoll or 0)
        local txt = nameOf(v, ft.attacker) .. ": " .. ft.attackerBase .. (ft.roll and (" + kość " .. tostring(ft.roll) .. (ft.extraRoll and (" + " .. ft.extraRoll) or "") .. " = " .. total) or " + kość")
        lg.push(); lg.translate(a.x + 10, a.y + 170); lg.scale(sp, sp)
        Theme.text(txt, 0, 0, { font = "body", color = C.cream })
        lg.pop()
      end
    end
    local poolFame = mon.fame + field.pledgedFame
    local poolCoins = mon.coins + 2 * field.guardedCards
    local px = a.x + a.w - 120
    Theme.text("Pula:", px, a.y + 6, { font = "small", color = C.creamDark })
    local ix = px + 30
    local pp = Anim.popScale("pool")
    for _ = 1, poolFame do Theme.star(ix + 4, a.y + 12, 4 * pp, C.star); ix = ix + 11 end
    for _ = 1, poolCoins do Theme.coin(ix + 4, a.y + 12, 3 * pp); ix = ix + 10 end
    if ft and ft.extraColor then Theme.text("Wilk: +" .. Cards.COLOR_LABEL[ft.extraColor], a.x + 112, a.y + 6, { font = "small", color = C.gold }) end
    local sub = field.submitted
    local pickable = live and v.phase == "fight_pick" and ft.attacker == v.me
    local destroyable = live and v.phase == "fight_destroy" and ft.attacker == v.me
    if #sub > 0 then Theme.text("Karty przy potworze:", a.x + 112, a.y + 20, { font = "small", color = C.creamDark }) end
    for i, e in ipairs(sub) do
      local x, y, w, h = a.x + 112 + (i - 1) * 50, a.y + 32, 44, 60
      local hov = Theme.hit(mx, my, x, y, w, h)
      local counted
      if ft and ft.counted then for _, ce in ipairs(ft.counted) do if e.card and ce.card.id == e.card.id then counted = ce end end end
      if e.card and e.revealed then
        Art.draw(e.card, x, y - (hov and 2 or 0), w, h, { highlight = (destroyable and counted and hov) and C.highlight or nil, dim = ft and ft.counted and not counted and e.card.kind ~= "black" })
        if hov then self.hover = { card = e.card, x = x + w + 4, y = y - 20 } end
        if counted then Theme.centerText("+" .. counted.power, x + w - 8, y + 6, { font = "tinyB", color = C.white }) end
      elseif e.card then
        Art.draw(e.card, x, y, w, h, {})
        Theme.centerText("zakryta", x + w / 2, y + h - 6, { font = "tinyB", color = C.gold })
        if hov then self.hover = { card = e.card, x = x + w + 4, y = y - 20 } end
      else
        Art.drawBack("village", x, y - (hov and pickable and 2 or 0), w, h, { highlight = (pickable and hov) and C.highlight or nil })
      end
      Theme.centerText(Theme.fit(nameOf(v, e.owner), "small", 48), x + w / 2, y + h + 6, { font = "small", color = C.cream })
      self.fieldHit[#self.fieldHit + 1] = { x = x, y = y, w = w, h = h, index = i, counted = counted }
    end
    if ft and ft.bonuses and #ft.bonuses > 0 then
      Theme.text("Premie " .. nameOf(v, ft.attacker) .. ":", a.x + 112, a.y + 106, { font = "small", color = C.creamDark })
      for i, c in ipairs(ft.bonuses) do
        local x, y = a.x + 112 + (i - 1) * 34, a.y + 118
        Art.draw(c, x, y, 30, 42, {})
        if Theme.hit(mx, my, x, y, 30, 42) then self.hover = { card = c, x = x + 34, y = y - 60 } end
      end
    end
  end
  if brawl then
    local b = brawl
    Theme.panel(a.x + 112, a.y + 24, 210, 70, { fill = C.panel })
    Theme.text("USTAWKA" .. (b.color and (" – " .. Cards.COLOR_LABEL[b.color]) or ""), a.x + 118, a.y + 28, { font = "smallB", color = C.gold })
    Theme.text(nameOf(v, b.a) .. ": siła " .. tostring(b.strengthA or "?") .. " + kość  (" .. #b.bonusesA .. " premii)" .. (b.readyA and " ✓" or ""), a.x + 118, a.y + 46, { font = "small", color = C.cream })
    Theme.text(nameOf(v, b.b) .. ": siła " .. tostring(b.strengthB or "?") .. " + kość  (" .. #b.bonusesB .. " premii)" .. (b.readyB and " ✓" or ""), a.x + 118, a.y + 62, { font = "small", color = C.cream })
  end
  local d = Anim.dice
  if d then
    Theme.die(d.x, d.y, 34, d.show, d.rot, d.sq)
    Theme.centerText(nameOf(v, d.pid), d.x, d.y + 28, { font = "small", color = C.cream })
  elseif ft and ft.roll then
    Theme.die(DICE_X, DICE_Y, 34, ft.roll)
    if ft.extraRoll then Theme.die(DICE_X, DICE_Y + 44, 26, ft.extraRoll) end
  end
  if live then
    if self.hint then Theme.text(self.hint, a.x + 8, a.y + 184, { font = "small", color = C.cream, width = a.w - 16 }) end
    for _, b in ipairs(self.buttons) do b:draw() end
  end
  if self.banner and self.t < self.banner.untilT then
    local left = self.banner.untilT - self.t
    local k = math.min(1, left / 0.3)
    local sc = 1 + math.max(0, 1 - (2.4 - left) * 4) * 0.6
    lg.push(); lg.translate(a.x + a.w / 2, a.y + 100); lg.scale(sc, sc)
    Theme.centerText(self.banner.text, 0, 0, { font = "hugeB", color = { self.banner.color[1], self.banner.color[2], self.banner.color[3], k } })
    lg.pop()
  end
end

function G:handLayout(v)
  local hand = me(v).hand or {}
  local n = #hand
  local cw = L.hand.cw
  local spread = n > 1 and math.min(L.hand.maxSpread, (n - 1) * 44) or 0
  local step = n > 1 and spread / (n - 1) or 0
  local out = {}
  for i, c in ipairs(hand) do
    local off = i - (n + 1) / 2
    out[i] = { card = c, x = floor(L.hand.cx - spread / 2 + (i - 1) * step - cw / 2), y = L.hand.baseY + floor(math.abs(off) * 1.5), rot = off * 0.035 }
  end
  return out
end

function G:drawHand(v, mx, my)
  local layout = self:handLayout(v)
  local cw, ch = L.hand.cw, L.hand.ch
  local hovIdx
  for i = #layout, 1, -1 do
    local it = layout[i]
    local vis = Anim.cardVisual(it.card.id, it.x, it.y, 1, it.rot)
    if not hovIdx and Theme.hit(mx, my, vis.x, vis.y, cw, Theme.VH - vis.y) then hovIdx = i end
  end
  self.handHit = {}
  local hovered
  for i, it in ipairs(layout) do
    local selected = self.sel[it.card.id]
    local ty, tr = it.y, it.rot
    if hovIdx == i then ty, tr = L.hand.hoverY, 0 elseif selected then ty = L.hand.selY end
    local vis = Anim.cardVisual(it.card.id, it.x, ty, 1, tr)
    self.handHit[i] = { x = vis.x, y = vis.y, w = cw, h = ch, card = it.card }
    if hovIdx ~= i then
      lg.push(); lg.translate(floor(vis.x + cw / 2), floor(vis.y + ch / 2)); lg.rotate(vis.r)
      Art.draw(it.card, -cw / 2, -ch / 2, cw, ch, { selected = selected })
      lg.pop()
    else hovered = { it = it, vis = vis, selected = selected } end
  end
  if hovered then
    local vis = hovered.vis
    local tilt = ((mx - (vis.x + cw / 2)) / cw) * 0.12
    lg.push(); lg.translate(floor(vis.x + cw / 2), floor(vis.y + ch / 2)); lg.rotate(tilt)
    Art.draw(hovered.it.card, -cw / 2, -ch / 2, cw, ch, { selected = hovered.selected, highlight = C.highlight })
    lg.pop()
    self.hover = { card = hovered.it.card, x = vis.x + cw / 2 - L.preview.w / 2, y = L.hand.hoverY - L.preview.h - 4 }
  end
  if #layout == 0 then Theme.centerText("(brak kart na ręce)", L.hand.cx, L.hand.baseY + 10, { font = "small", color = C.creamDark }) end
end

-- ------------------------------------------------------------------ dymki
local function tooltipPanel(x, y, w, h)
  x = math.max(4, math.min(Theme.VW - w - 4, floor(x)))
  y = math.max(L.top + 2, math.min(Theme.VH - h - 4, floor(y)))
  Theme.panel(x, y, w, h, { fill = C.panel, border = C.gold, radius = 4, shadow = 3 })
  return x, y
end

function G:drawPlayerTip(v, p, tx, ty)
  local w, h = 150, 118
  local x, y = tooltipPanel(tx, ty, w, h)
  Art.drawPortrait(p.char, x + 4, y + 4, 2)
  Theme.text(p.name .. (p.id == v.me and " (Ty)" or ""), x + 44, y + 4, { font = "tinyB", color = C.gold })
  Theme.text(p.char.name .. " • " .. p.char.job, x + 44, y + 15, { font = "small", color = C.creamDark, width = w - 48 })
  for i = 1, p.maxHp do Theme.heart(x + 49 + (i - 1) * 9, y + 31, 3, i <= p.hp and C.heart or Theme.rgb("#4a3a3a")) end
  Theme.coin(x + 92, y + 31, 3); Theme.text(tostring(p.coins), x + 98, y + 25, { font = "body", color = C.cream })
  if p.id ~= v.me then
    lg.setColor(C.creamDark); lg.rectangle("fill", x + 116, y + 27, 6, 8, 1, 1); lg.setColor(C.ink); lg.rectangle("line", x + 116.5, y + 27.5, 5, 7, 1, 1)
    Theme.text("×" .. p.handCount, x + 124, y + 25, { font = "body", color = C.cream })
  end
  -- pierścień sławy
  Art.drawFameRing(x + 24, y + 70, 13, p.fame)
  Theme.text("Sława " .. p.fameCount .. "/7", x + 4, y + 94, { font = "small", color = C.gold })
  Theme.text("siła:", x + 48, y + 44, { font = "small", color = C.creamDark })
  strengthChips(v, p, x + 72, y + 42)
  Theme.text("sprzęt:", x + 48, y + 59, { font = "small", color = C.creamDark })
  local ex = equipChips(p, x + 80, y + 59)
  if ex == x + 80 then Theme.text("brak", x + 80, y + 59, { font = "small", color = C.inkSoft }) end
  Theme.text(p.char.traitText, x + 48, y + 72, { font = "small", color = C.cream, width = w - 52 })
  if p.eliminated then Theme.text("ODPADŁ Z GRY", x + 48, y + 104, { font = "tinyB", color = C.btnDanger }) end
end

function G:drawDeckTip(tip)
  local w, h = 150, 84
  local x, y = tooltipPanel(tip.x, tip.y, w, h)
  Theme.text(tip.name, x + 6, y + 4, { font = "tinyB", color = C.gold })
  Theme.text("W talii: " .. tip.info.draw .. "\nOdrzucone: " .. tip.info.discard, x + 6, y + 18, { font = "small", color = C.cream })
  if tip.info.top then
    Theme.text("ostatnio odrzucona:", x + 6, y + 44, { font = "small", color = C.creamDark })
    Art.draw(tip.info.top, x + w - 50, y + 4, 44, 60, {})
    Theme.text(Theme.fit(tip.info.top.name, "small", 80), x + 6, y + 56, { font = "small", color = C.cream })
  else
    Theme.text("stos odrzuconych pusty", x + 6, y + 44, { font = "small", color = C.creamDark })
  end
end

function G:drawTips(v)
  local hv = self.hover
  if hv and hv.card then
    local x = math.max(4, math.min(Theme.VW - L.preview.w - 4, floor(hv.x or 260)))
    local y = math.max(L.top + 2, math.min(Theme.VH - L.preview.h - 4, floor(hv.y or 60)))
    Art.draw(hv.card, x, y, L.preview.w, L.preview.h, {})
  elseif self.tip then
    if self.tip.kind == "player" then self:drawPlayerTip(v, self.tip.p, self.tip.x, self.tip.y)
    elseif self.tip.kind == "deck" then self:drawDeckTip(self.tip) end
  end
end

function G:drawModal(v, mx, my)
  local pr = v.prompt
  local step = v.phase == "setup" and v.setup[v.me]
  local m = me(v)
  local full = (pr and pr.pid == v.me and pr.type ~= "hyena" and pr.type ~= "healer" and pr.type ~= "hog_target") or step == "character" or step == "fame"
  local half = pr and pr.pid == v.me and (pr.type == "hyena" or pr.type == "healer" or pr.type == "hog_target")
  self.modalHit = {}
  if not full and not half then return end
  lg.setColor(C.dim); lg.rectangle("fill", 0, 0, Theme.VW, Theme.VH)
  local px, py, pw, ph = L.modal.x, L.modal.y, L.modal.w, L.modal.h
  Theme.panel(px, py, pw, ph, { fill = C.panel, border = C.gold })
  if step == "character" then
    Theme.centerText("Wybierz postać (druga będzie zapasową)", px + pw / 2, py + 14, { font = "largeB", color = C.gold })
    for i, ch in ipairs({ m.char, m.backup }) do
      local x = px + 70 + (i - 1) * 160
      local hov = Theme.hit(mx, my, x, py + 34, 100, 136)
      Art.drawCharacter(ch, x, py + 34 - (hov and 3 or 0), 100, 136, { selected = hov })
      self.modalHit[#self.modalHit + 1] = { x = x, y = py + 34, w = 100, h = 136, action = { type = "choose_character", index = i } }
    end
    Theme.centerText("Zdrowie 3 (Onufry 4) • Sława 1 (Gienek 2) • Miedziaki 1 (Alojz 3, Gienek 0)", px + pw / 2, py + 196, { font = "small", color = C.creamDark, width = pw - 20 })
  elseif step == "fame" or (pr and (pr.type == "fame_slot" or pr.type == "fame_remove")) then
    local removing = pr and pr.type == "fame_remove"
    Theme.centerText(removing and ("Tracisz punkt sławy (" .. (pr.reason or "") .. "). Który żeton zdejmujesz?") or "Połóż żeton sławy obok pozostałych (bez przerwy)", px + pw / 2, py + 16, { font = "smallB", color = C.gold, width = pw - 20 })
    local cx, cy, R = px + pw / 2, py + 118, 40
    local legal = removing and pr.slots or m.legalFameSlots
    Art.drawFameRing(cx, cy, R, m.fame, { legal = (not removing) and legal or nil, removable = removing and legal or nil })
    for _, s in ipairs(legal) do
      local sx, sy, sr = Art.fameSlotPos(cx, cy, R, s)
      local act = step == "fame" and { type = "setup_fame_slot", slot = s } or { type = pr.type, slot = s }
      self.modalHit[#self.modalHit + 1] = { x = sx - sr, y = sy - sr, w = sr * 2, h = sr * 2, action = act }
    end
    Theme.centerText("2 żetony w jednym kolorze = +1 siły w tym kolorze. 7. żeton (korona) wygrywa grę.", px + pw / 2, py + 212, { font = "small", color = C.creamDark, width = pw - 20 })
  elseif pr.type == "equip_replace" then
    Theme.centerText("Pełny ekwipunek – co robisz z kartą " .. pr.card.name .. "?", px + pw / 2, py + 16, { font = "smallB", color = C.gold, width = pw - 20 })
    Art.draw(pr.card, px + pw / 2 - 42, py + 34, 84, 116, {})
    for _, b in ipairs(self.modalButtons) do b:draw() end
  elseif pr.type == "seer" then
    Theme.centerText("Wiejski Dziad: wybierz kartę, która zostanie na wierzchu Gościńca", px + pw / 2, py + 16, { font = "smallB", color = C.gold, width = pw - 20 })
    for i, c in ipairs(pr.cards or {}) do
      local x = px + 60 + (i - 1) * 100
      local hov = Theme.hit(mx, my, x, py + 40, 84, 116)
      Art.draw(c, x, py + 40 - (hov and 3 or 0), 84, 116, { selected = hov })
      self.modalHit[#self.modalHit + 1] = { x = x, y = py + 40, w = 84, h = 116, action = { type = "seer", cardId = c.id } }
    end
  elseif half then
    local titles = { hyena = "Hiena: atakujący przegrał – co zabierasz?", healer = "Znachor: sprzedaj narządy za 4 miedziaki (tracisz 1 zdrowie)?", hog_target = "Wieprz! Tracisz 1 sławę – komu ją oddajesz?" }
    Theme.centerText(titles[pr.type], px + pw / 2, py + 40, { font = "smallB", color = C.gold, width = pw - 20 })
    for _, b in ipairs(self.modalButtons) do b:draw() end
  end
end

function G:draw()
  local v = self:view()
  if not v then
    Theme.centerText("Oczekiwanie na stan gry…", Theme.VW / 2, Theme.VH / 2, { font = "largeB", color = C.cream })
    return
  end
  local mx, my = Theme.toVirtual(love.mouse.getPosition())
  self.hover, self.tip, self.seatRects = nil, nil, {}
  self:drawTopBar(v)
  local idx = 0
  for _, p in ipairs(v.players) do
    if p.id ~= v.me then
      idx = idx + 1
      local s = L.seat.slots[idx]
      if s then self:drawSeat(v, p, s[1], s[2], mx, my) end
    end
  end
  self:drawCenter(v, mx, my)
  self:drawOwn(v, mx, my)
  self:drawRight(v)
  if self:arenaActive(v) and self.arenaSnap then
    self.hover = nil
    self:drawArena(v, self.arenaSnap, true, mx, my)
  elseif self.arenaSnap and self.t < self.lingerUntil then
    self:drawArena(v, self.arenaSnap, false, mx, my)
  end
  self:drawHand(v, mx, my)
  self:drawTips(v)
  for _, f in ipairs(Anim.floats) do
    local a = 1 - f.t / 1.4
    Theme.centerText(f.text, f.x, f.y - f.t * 22, { font = f.font, color = { f.color[1], f.color[2], f.color[3], a } })
  end
  self:drawModal(v, mx, my)
end

-- ----------------------------------------------------------------- wejście
function G:mousemoved(x, y)
  for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end
  for _, b in ipairs(self.modalButtons) do b:mousemoved(x, y) end
  if self.fameButton then self.fameButton:mousemoved(x, y) end
end

function G:mousepressed(x, y)
  local v = self:view()
  if not v then return end
  for _, h in ipairs(self.modalHit or {}) do
    if Theme.hit(x, y, h.x, h.y, h.w, h.h) then Audio.play("click"); self:act(h.action); return end
  end
  for _, b in ipairs(self.modalButtons) do if b:mousepressed(x, y) then return end end
  local pr = v.prompt
  if pr and pr.pid == v.me then return end
  if v.phase == "setup" and v.setup[v.me] ~= "swap" then return end
  for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end
  if self.fameButton and self.fameButton:mousepressed(x, y) then return end
  if v.phase == "market" and v.turn.player == v.me then
    for i, h in ipairs(self.marketHit) do
      if v.marketRow[i] and Theme.hit(x, y, h.x, h.y, h.w, h.h) then
        if me(v).coins >= v.marketRow[i].price then self:act({ type = "buy", index = i }) else W.toast("Za mało miedziaków.", "error") end
        return
      end
    end
  end
  if v.fight and v.fight.attacker == v.me then
    for _, h in ipairs(self.fieldHit or {}) do
      if Theme.hit(x, y, h.x, h.y, h.w, h.h) then
        if v.phase == "fight_pick" then self:act({ type = "pick_card", index = h.index }); return end
        if v.phase == "fight_destroy" and h.counted then
          for ci, ce in ipairs(v.fight.counted) do if ce.card.id == h.counted.card.id then self:act({ type = "destroy_card", index = ci }); return end end
        end
      end
    end
  end
  for i = #(self.handHit or {}), 1, -1 do
    local h = self.handHit[i]
    if Theme.hit(x, y, h.x, h.y, h.w, Theme.VH - h.y) then
      local id = h.card.id
      local multi = v.phase == "encounter" and v.turn.player == v.me
      if self.sel[id] then
        self.sel[id] = nil
        for k, sid in ipairs(self.selOrder) do if sid == id then table.remove(self.selOrder, k) end end
      else
        if not multi then self.sel, self.selOrder = {}, {} end
        if multi and #self.selOrder >= 3 then W.toast("Do zlecenia maksymalnie 3 karty.", "error"); return end
        self.sel[id] = true
        self.selOrder[#self.selOrder + 1] = id
      end
      Audio.play("card")
      self.actionsKey = nil
      return
    end
  end
end

function G:keypressed(key)
  if key == "space" or key == "return" or key == "kpenter" then
    for _, b in ipairs(self.buttons) do
      if b.enabled and (b.style == "ok" or b.style == "danger") then b.onClick(b); return true end
    end
  end
end

return G
