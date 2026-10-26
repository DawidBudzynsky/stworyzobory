-- Nakładka ustawień (głośność, pełny ekran, powrót do menu).
local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local Settings = require("src.settings")
local Audio = require("src.audio")

local S = {}
S.__index = S

local PX, PY, PW, PH = 220, 90, 200, 170

function S.new()
  local s = setmetatable({ name = "settings", buttons = {} }, S)
  local function vol(d)
    Settings.data.volume = math.max(0, math.min(1, (Settings.data.volume or 0.7) + d))
    Audio.setVolume(Settings.data.volume); Settings.save(); Audio.play("click")
  end
  s.buttons[#s.buttons + 1] = W.button({ x = PX + 10, y = PY + 36, w = 30, h = 18, label = "−", onClick = function() vol(-0.1) end })
  s.buttons[#s.buttons + 1] = W.button({ x = PX + PW - 40, y = PY + 36, w = 30, h = 18, label = "+", onClick = function() vol(0.1) end })
  s.buttons[#s.buttons + 1] = W.button({ x = PX + 10, y = PY + 66, w = PW - 20, h = 18, label = "Pełny ekran: " .. (Settings.data.fullscreen and "TAK" or "NIE"), style = "secondary", onClick = function(b)
    Settings.data.fullscreen = not Settings.data.fullscreen; Settings.save(); App.applyFullscreen()
    b.label = "Pełny ekran: " .. (Settings.data.fullscreen and "TAK" or "NIE")
  end })
  s.buttons[#s.buttons + 1] = W.button({ x = PX + 10, y = PY + 96, w = PW - 20, h = 18, label = "Wróć", style = "ok", onClick = function() App.overlay = nil end })
  s.buttons[#s.buttons + 1] = W.button({ x = PX + 10, y = PY + 126, w = PW - 20, h = 18, label = "Opuść grę (do menu)", style = "danger", onClick = function()
    App.overlay = nil; App.closeSession(); App.setScreen("menu")
  end })
  return s
end

function S:draw()
  local c = Theme.colors
  love.graphics.setColor(c.dim); love.graphics.rectangle("fill", 0, 0, Theme.VW, Theme.VH)
  Theme.panel(PX, PY, PW, PH, { fill = c.panel })
  Theme.centerText("Ustawienia", PX + PW / 2, PY + 14, { font = "largeB", color = c.gold })
  Theme.centerText("Głośność: " .. math.floor((Settings.data.volume or 0.7) * 100 + 0.5) .. "%", PX + PW / 2, PY + 45, { font = "body", color = c.cream })
  for _, b in ipairs(self.buttons) do b:draw() end
end

function S:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function S:mousepressed(x, y)
  for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end
  if not Theme.hit(x, y, PX, PY, PW, PH) then App.overlay = nil end
end
function S:keypressed(key) if key == "escape" then App.overlay = nil; return true end end

return S
