-- Test integracyjny sieci przez loopback: host + 2 klientów, lobby, start, rozgrywka,
-- odrzucanie nieaktualnych akcji, ukrywanie informacji, rozłączenie i ponowne połączenie.
package.path = "./?.lua;" .. package.path
local Host = require("src.net.host")
local Client = require("src.net.client")
local Rules = require("src.game.rules")
local socket = require("socket")

local PORT = 36111
local function pump(host, clients, n)
  for _ = 1, n or 20 do
    host:update()
    for _, c in ipairs(clients) do c:update() end
    socket.sleep(0.01)
  end
end
local function assertf(cond, ...) if not cond then error(string.format(...), 2) end end

local host = assert(Host.new(PORT, "Host"))
local c1 = Client.new("127.0.0.1", PORT, "Ala")
local c2 = Client.new("127.0.0.1", PORT, "Bartek")
pump(host, { c1, c2 }, 30)
assertf(c1.status == "lobby" and c2.status == "lobby", "klienci w lobby: %s %s", c1.status, c2.status)
assertf(c1.pid == 2 and c2.pid == 3, "pid")
assertf(#host.players == 3, "3 graczy")
assertf(c2.lobby and #c2.lobby.players == 3, "lobby widzi 3 graczy")

-- odrzucenie: zła wersja protokołu
local T = require("src.net.transport")
local bad = T.connect("127.0.0.1", PORT)
local badConn
for _ = 1, 50 do badConn = bad:poll(); if badConn then break end; socket.sleep(0.01) end
badConn:send({ t = "join", name = "Zły", protocol = 99 })
pump(host, { c1, c2 }, 10)
local gotRejected = false
for _, m in ipairs(badConn:receive()) do if m.t == "rejected" then gotRejected = true end end
assertf(gotRejected, "zła wersja odrzucona")

assert(host:startGame(123))
pump(host, { c1, c2 }, 10)
assertf(c1.status == "game" and c1.view and c1.view.seq == 0, "klient dostał widok")
assertf(host.view.me == 1 and c1.view.me == 2, "widoki personalizowane")

-- ukrywanie: klient 1 nie widzi ręki klienta 2 ani jego zapasowej postaci
assertf(c1.view.players[3].hand == nil and c1.view.players[3].backup == nil, "ukryte dane")

-- rozgrywka losową polityką po sieci aż do końca (lub limitu)
local sessions = { [1] = host, [2] = c1, [3] = c2 }
math.randomseed(7)
local steps = 0
while not host.state.winner and steps < 6000 do
  steps = steps + 1
  local waiting = Rules.waitingFor(host.state)
  local pid = waiting[math.random(#waiting)]
  local cands = Rules.candidateActions(host.state, pid)
  local a = cands[math.random(#cands)]
  if host.state.phase == "encounter" then a = cands[1] end
  if host.state.phase == "fight_react" then a = cands[1] end
  if host.state.phase == "road_choice" then a = cands[1] end
  local seqBefore = host.state.seq
  assert(sessions[pid]:localAct(a))
  pump(host, { c1, c2 }, 3)
  assertf(host.state.seq == seqBefore + 1, "akcja %s gracza %d nie przeszła: %s", a.type, pid, tostring(sessions[pid].lastError))
  assertf(c1.view.seq == host.state.seq and c2.view.seq == host.state.seq, "widoki zsynchronizowane (krok %d)", steps)
  if steps == 5 then
    -- powtórzona (nieaktualna) akcja musi zostać odrzucona
    c1.conn:send({ t = "action", action = a, seq = seqBefore })
    pump(host, { c1, c2 }, 3)
    assertf(host.state.seq == seqBefore + 1, "stara akcja zignorowana")
    assertf(c1.lastError ~= nil, "klient dostał komunikat błędu")
    c1.lastError = nil
  end
  if steps == 30 then
    -- rozłączenie i ponowne połączenie klienta 2 z tokenem
    local token = c2.token
    c2:close()
    pump(host, { c1 }, 10)
    assertf(host.players[3].connected == false, "host widzi rozłączenie")
    c2 = Client.new("127.0.0.1", PORT, "Bartek", token)
    sessions[3] = c2
    pump(host, { c1, c2 }, 30)
    assertf(c2.status == "game" and c2.pid == 3 and c2.view.seq == host.state.seq, "ponowne połączenie: %s", tostring(c2.error))
  end
end
assertf(host.state.winner, "gra po sieci dobiegła końca (kroki: %d)", steps)
assertf(c1.view.winner == host.state.winner, "klienci znają zwycięzcę")

-- host kończy -> klienci dostają komunikat
host:close()
pump(host, { c1, c2 }, 10)
assertf(c1.status == "error" and c1.error:find("Host"), "klient wie, że host zakończył: %s", tostring(c1.error))
print("Test sieci: OK (" .. steps .. " akcji po sieci)")
