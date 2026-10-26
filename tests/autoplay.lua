-- Automatyczny przebieg gry w LÖVE (host + boty w procesie), ze zrzutami ekranu.
-- Uruchomienie: STWORY_AUTOTEST=1 love .   (zrzuty trafiają do katalogu zapisu LÖVE: autotest/)
local Rules = require("src.game.rules")
local Host = require("src.net.host")
local Client = require("src.net.client")

local A = { bots = {}, t = 0, phaseShots = {}, stalls = 0, lastAct = 0, started = false, done = false, shots = 0, seed = tonumber(os.getenv("STWORY_SEED") or "11") }
local PORT = 36222

local function shot(name)
  if A.shots > 60 then return end
  A.shots = A.shots + 1
  love.graphics.captureScreenshot("autotest/" .. string.format("%02d_%s.png", A.shots, name))
end

local function pick(list) return list[math.random(#list)] end

local function botAct(bot)
  local st = App.session.state
  local waiting = Rules.waitingFor(st)
  local mine = false
  for _, pid in ipairs(waiting) do if pid == bot.pid then mine = true end end
  if not mine then return end
  local c = Rules.candidateActions(st, bot.pid)
  if #c == 0 then return end
  local a = pick(c)
  if st.phase == "encounter" and math.random() < 0.6 then a = c[1] end
  if st.phase == "fight_react" and math.random() < 0.7 then a = c[1] end
  if st.phase == "road_choice" and math.random() < 0.8 then a = c[1] end
  bot:act(a)
end

-- Gra hosta przez interfejs (kliknięcia w przyciski/karty ekranu).
local function hostActViaUI()
  local scr = App.screen
  if not scr or scr.name ~= "game" then return false end
  local v = scr:view()
  if not v then return false end
  local mine = false
  for _, pid in ipairs(v.waitingFor) do if pid == v.me then mine = true end end
  if not mine then return false end
  if scr.modalHit and #scr.modalHit > 0 then
    local h = pick(scr.modalHit)
    scr:mousepressed(h.x + h.w / 2, h.y + h.h / 2)
    return true
  end
  if #scr.modalButtons > 0 then
    local en = {}
    for _, b in ipairs(scr.modalButtons) do if b.enabled then en[#en + 1] = b end end
    if #en > 0 then local b = pick(en); scr:mousepressed(b.x + 5, b.y + 5); return true end
  end
  if v.phase == "fight_pick" or v.phase == "fight_destroy" then
    local hits = {}
    for _, h in ipairs(scr.fieldHit or {}) do if v.phase == "fight_pick" or h.counted then hits[#hits + 1] = h end end
    if #hits > 0 then local h = pick(hits); scr:mousepressed(h.x + 5, h.y + 5); return true end
  end
  -- czasem zaznacz kartę na ręce (dla zlecenia / dorzucania / premii)
  if scr.handHit and #scr.handHit > 0 and math.random() < 0.6 and #scr.selOrder == 0 then
    local h = pick(scr.handHit)
    scr:mousepressed(h.x + 5, h.y + 5)
    scr:rebuildActions(v)
  end
  if v.phase == "market" and math.random() < 0.5 then
    for i, h in ipairs(scr.marketHit or {}) do
      local card = v.marketRow[i]
      if card and v.players[v.me].coins >= card.price then scr:mousepressed(h.x + 2, h.y + 2); return true end
    end
  end
  local en = {}
  for _, b in ipairs(scr.buttons) do if b.enabled then en[#en + 1] = b end end
  if scr.fameButton and scr.fameButton.enabled and math.random() < 0.5 then en[#en + 1] = scr.fameButton end
  if #en > 0 then
    local b = pick(en)
    scr:mousepressed(b.x + 5, b.y + 5)
    return true
  end
  return false
end

function A.install()
  math.randomseed(A.seed)
  love.filesystem.createDirectory("autotest")
  local baseUpdate = love.update
  love.update = function(dt)
    baseUpdate(dt)
    A.t = A.t + dt
    if A.done then return end
    if not A.started then
      if A.t > 0.3 and not App.session then
        local h = assert(Host.new(PORT, "Host"))
        App.session = h
        App.setScreen("lobby")
        local names = { "Bot-Ala", "Bot-Bartek", "Bot-Celina", "Bot-Darek" }
        for i = 1, tonumber(os.getenv("STWORY_BOTS") or "2") do A.bots[i] = Client.new("127.0.0.1", PORT, names[i]) end
      elseif App.session and App.session:isHost() and App.session:canStart() and #App.session.players == #A.bots + 1 and A.t > 1.2 then
        shot("lobby")
        App.session:startGame(A.seed)
        A.started = true
      end
      for _, b in ipairs(A.bots) do b:update() end
      return
    end
    for _, b in ipairs(A.bots) do b:update() end
    local sess = App.session
    if not sess or not sess.state then return end
    local st = sess.state
    if st.winner then
      if App.screen.name == "gameover" and not A.finalShot then
        A.finalShot = true
        shot("gameover")
        A.doneAt = A.t
      end
      if A.doneAt and A.t > A.doneAt + 0.5 then
        A.done = true
        print(string.format("AUTOTEST OK: zwycięzca=%s, akcji=%d, zrzutów=%d, zastojów UI=%d", st.players[st.winner].name, st.seq, A.shots, A.stalls))
        love.event.quit()
      end
      return
    end
    -- zrzut z najechaniem na kartę w ręce (podgląd) – raz
    -- symulacja pozycji myszy (podmiana love.mouse.getPosition) – kilka klatek na każdy dymek
    if not A.hoverShot and App.screen.name == "game" and st.phase == "market" and st.seq > 12 and App.screen.handHit and #App.screen.handHit >= 3 then
      local Theme = require("src.ui.theme")
      local h = App.screen.handHit[3]
      A.hoverSeq = { { "hover_hand", h.x + 20, h.y + 30 }, { "hover_seat", 60, 50 }, { "hover_deck", 320, 60 }, { "hover_own", 20, 300 }, { "hover_market", 320, 170 } }
      A.hoverShot = 1; A.hoverFrames = 0
      A.realGetPos = love.mouse.getPosition
      love.mouse.getPosition = function()
        local cur = A.hoverSeq[A.hoverIdx or 1]
        return Theme.ox + cur[2] * Theme.scale, Theme.oy + cur[3] * Theme.scale
      end
      A.hoverIdx = 1
    elseif A.hoverShot == 1 then
      A.hoverFrames = A.hoverFrames + 1
      if A.hoverFrames >= 12 then
        shot(A.hoverSeq[A.hoverIdx][1])
        A.hoverIdx = A.hoverIdx + 1; A.hoverFrames = 0
        if A.hoverIdx > #A.hoverSeq then love.mouse.getPosition = A.realGetPos; A.hoverShot = 2 end
      end
    end
    -- zrzut pierwszego wystąpienia każdej fazy / promptu
    local key = st.phase .. (st.prompt and ("_" .. st.prompt.type) or "")
    if App.screen.name == "game" and not A.phaseShots[key] and A.t - (A.lastShotT or 0) > 0.2 then
      A.phaseShots[key] = true
      A.lastShotT = A.t
      shot(key)
    end
    -- boty działają co ~0.15 s, host co ~0.35 s (żeby zrzuty łapały stan "do decyzji")
    if A.t - A.lastAct > 0.15 then
      A.lastAct = A.t
      local seqBefore = st.seq
      for _, b in ipairs(A.bots) do botAct(b) end
      if st.seq == seqBefore and A.t - (A.lastHostAct or 0) > 0.35 then
        A.lastHostAct = A.t
        local acted = hostActViaUI()
        if not acted then
          local waiting = Rules.waitingFor(st)
          local hostWaiting = false
          for _, pid in ipairs(waiting) do if pid == 1 then hostWaiting = true end end
          if hostWaiting then
            A.stallFrames = (A.stallFrames or 0) + 1
            if A.stallFrames > 8 then
              A.stalls = A.stalls + 1
              print("UI STALL w fazie " .. key .. " – akcja domyślna")
              sess:skipPlayer(1)
              A.stallFrames = 0
            end
          else A.stallFrames = 0 end
        else A.stallFrames = 0 end
      end
    end
    if os.getenv("STWORY_DEBUG") and math.floor(A.t) ~= A.lastDbg then
      A.lastDbg = math.floor(A.t)
      local w = Rules.waitingFor(st)
      print(string.format("[t=%d] faza=%s seq=%d czeka=%s bot1=%s/%s bot2=%s/%s screen=%s", A.lastDbg, key, st.seq, table.concat(w, ","), A.bots[1].status, tostring(A.bots[1].lastError), A.bots[2].status, tostring(A.bots[2].lastError), App.screen.name))
    end
    if A.t > 240 then
      print("AUTOTEST TIMEOUT w fazie " .. key)
      A.done = true
      love.event.quit()
    end
  end
end

return A
