-- Transport TCP (LuaSocket): wiadomości JSON rozdzielane znakiem nowej linii, bez blokowania.
local socket = require("socket")
local json = require("src.net.json")

local T = {}

local Conn = {}
Conn.__index = Conn

function Conn.wrap(sock)
  sock:settimeout(0)
  pcall(sock.setoption, sock, "tcp-nodelay", true)
  return setmetatable({ sock = sock, buf = "", open = true, err = nil }, Conn)
end

function Conn:send(msg)
  if not self.open then return false, "closed" end
  local data = json.encode(msg) .. "\n"
  local i, tries = 1, 0
  while i <= #data do
    local n, err, partial = self.sock:send(data, i)
    if n then
      i = n + 1
    elseif err == "timeout" then
      i = (partial or (i - 1)) + 1
      tries = tries + 1
      if tries > 200 then self.open, self.err = false, "send timeout"; return false, self.err end
      socket.select(nil, { self.sock }, 0.05)
    else
      self.open, self.err = false, err
      return false, err
    end
  end
  return true
end

-- Zwraca listę odebranych wiadomości (tabel). Po zamknięciu połączenia self.open = false.
function Conn:receive()
  local msgs = {}
  if not self.open then return msgs end
  for _ = 1, 500 do
    local line, err, partial = self.sock:receive("*l")
    if line then
      local ok, msg = pcall(json.decode, self.buf .. line)
      self.buf = ""
      if ok and type(msg) == "table" then msgs[#msgs + 1] = msg end
    elseif err == "timeout" then
      self.buf = self.buf .. (partial or "")
      if #self.buf > 1000000 then self.open, self.err = false, "message too long" end
      break
    else
      self.open, self.err = false, err
      break
    end
  end
  return msgs
end

function Conn:close()
  self.open = false
  pcall(self.sock.close, self.sock)
end

function Conn:peer()
  local ip, port = self.sock:getpeername()
  return ip, port
end

-- ------------------------------------------------------------------ serwer
local Server = {}
Server.__index = Server

function T.listen(port)
  local sock, err = socket.bind("*", port)
  if not sock then return nil, err end
  sock:settimeout(0)
  return setmetatable({ sock = sock, conns = {} }, Server)
end

-- Przyjmuje nowe połączenia; zwraca listę nowych Conn.
function Server:accept()
  local new = {}
  for _ = 1, 16 do
    local c = self.sock:accept()
    if not c then break end
    local conn = Conn.wrap(c)
    self.conns[#self.conns + 1] = conn
    new[#new + 1] = conn
  end
  return new
end

function Server:close()
  for _, c in ipairs(self.conns) do c:close() end
  pcall(self.sock.close, self.sock)
end

-- ------------------------------------------------------------------ klient
-- Nieblokujące łączenie: T.connect zwraca obiekt, który trzeba odpytywać metodą poll().
local Pending = {}
Pending.__index = Pending

function T.connect(host, port, timeout)
  local sock = socket.tcp()
  sock:settimeout(0)
  local ok, err = sock:connect(host, port)
  local p = setmetatable({ sock = sock, started = socket.gettime(), timeout = timeout or 6 }, Pending)
  if ok then p.done = Conn.wrap(sock) return p end
  if err ~= "timeout" and err ~= "Operation already in progress" then
    p.err = err
  end
  return p
end

-- Zwraca: nil (w toku) | Conn (połączono) | false, err (błąd)
function Pending:poll()
  if self.done then return self.done end
  if self.err then return false, self.err end
  local _, w, serr = socket.select(nil, { self.sock }, 0)
  if w and #w > 0 then
    local ip = self.sock:getpeername()
    if ip then
      self.done = Conn.wrap(self.sock)
      return self.done
    end
    self.err = "połączenie odrzucone"
    return false, self.err
  end
  if socket.gettime() - self.started > self.timeout then
    self.err = "przekroczono czas oczekiwania"
    pcall(self.sock.close, self.sock)
    return false, self.err
  end
  return nil
end

-- Adres IP interfejsu, przez który wychodzi ruch do `target` (bez wysyłania danych).
function T.localIp(target)
  local u = socket.udp()
  if not u then return nil end
  u:settimeout(0)
  local ok = u:setpeername(target or "8.8.8.8", 80)
  if not ok then u:close(); return nil end
  local ip = u:getsockname()
  u:close()
  return ip
end

T.Conn = Conn
T.now = socket.gettime
return T
