local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local Art = require("src.ui.cardart")
local Cards = require("src.game.cards")
local lg = love.graphics

local Menu = {}
Menu.__index = Menu

function Menu.new()
  local m = setmetatable({ name = "menu", buttons = {}, t = 0 }, Menu)
  local cx = Theme.VW / 2
  local y = 150
  local function add(label, style, fn)
    m.buttons[#m.buttons + 1] = W.button({ x = cx - 70, y = y, w = 140, h = 22, label = label, style = style, onClick = fn, font = "smallB" })
    y = y + 30
  end
  add("Stwórz pokój (host)", "primary", function() App.setScreen("host") end)
  add("Dołącz do gry", "secondary", function() App.setScreen("join") end)
  add("Ustawienia", "secondary", function() App.openOverlay("settings") end)
  add("Wyjście", "danger", function() love.event.quit() end)
  local road = Cards.buildDeck(Cards.road, "d")
  local vill = Cards.buildDeck(Cards.village, "d")
  m.deco = { road[1], vill[20], road[9], vill[1], road[16], vill[30], road[20], vill[38] }
  return m
end

function Menu:update(dt) self.t = self.t + dt end

function Menu:draw()
  local c = Theme.colors
  for i, card in ipairs(self.deco) do
    local side = (i % 2 == 0) and 1 or -1
    local x = Theme.VW / 2 + side * (150 + ((i - 1) % 4) * 32) - 26
    local y = 70 + math.floor((i - 1) / 2) * 60 + math.sin(self.t * 0.9 + i) * 3
    lg.push()
    lg.translate(math.floor(x + 26), math.floor(y + 36))
    lg.rotate(math.sin(self.t * 0.5 + i * 1.3) * 0.06 + side * 0.12)
    Art.draw(card, -26, -36, 52, 72, {})
    lg.pop()
  end
  Theme.centerText("STWORY", Theme.VW / 2, 60, { font = "hugeB", color = c.gold })
  Theme.centerText("z OBORY", Theme.VW / 2, 92, { font = "titleB", color = c.cream })
  Theme.centerText("cyfrowa adaptacja gry karcianej Tomasza Bolika (Muduko)", Theme.VW / 2, 118, { font = "small", color = c.creamDark })
  for _, b in ipairs(self.buttons) do b:draw() end
  Theme.centerText("F11 – pełny ekran   •   Esc – ustawienia", Theme.VW / 2, 340, { font = "small", color = c.creamDark })
end

function Menu:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function Menu:mousepressed(x, y) for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end end

return Menu
