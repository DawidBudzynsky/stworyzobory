-- Nakładka po utracie połączenia (klient).
local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")

local S = {}
S.__index = S
local PX, PY, PW, PH = 200, 110, 240, 130

function S.new()
  local s = setmetatable({ name = "disconnected", buttons = {} }, S)
  local sess = App.session
  if sess and not sess.hostQuit then
    s.buttons[#s.buttons + 1] = W.button({ x = PX + 20, y = PY + 66, w = PW - 40, h = 18, label = "Połącz ponownie", style = "ok", onClick = function()
      if App.session and App.session.reconnect then App.session:reconnect() end
      App.overlay = nil
    end })
  end
  s.buttons[#s.buttons + 1] = W.button({ x = PX + 20, y = PY + 96, w = PW - 40, h = 18, label = "Wróć do menu", style = "danger", onClick = function()
    App.overlay = nil; App.closeSession(); App.setScreen("menu")
  end })
  return s
end

function S:draw()
  local c = Theme.colors
  love.graphics.setColor(c.dim); love.graphics.rectangle("fill", 0, 0, Theme.VW, Theme.VH)
  Theme.panel(PX, PY, PW, PH, { fill = c.panel })
  Theme.centerText("Utracono połączenie", PX + PW / 2, PY + 16, { font = "largeB", color = c.btnDanger })
  Theme.centerText(App.session and App.session.error or "", PX + PW / 2, PY + 42, { font = "small", color = c.cream, width = PW - 20 })
  for _, b in ipairs(self.buttons) do b:draw() end
end

function S:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function S:mousepressed(x, y) for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end end
function S:keypressed(key) return key == "escape" end

return S
