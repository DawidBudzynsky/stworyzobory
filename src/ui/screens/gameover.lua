local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local Art = require("src.ui.cardart")
local Audio = require("src.audio")

local S = {}
S.__index = S

function S.new(view)
  local s = setmetatable({ name = "gameover", view = view, buttons = {}, t = 0 }, S)
  s.buttons[1] = W.button({ x = Theme.VW / 2 - 70, y = 318, w = 140, h = 22, label = "Wróć do menu", style = "primary", onClick = function()
    App.closeSession(); App.setScreen("menu")
  end })
  Audio.play(view.winner == view.me and "win" or "lose")
  return s
end

function S:update(dt) self.t = self.t + dt end

function S:draw()
  local c = Theme.colors
  local v = self.view
  local w = v.players[v.winner]
  Theme.centerText("KONIEC GRY", Theme.VW / 2, 34, { font = "hugeB", color = c.gold })
  Theme.centerText(w.name .. " zostaje Królem Pogromców Potworów!", Theme.VW / 2, 66, { font = "largeB", color = c.cream })
  Art.drawCharacter(w.char, Theme.VW / 2 - 50, 86, 100, 136, { selected = true })
  Theme.crown(Theme.VW / 2, 80 + math.sin(self.t * 3) * 2, 12, c.gold)
  local y = 236
  Theme.panel(100, y - 6, 440, 70, { fill = c.panel })
  local n = #v.players
  for i, p in ipairs(v.players) do
    local x = 106 + (i - 1) * (428 / n)
    Theme.text(p.name, x + 4, y, { font = "smallB", color = p.id == v.winner and c.gold or c.cream, width = 428 / n - 8 })
    Theme.text(p.char.name .. (p.eliminated and " (odpadł)" or ""), x + 4, y + 14, { font = "small", color = c.creamDark, width = 428 / n - 8 })
    Theme.text("Sława " .. p.fameCount .. (p.id == v.winner and "+korona" or "") .. "\n¢ " .. p.coins .. "   ♥ " .. p.hp, x + 4, y + 28, { font = "small", color = c.cream, width = 428 / n - 8 })
  end
  for _, b in ipairs(self.buttons) do b:draw() end
end

function S:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function S:mousepressed(x, y) for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end end

return S
