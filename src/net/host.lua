-- Host: serwer TCP + autorytatywny stan gry. Gracz 1 (host) działa lokalnie bez gniazda.
local T = require("src.net.transport")
local Rules = require("src.game.rules")

local PROTOCOL = 1
local MAX_PLAYERS = 5

local Host = {}
Host.__index = Host

local function randomToken()
  local t = {}
  for i = 1, 16 do t[i] = string.format("%x", math.random(0, 15)) end
  return table.concat(t)
end

function Host.new(port, hostName)
  local server, err = T.listen(port)
  if not server then return nil, err end
  local h = setmetatable({
    server = server, port = port, protocol = PROTOCOL,
    players = { { pid = 1, name = hostName, connected = true, isLocal = true } },
    pending = {}, -- połączenia bez przypisanego gracza
    state = nil, view = nil, lastError = nil, closed = false,
    log = {},
  }, Host)
  return h
end

function Host:isHost() return true end

function Host:lobbyInfo()
  local list = {}
  for _, p in ipairs(self.players) do list[#list + 1] = { pid = p.pid, name = p.name, connected = p.connected } end
  return { t = "lobby", players = list, started = self.state ~= nil }
end

function Host:broadcastLobby()
  local info = self:lobbyInfo()
  for _, p in ipairs(self.players) do
    if p.conn and p.connected then p.conn:send(info) end
  end
end

function Host:sendView(p)
  if not self.state then return end
  if p.isLocal then
    self.view = Rules.view(self.state, p.pid)
  elseif p.conn and p.connected then
    p.conn:send({ t = "state", view = Rules.view(self.state, p.pid) })
  end
end

function Host:broadcastViews()
  for _, p in ipairs(self.players) do self:sendView(p) end
end

local function findByToken(self, token)
  for _, p in ipairs(self.players) do if p.token and p.token == token then return p end end
end

function Host:handleJoin(conn, msg)
  if msg.protocol ~= PROTOCOL then
    conn:send({ t = "rejected", msg = "Niezgodna wersja gry (host: " .. PROTOCOL .. ")." })
    conn:close()
    return
  end
  local p = msg.token and findByToken(self, msg.token)
  if p then -- ponowne połączenie
    if p.conn then p.conn:close() end
    p.conn, p.connected = conn, true
    conn.player = p
    conn:send({ t = "welcome", pid = p.pid, token = p.token, name = p.name })
    self:broadcastLobby()
    self:sendView(p)
    self.log[#self.log + 1] = p.name .. " połączył się ponownie."
    return
  end
  if self.state then
    conn:send({ t = "rejected", msg = "Gra już trwa." })
    conn:close()
    return
  end
  if #self.players >= MAX_PLAYERS then
    conn:send({ t = "rejected", msg = "Pokój jest pełny (maks. 5 graczy)." })
    conn:close()
    return
  end
  local name = tostring(msg.name or "Gracz"):sub(1, 16)
  if name == "" then name = "Gracz" end
  for _, q in ipairs(self.players) do if q.name == name then name = name .. #self.players + 1 end end
  p = { pid = #self.players + 1, name = name, connected = true, conn = conn, token = randomToken() }
  self.players[#self.players + 1] = p
  conn.player = p
  conn:send({ t = "welcome", pid = p.pid, token = p.token, name = p.name })
  self:broadcastLobby()
  self.log[#self.log + 1] = p.name .. " dołączył."
end

function Host:act(pid, action, seq)
  if not self.state then return false, "Gra się jeszcze nie zaczęła." end
  if seq and seq ~= self.state.seq then return false, "Stan gry się zmienił – spróbuj ponownie." end
  local ok, err = Rules.apply(self.state, pid, action)
  if ok then self:broadcastViews() end
  return ok, err
end

function Host:localAct(action)
  local ok, err = self:act(1, action, self.state and self.state.seq)
  if not ok then self.lastError = err end
  return ok, err
end

function Host:handleMessage(conn, msg)
  if msg.t == "join" then return self:handleJoin(conn, msg) end
  local p = conn.player
  if not p then return end
  if msg.t == "action" then
    local ok, err = self:act(p.pid, msg.action, msg.seq)
    if not ok then conn:send({ t = "err", msg = err }) end
  elseif msg.t == "ping" then
    conn:send({ t = "pong" })
  elseif msg.t == "leave" then
    conn:close()
  end
end

function Host:update()
  if self.closed then return end
  for _, conn in ipairs(self.server:accept()) do self.pending[#self.pending + 1] = conn end
  -- połączenia oczekujące na "join"
  local keep = {}
  for _, conn in ipairs(self.pending) do
    for _, msg in ipairs(conn:receive()) do self:handleMessage(conn, msg) end
    if conn.open and not conn.player then keep[#keep + 1] = conn end
  end
  self.pending = keep
  -- gracze
  for _, p in ipairs(self.players) do
    if p.conn then
      for _, msg in ipairs(p.conn:receive()) do self:handleMessage(p.conn, msg) end
      if not p.conn.open and p.connected then
        p.connected = false
        self.log[#self.log + 1] = p.name .. " rozłączył się."
        self:broadcastLobby()
      end
    end
  end
end

function Host:canStart()
  return not self.state and #self.players >= 2
end

function Host:startGame(seed)
  if not self:canStart() then return false end
  local names = {}
  for i, p in ipairs(self.players) do names[i] = p.name end
  self.state = Rules.new(names, seed or os.time())
  self:broadcastLobby()
  self:broadcastViews()
  return true
end

-- Wykonuje akcję domyślną za nieobecnego gracza (host może odblokować grę).
function Host:skipPlayer(pid)
  if not self.state then return false end
  local a = Rules.defaultAction(self.state, pid)
  if not a then return false, "Brak akcji do wykonania." end
  return self:act(pid, a, self.state.seq)
end

function Host:kick(pid)
  for i, p in ipairs(self.players) do
    if p.pid == pid and not p.isLocal and not self.state then
      if p.conn then p.conn:send({ t = "rejected", msg = "Host usunął Cię z pokoju." }); p.conn:close() end
      table.remove(self.players, i)
      for j, q in ipairs(self.players) do q.pid = j end
      self:broadcastLobby()
      return true
    end
  end
end

function Host:close()
  if self.closed then return end
  self.closed = true
  for _, p in ipairs(self.players) do
    if p.conn and p.connected then p.conn:send({ t = "hostQuit" }) end
  end
  self.server:close()
end

return Host
