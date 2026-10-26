local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local Settings = require("src.settings")
local Client = require("src.net.client")

local S = {}
S.__index = S

function S.new()
  local s = setmetatable({ name = "join", buttons = {}, error = nil }, S)
  local cx = Theme.VW / 2
  s.nameInput = W.textInput({ x = cx - 90, y = 100, w = 180, text = Settings.data.name or "", placeholder = "Twoje imię", maxLen = 16 })
  s.hostInput = W.textInput({ x = cx - 90, y = 144, w = 180, text = Settings.data.lastHost or "", placeholder = "IP hosta (LAN / Tailscale)", maxLen = 64 })
  s.portInput = W.textInput({ x = cx - 90, y = 188, w = 180, text = Settings.data.lastPort or "29999", placeholder = "Port", numeric = true, maxLen = 5 })
  s.buttons[1] = W.button({ x = cx - 90, y = 226, w = 180, h = 22, label = "Połącz", style = "ok", onClick = function() s:connect() end })
  s.buttons[2] = W.button({ x = cx - 90, y = 258, w = 180, h = 18, label = "Wróć", style = "secondary", onClick = function() App.setScreen("menu") end })
  s.inputs = { s.nameInput, s.hostInput, s.portInput }
  s.nameInput.focused = s.nameInput.text == ""
  s.hostInput.focused = not s.nameInput.focused
  return s
end

function S:connect()
  local name = self.nameInput.text:gsub("^%s+", ""):gsub("%s+$", "")
  local host = self.hostInput.text:gsub("%s", "")
  local port = tonumber(self.portInput.text)
  if name == "" then self.error = "Podaj imię."; return end
  if host == "" then self.error = "Podaj adres hosta."; return end
  if not port or port < 1 or port > 65535 then self.error = "Nieprawidłowy port."; return end
  Settings.data.name, Settings.data.lastHost, Settings.data.lastPort = name, host, tostring(port)
  Settings.save()
  App.closeSession()
  local sess = Settings.data.session
  local token = (sess and sess.host == host and sess.port == port) and sess.token or nil
  App.session = Client.new(host, port, name, token)
  App.setScreen("lobby")
end

function S:draw()
  local c = Theme.colors
  Theme.centerText("Dołącz do gry", Theme.VW / 2, 60, { font = "titleB", color = c.gold })
  Theme.text("Imię gracza", Theme.VW / 2 - 90, 88, { font = "small", color = c.creamDark })
  Theme.text("Adres hosta", Theme.VW / 2 - 90, 132, { font = "small", color = c.creamDark })
  Theme.text("Port", Theme.VW / 2 - 90, 176, { font = "small", color = c.creamDark })
  for _, i in ipairs(self.inputs) do i:draw() end
  for _, b in ipairs(self.buttons) do b:draw() end
  if self.error then Theme.centerText(self.error, Theme.VW / 2, 300, { font = "body", color = c.btnDanger }) end
end

function S:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function S:mousepressed(x, y)
  for _, i in ipairs(self.inputs) do i:mousepressed(x, y) end
  for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end
end
function S:textinput(t) for _, i in ipairs(self.inputs) do i:textinput(t) end end
function S:keypressed(key)
  if key == "tab" then
    local idx = 1
    for i, inp in ipairs(self.inputs) do if inp.focused then idx = i end; inp.focused = false end
    self.inputs[idx % #self.inputs + 1].focused = true
    return true
  end
  if key == "return" or key == "kpenter" then self:connect(); return true end
  for _, i in ipairs(self.inputs) do i:keypressed(key) end
end

return S
