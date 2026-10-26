local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local Settings = require("src.settings")
local Host = require("src.net.host")

local S = {}
S.__index = S

function S.new()
  local s = setmetatable({ name = "host", buttons = {}, error = nil }, S)
  local cx = Theme.VW / 2
  s.nameInput = W.textInput({ x = cx - 90, y = 118, w = 180, text = Settings.data.name or "", placeholder = "Twoje imię", maxLen = 16 })
  s.portInput = W.textInput({ x = cx - 90, y = 162, w = 180, text = Settings.data.lastPort or "29999", placeholder = "Port (np. 29999)", numeric = true, maxLen = 5 })
  s.buttons[1] = W.button({ x = cx - 90, y = 200, w = 180, h = 22, label = "Utwórz pokój", style = "ok", onClick = function() s:create() end })
  s.buttons[2] = W.button({ x = cx - 90, y = 232, w = 180, h = 18, label = "Wróć", style = "secondary", onClick = function() App.setScreen("menu") end })
  s.nameInput.focused = true
  return s
end

function S:create()
  local name = self.nameInput.text:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then self.error = "Podaj imię."; return end
  local port = tonumber(self.portInput.text)
  if not port or port < 1024 or port > 65535 then self.error = "Port musi być liczbą 1024–65535."; return end
  Settings.data.name, Settings.data.lastPort = name, tostring(port)
  Settings.save()
  App.closeSession()
  local host, err = Host.new(port, name)
  if not host then self.error = "Nie udało się otworzyć portu " .. port .. ": " .. tostring(err); return end
  App.session = host
  App.setScreen("lobby")
end

function S:draw()
  local c = Theme.colors
  Theme.centerText("Stwórz pokój", Theme.VW / 2, 70, { font = "titleB", color = c.gold })
  Theme.text("Imię gracza", Theme.VW / 2 - 90, 106, { font = "small", color = c.creamDark })
  self.nameInput:draw()
  Theme.text("Port TCP (otwórz go w zaporze dla gry w LAN)", Theme.VW / 2 - 90, 150, { font = "small", color = c.creamDark })
  self.portInput:draw()
  for _, b in ipairs(self.buttons) do b:draw() end
  if self.error then Theme.centerText(self.error, Theme.VW / 2, 275, { font = "body", color = c.btnDanger }) end
end

function S:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function S:mousepressed(x, y)
  self.nameInput:mousepressed(x, y); self.portInput:mousepressed(x, y)
  for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end
end
function S:textinput(t) self.nameInput:textinput(t); self.portInput:textinput(t) end
function S:keypressed(key)
  if key == "tab" then self.nameInput.focused, self.portInput.focused = self.portInput.focused, self.nameInput.focused; return true end
  if key == "return" or key == "kpenter" then self:create(); return true end
  self.nameInput:keypressed(key); self.portInput:keypressed(key)
end

return S
