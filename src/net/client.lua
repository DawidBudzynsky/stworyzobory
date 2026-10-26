-- Klient: łączy się z hostem, odbiera widok stanu, wysyła żądania akcji.
local T = require("src.net.transport")

local PROTOCOL = 1

local Client = {}
Client.__index = Client

function Client.new(host, port, name, token)
  local c = setmetatable({
    host = host, port = port, name = name, token = token,
    status = "connecting", error = nil, pid = nil,
    lobby = nil, view = nil, lastError = nil, hostQuit = false,
    pending = T.connect(host, port, 6), conn = nil, lastPing = T.now(),
    log = {},
  }, Client)
  return c
end

function Client:isHost() return false end

function Client:handle(msg)
  if msg.t == "welcome" then
    self.pid, self.token, self.name = msg.pid, msg.token, msg.name
    self.status = "lobby"
  elseif msg.t == "lobby" then
    self.lobby = msg
    if msg.started and self.status == "lobby" then self.status = "game" end
  elseif msg.t == "state" then
    self.view = msg.view
    self.status = "game"
  elseif msg.t == "err" then
    self.lastError = msg.msg
  elseif msg.t == "rejected" then
    self.status, self.error = "error", msg.msg
  elseif msg.t == "hostQuit" then
    self.hostQuit = true
    self.status, self.error = "error", "Host zakończył grę."
  end
end

function Client:update()
  if self.pending then
    local conn, err = self.pending:poll()
    if conn then
      self.pending, self.conn = nil, conn
      conn:send({ t = "join", name = self.name, token = self.token, protocol = PROTOCOL })
    elseif conn == false then
      self.pending = nil
      self.status, self.error = "error", "Nie udało się połączyć: " .. tostring(err)
    end
    return
  end
  if not self.conn then return end
  for _, msg in ipairs(self.conn:receive()) do self:handle(msg) end
  if not self.conn.open and self.status ~= "error" then
    self.status, self.error = "error", self.hostQuit and "Host zakończył grę." or "Utracono połączenie z hostem."
  end
  if T.now() - self.lastPing > 5 and self.conn.open then
    self.lastPing = T.now()
    self.conn:send({ t = "ping" })
  end
end

function Client:act(action)
  if not self.conn or not self.conn.open then
    self.lastError = "Brak połączenia."
    return false, self.lastError
  end
  self.conn:send({ t = "action", action = action, seq = self.view and self.view.seq })
  return true
end

-- lokalny odpowiednik Host:localAct – pozwala UI używać jednego interfejsu
function Client:localAct(action) return self:act(action) end

-- Próba ponownego połączenia z zachowaniem tokenu (po zerwaniu łącza).
function Client:reconnect()
  if self.hostQuit then return false end
  if self.conn then self.conn:close() end
  self.conn = nil
  self.status, self.error = "connecting", nil
  self.pending = T.connect(self.host, self.port, 6)
  return true
end

function Client:close()
  if self.conn and self.conn.open then self.conn:send({ t = "leave" }); self.conn:close() end
  self.conn = nil
  self.status = "closed"
end

return Client
