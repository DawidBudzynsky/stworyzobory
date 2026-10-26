-- Rysowanie kart (pixel-art, kanwa 640x360). Dane kart są w cards.lua; tutaj tylko wygląd.
-- Ilustracje są proceduralne (wektorowe, rasteryzowane bez antyaliasingu → piksele) i dobierane
-- po nazwie/rodzaju karty, więc podmiana na bitmapy wymaga zmiany tylko funkcji Art.illustration.
-- Poziomy szczegółu: w < 70 → sama ikona i odznaki; w >= 70 → nazwa; w >= 100 → pełny tekst.
local Theme = require("src.ui.theme")
local Cards = require("src.game.cards")
local lg = love.graphics
local C = Theme.colors
local floor = math.floor

local Art = {}

local function hash(str)
  local h = 7
  for i = 1, #str do h = (h * 31 + str:byte(i)) % 2147483647 end
  return h
end
local function hrand(h, k, n) return floor(((h * (k * 2654435761 % 2147483647)) % 2147483647) / 2147483647 * n) end

local function col(c, a, b, c2)
  if type(c) == "number" then lg.setColor(c, a, b, c2 or 1) else lg.setColor(c[1], c[2], c[3], a or c[4] or 1) end
end
local function circ(x, y, r) lg.circle("fill", floor(x), floor(y), r, r < 4 and 6 or 10) end
local function eye(x, y, r, dx)
  col(C.white); circ(x, y, r)
  col(C.ink); circ(x + (dx or 0) * r * 0.3, y, math.max(1, r * 0.45))
end
local function dark(c) return { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1 } end

-- ------------------------------------------------------------------ doodles
local D = {}

function D.creature(cx, cy, s, h, c)
  local bw, bh = s * (0.5 + hrand(h, 1, 30) / 100), s * (0.45 + hrand(h, 2, 35) / 100)
  local eyes, horns, legs = 1 + hrand(h, 3, 3), hrand(h, 4, 2) == 1, 2 + hrand(h, 5, 3) * 2
  local dk = dark(c)
  col(dk); lg.setLineWidth(math.max(1, s * 0.06))
  for i = 1, legs do
    local lx = cx - bw / 2 + (i - 0.5) * bw / legs
    lg.line(lx, cy + bh * 0.3, lx + (i % 2 == 0 and 1 or -1) * s * 0.05, cy + s * 0.45)
  end
  lg.setLineWidth(1)
  col(dk); lg.ellipse("fill", cx + 1, cy + 1, bw / 2, bh / 2, 12)
  col(c); lg.ellipse("fill", cx, cy, bw / 2, bh / 2, 12)
  col(dk)
  for i = 0, 6 do
    local a = math.pi + i * math.pi / 6
    local px, py = cx + math.cos(a) * bw / 2, cy + math.sin(a) * bh / 2
    lg.polygon("fill", px, py, px + math.cos(a) * s * 0.1, py + math.sin(a) * s * 0.1, px + math.cos(a + 0.35) * s * 0.03, py + math.sin(a + 0.35) * s * 0.03)
  end
  if horns then
    col(C.creamDark)
    lg.polygon("fill", cx - bw * 0.3, cy - bh * 0.35, cx - bw * 0.45, cy - bh * 0.85, cx - bw * 0.12, cy - bh * 0.4)
    lg.polygon("fill", cx + bw * 0.3, cy - bh * 0.35, cx + bw * 0.45, cy - bh * 0.85, cx + bw * 0.12, cy - bh * 0.4)
  end
  local er = math.max(1.5, s * 0.07)
  if eyes == 1 then eye(cx, cy - bh * 0.12, er * 1.4)
  elseif eyes == 2 then eye(cx - bw * 0.22, cy - bh * 0.12, er); eye(cx + bw * 0.22, cy - bh * 0.12, er)
  else eye(cx - bw * 0.24, cy - bh * 0.1, er * 0.8); eye(cx + bw * 0.24, cy - bh * 0.1, er * 0.8); eye(cx, cy - bh * 0.3, er * 0.7) end
  col(C.ink); lg.arc("fill", cx, cy + bh * 0.15, bw * 0.25, 0.15, math.pi - 0.15, 8)
  col(C.white)
  for i = 0, 2 do
    local tx = cx - bw * 0.15 + i * bw * 0.15
    lg.polygon("fill", tx, cy + bh * 0.17, tx + s * 0.05, cy + bh * 0.17, tx + s * 0.025, cy + bh * 0.3)
  end
end

function D.spider(cx, cy, s, _, c)
  col(C.inkSoft); lg.setLineWidth(math.max(1, s * 0.04))
  for i = -3, 3, 2 do for side = -1, 1, 2 do lg.line(cx, cy, cx + side * s * 0.4, cy + i * s * 0.1, cx + side * s * 0.45, cy + i * s * 0.1 + s * 0.15) end end
  lg.setLineWidth(1)
  col(c); lg.ellipse("fill", cx, cy + s * 0.05, s * 0.22, s * 0.18, 10); circ(cx, cy - s * 0.15, s * 0.11)
  eye(cx - s * 0.05, cy - s * 0.17, math.max(1, s * 0.035)); eye(cx + s * 0.05, cy - s * 0.17, math.max(1, s * 0.035))
end

function D.frog(cx, cy, s, _, c)
  col(dark(c)); lg.ellipse("fill", cx, cy + s * 0.08, s * 0.4, s * 0.3, 12)
  col(c); lg.ellipse("fill", cx, cy + s * 0.02, s * 0.36, s * 0.26, 12)
  eye(cx - s * 0.15, cy - s * 0.2, s * 0.08); eye(cx + s * 0.15, cy - s * 0.2, s * 0.08)
  col(C.ink); lg.line(cx - s * 0.2, cy + s * 0.1, cx, cy + s * 0.14, cx + s * 0.2, cy + s * 0.1)
  col(dark(c)); lg.ellipse("fill", cx - s * 0.33, cy + s * 0.28, s * 0.12, s * 0.06, 8); lg.ellipse("fill", cx + s * 0.33, cy + s * 0.28, s * 0.12, s * 0.06, 8)
end

function D.wolf(cx, cy, s, _, c)
  col(c)
  lg.polygon("fill", cx - s * 0.3, cy - s * 0.4, cx - s * 0.15, cy - s * 0.15, cx - s * 0.3, cy - s * 0.1)
  lg.polygon("fill", cx + s * 0.3, cy - s * 0.4, cx + s * 0.15, cy - s * 0.15, cx + s * 0.3, cy - s * 0.1)
  lg.ellipse("fill", cx, cy, s * 0.32, s * 0.3, 12); lg.ellipse("fill", cx, cy + s * 0.22, s * 0.18, s * 0.15, 10)
  eye(cx - s * 0.12, cy - s * 0.08, s * 0.05, 1); eye(cx + s * 0.12, cy - s * 0.08, s * 0.05, -1)
  col(C.white)
  for i = -2, 2 do lg.polygon("fill", cx + i * s * 0.07 - s * 0.03, cy + s * 0.18, cx + i * s * 0.07 + s * 0.03, cy + s * 0.18, cx + i * s * 0.07, cy + s * 0.28) end
  col(C.ink); circ(cx, cy + s * 0.14, math.max(1, s * 0.04))
end

function D.devil(cx, cy, s, _, c)
  col(C.creamDark)
  lg.polygon("fill", cx - s * 0.2, cy - s * 0.25, cx - s * 0.38, cy - s * 0.48, cx - s * 0.08, cy - s * 0.3)
  lg.polygon("fill", cx + s * 0.2, cy - s * 0.25, cx + s * 0.38, cy - s * 0.48, cx + s * 0.08, cy - s * 0.3)
  col(c); lg.ellipse("fill", cx, cy - s * 0.1, s * 0.24, s * 0.28, 12)
  lg.setLineWidth(math.max(1, s * 0.05)); lg.line(cx - s * 0.1, cy + s * 0.15, cx - s * 0.2, cy + s * 0.45); lg.line(cx + s * 0.1, cy + s * 0.15, cx + s * 0.2, cy + s * 0.45); lg.setLineWidth(1)
  eye(cx - s * 0.09, cy - s * 0.15, s * 0.05); eye(cx + s * 0.09, cy - s * 0.15, s * 0.05)
end

function D.ghost(cx, cy, s, _, c)
  col(c[1], c[2], c[3], 0.9)
  circ(cx, cy - s * 0.1, s * 0.25); lg.rectangle("fill", cx - s * 0.25, cy - s * 0.1, s * 0.5, s * 0.4)
  col(C.cream); for i = 0, 3 do circ(cx - s * 0.19 + i * s * 0.125, cy + s * 0.3, s * 0.065) end
  eye(cx - s * 0.1, cy - s * 0.12, s * 0.06); eye(cx + s * 0.1, cy - s * 0.12, s * 0.06)
  col(C.ink); lg.ellipse("fill", cx, cy + s * 0.08, s * 0.05, s * 0.08, 6)
end

function D.skeleton(cx, cy, s)
  col(C.inkSoft); lg.ellipse("fill", cx, cy + s * 0.35, s * 0.4, s * 0.1, 10)
  Theme.skull(cx, cy - s * 0.12, s * 0.18, C.creamDark)
  col(C.creamDark); lg.setLineWidth(math.max(1, s * 0.04))
  lg.line(cx, cy + s * 0.05, cx, cy + s * 0.3); lg.line(cx - s * 0.2, cy + s * 0.12, cx + s * 0.2, cy + s * 0.12); lg.line(cx - s * 0.15, cy + s * 0.22, cx + s * 0.15, cy + s * 0.22)
  lg.setLineWidth(1)
end

function D.tentacles(cx, cy, s, _, c)
  col(c); lg.setLineWidth(math.max(1, s * 0.07))
  for i = -2, 2 do local x0 = cx + i * s * 0.14; lg.line(x0, cy, x0 + i * s * 0.05, cy + s * 0.25, x0 - i * s * 0.08, cy + s * 0.45) end
  lg.setLineWidth(1)
  lg.ellipse("fill", cx, cy - s * 0.08, s * 0.33, s * 0.25, 12)
  eye(cx - s * 0.12, cy - s * 0.1, s * 0.06); eye(cx + s * 0.12, cy - s * 0.1, s * 0.06)
end

function D.fly(cx, cy, s)
  col(C.inkSoft)
  local pts = {}
  for i = 0, 16 do pts[#pts + 1] = cx - s * 0.4 + i * s * 0.05; pts[#pts + 1] = cy + s * 0.3 - math.sin(i * 0.9) * s * 0.12 - i * s * 0.03 end
  lg.line(pts)
  col(C.ink); lg.ellipse("fill", cx + s * 0.38, cy - s * 0.25, s * 0.07, s * 0.05, 6)
  col(C.white[1], C.white[2], C.white[3], 0.7); lg.ellipse("fill", cx + s * 0.33, cy - s * 0.33, s * 0.07, s * 0.03, 6); lg.ellipse("fill", cx + s * 0.43, cy - s * 0.33, s * 0.07, s * 0.03, 6)
end

function D.pig(cx, cy, s, _, crown)
  col(Theme.rgb("#efb8a8")); lg.ellipse("fill", cx, cy + s * 0.05, s * 0.36, s * 0.3, 12); circ(cx, cy - s * 0.08, s * 0.2)
  col(Theme.rgb("#d98f80")); lg.ellipse("fill", cx, cy, s * 0.09, s * 0.06, 6)
  col(C.ink); circ(cx - s * 0.03, cy, 1); circ(cx + s * 0.03, cy, 1)
  eye(cx - s * 0.09, cy - s * 0.12, math.max(1.5, s * 0.035)); eye(cx + s * 0.09, cy - s * 0.12, math.max(1.5, s * 0.035))
  col(Theme.rgb("#efb8a8")); lg.polygon("fill", cx - s * 0.18, cy - s * 0.18, cx - s * 0.1, cy - s * 0.3, cx - s * 0.06, cy - s * 0.16); lg.polygon("fill", cx + s * 0.18, cy - s * 0.18, cx + s * 0.1, cy - s * 0.3, cx + s * 0.06, cy - s * 0.16)
  if crown then Theme.crown(cx, cy - s * 0.32, s * 0.1) end
  col(C.gold); for i = -2, 2 do circ(cx + i * s * 0.12, cy + s * 0.36, s * 0.05) end
end

function D.flask(cx, cy, s, _, c)
  col(C.creamDark); lg.rectangle("fill", cx - s * 0.08, cy - s * 0.4, s * 0.16, s * 0.2)
  col(C.inkSoft); lg.rectangle("fill", cx - s * 0.1, cy - s * 0.45, s * 0.2, s * 0.07)
  col(c); circ(cx, cy + s * 0.1, s * 0.3)
  col(C.white[1], C.white[2], C.white[3], 0.5); circ(cx - s * 0.1, cy, s * 0.07)
  col(C.ink); lg.circle("line", cx, cy + s * 0.1, s * 0.3, 12)
end

function D.bottle(cx, cy, s)
  col(Theme.rgb("#cfe4ec")); lg.rectangle("fill", cx - s * 0.15, cy - s * 0.1, s * 0.3, s * 0.5, 2, 2); lg.rectangle("fill", cx - s * 0.06, cy - s * 0.4, s * 0.12, s * 0.32)
  col(C.inkSoft); lg.rectangle("fill", cx - s * 0.07, cy - s * 0.45, s * 0.14, s * 0.06)
  col(C.cream); lg.rectangle("fill", cx - s * 0.11, cy + s * 0.05, s * 0.22, s * 0.2)
  col(C.ink); lg.rectangle("line", cx - s * 0.15, cy - s * 0.1, s * 0.3, s * 0.5, 2, 2)
end

function D.weapon(cx, cy, s, name)
  local n = name:lower()
  col(Theme.rgb("#8a5a2b")); lg.setLineWidth(math.max(1, s * 0.07))
  lg.line(cx - s * 0.3, cy + s * 0.35, cx + s * 0.15, cy - s * 0.2)
  local tipx, tipy = cx + s * 0.15, cy - s * 0.2
  if n:find("kupa") then
    col(Theme.rgb("#8b6b3a")); circ(tipx, tipy - s * 0.08, s * 0.1); circ(tipx - s * 0.06, tipy, s * 0.09); circ(tipx + s * 0.05, tipy + s * 0.01, s * 0.07)
    col(C.inkSoft); lg.setLineWidth(1); lg.line(tipx, tipy - s * 0.2, tipx + s * 0.05, tipy - s * 0.35)
  elseif n:find("pała") then
    col(Theme.rgb("#8a5a2b")); lg.setLineWidth(math.max(2, s * 0.16)); lg.line(cx - s * 0.05, cy + s * 0.05, tipx + s * 0.1, tipy - s * 0.12)
  elseif n:find("cep") then
    col(C.inkSoft); lg.setLineWidth(1); lg.line(tipx, tipy, tipx + s * 0.15, tipy - s * 0.1)
    col(Theme.rgb("#8a5a2b")); lg.setLineWidth(math.max(2, s * 0.09)); lg.line(tipx + s * 0.15, tipy - s * 0.1, tipx + s * 0.3, tipy + s * 0.15)
  elseif n:find("kosa") then
    col(Theme.rgb("#b8c0c8")); lg.setLineWidth(math.max(2, s * 0.06)); lg.arc("line", "open", tipx + s * 0.1, tipy + s * 0.15, s * 0.35, math.pi * 1.1, math.pi * 1.75, 8)
  elseif n:find("sierp") then
    col(Theme.rgb("#b8c0c8")); lg.setLineWidth(math.max(2, s * 0.06)); lg.arc("line", "open", tipx - s * 0.05, tipy - s * 0.05, s * 0.25, math.pi * 1.2, math.pi * 2.1, 8)
  elseif n:find("siekiera") then
    col(Theme.rgb("#b8c0c8")); lg.polygon("fill", tipx - s * 0.05, tipy - s * 0.1, tipx + s * 0.25, tipy - s * 0.3, tipx + s * 0.3, tipy + s * 0.05, tipx + s * 0.05, tipy + s * 0.08)
  elseif n:find("widły") then
    col(Theme.rgb("#b8c0c8")); lg.setLineWidth(math.max(1, s * 0.04))
    for i = -1, 1 do lg.line(tipx + i * s * 0.09, tipy - i * s * 0.09 + s * 0.02, tipx + s * 0.2 + i * s * 0.1, tipy - s * 0.25 + i * s * 0.02) end
    lg.line(tipx - s * 0.12, tipy - s * 0.05, tipx + s * 0.1, tipy + s * 0.12)
  elseif n:find("kołek") then
    col(Theme.rgb("#c9a06a")); lg.setLineWidth(math.max(2, s * 0.12)); lg.line(cx - s * 0.2, cy + s * 0.25, tipx, tipy)
    col(C.creamDark); lg.polygon("fill", tipx - s * 0.06, tipy + s * 0.06, tipx + s * 0.06, tipy - s * 0.06, tipx + s * 0.15, tipy - s * 0.2)
  else
    col(Theme.rgb("#d0d6dc")); lg.setLineWidth(math.max(2, s * 0.09)); lg.line(cx - s * 0.1, cy + s * 0.12, tipx + s * 0.2, tipy - s * 0.25)
    col(C.gold); lg.setLineWidth(math.max(1, s * 0.05)); lg.line(cx - s * 0.2, cy + s * 0.03, cx - s * 0.02, cy + s * 0.2)
  end
  lg.setLineWidth(1)
end

function D.pants(cx, cy, s)
  col(Theme.rgb("#9a6a3c"))
  lg.polygon("fill", cx - s * 0.25, cy - s * 0.35, cx + s * 0.25, cy - s * 0.35, cx + s * 0.3, cy + s * 0.4, cx + s * 0.08, cy + s * 0.4, cx, cy - s * 0.05, cx - s * 0.08, cy + s * 0.4, cx - s * 0.3, cy + s * 0.4)
  col(C.ink); lg.line(cx - s * 0.25, cy - s * 0.28, cx + s * 0.25, cy - s * 0.28)
end
function D.bomb(cx, cy, s)
  col(Theme.rgb("#a2451f")); circ(cx, cy, s * 0.3); col(C.ink); lg.circle("line", cx, cy, s * 0.3, 12)
  Theme.skull(cx, cy, s * 0.1, C.cream)
  col(C.inkSoft); lg.line(cx, cy - s * 0.3, cx + s * 0.15, cy - s * 0.45); col(C.gold); circ(cx + s * 0.17, cy - s * 0.47, math.max(1.5, s * 0.05))
end
function D.spikes(cx, cy, s)
  col(C.inkSoft); for i = -2, 2 do lg.line(cx + i * s * 0.12, cy + s * 0.35, cx + i * s * 0.12 + s * 0.05, cy - s * 0.3) end
  col(Theme.rgb("#5aa02c")); for i = -2, 2 do circ(cx + i * s * 0.12 + s * 0.05, cy - s * 0.3, math.max(1.5, s * 0.04)) end
end
function D.peas(cx, cy, s)
  col(Theme.rgb("#6f9a2a")); lg.ellipse("fill", cx, cy, s * 0.35, s * 0.15, 10)
  col(Theme.rgb("#9bcf4b")); for i = -2, 2 do circ(cx + i * s * 0.13, cy, s * 0.06) end
end
function D.goat(cx, cy, s)
  col(C.creamDark); lg.polygon("fill", cx - s * 0.1, cy - s * 0.2, cx - s * 0.35, cy - s * 0.45, cx - s * 0.05, cy - s * 0.3); lg.polygon("fill", cx + s * 0.1, cy - s * 0.2, cx + s * 0.35, cy - s * 0.45, cx + s * 0.05, cy - s * 0.3)
  col(Theme.rgb("#9c8c7a")); lg.ellipse("fill", cx, cy, s * 0.22, s * 0.3, 10)
  eye(cx - s * 0.08, cy - s * 0.08, math.max(1.5, s * 0.04)); eye(cx + s * 0.08, cy - s * 0.08, math.max(1.5, s * 0.04))
  col(C.inkSoft); lg.polygon("fill", cx - s * 0.06, cy + s * 0.25, cx + s * 0.06, cy + s * 0.25, cx, cy + s * 0.45)
end
function D.bucket(cx, cy, s)
  col(Theme.rgb("#8a6a4a")); lg.polygon("fill", cx - s * 0.3, cy - s * 0.2, cx + s * 0.3, cy - s * 0.2, cx + s * 0.22, cy + s * 0.35, cx - s * 0.22, cy + s * 0.35)
  col(Theme.rgb("#7fa31f")); lg.ellipse("fill", cx, cy - s * 0.2, s * 0.3, s * 0.1, 10); for i = -1, 1 do lg.ellipse("fill", cx + i * s * 0.15, cy - s * 0.28, s * 0.07, s * 0.1, 6) end
end
function D.herbs(cx, cy, s, _, c)
  col(c or C.blue); lg.setLineWidth(1)
  for i = -2, 2 do lg.line(cx, cy + s * 0.4, cx + i * s * 0.15, cy - s * 0.3); lg.ellipse("fill", cx + i * s * 0.15, cy - s * 0.3, s * 0.07, s * 0.12, 6) end
end
function D.cauldron(cx, cy, s, _, c)
  col(c or C.blue); for i = -2, 2 do circ(cx + i * s * 0.12, cy - s * 0.25 - math.abs(i) * s * 0.05, s * 0.07) end
  col(C.black); lg.ellipse("fill", cx, cy + s * 0.1, s * 0.32, s * 0.28, 12)
  col(Theme.rgb("#444444")); lg.ellipse("fill", cx, cy - s * 0.12, s * 0.32, s * 0.08, 10)
  col(C.red); lg.polygon("fill", cx - s * 0.2, cy + s * 0.45, cx + s * 0.2, cy + s * 0.45, cx, cy + s * 0.3)
end
function D.orb(cx, cy, s, _, c)
  col(C.white); lg.arc("line", "open", cx, cy, s * 0.36, math.pi * 0.2, math.pi * 1.6, 10)
  col(c or C.blue); circ(cx, cy, s * 0.25)
  col(C.white[1], C.white[2], C.white[3], 0.6); circ(cx - s * 0.08, cy - s * 0.08, s * 0.07)
end
function D.mask(cx, cy, s, _, c)
  col(Theme.rgb("#1d2a44")); lg.rectangle("fill", cx - s * 0.45, cy - s * 0.45, s * 0.9, s * 0.9, 2, 2)
  col(C.gold); circ(cx + s * 0.3, cy - s * 0.3, s * 0.08)
  col(c or Theme.rgb("#6b3e2e")); lg.ellipse("fill", cx, cy + s * 0.05, s * 0.28, s * 0.32, 12)
  col(C.creamDark); lg.polygon("fill", cx - s * 0.25, cy - s * 0.15, cx - s * 0.1, cy - s * 0.4, cx - s * 0.05, cy - s * 0.12); lg.polygon("fill", cx + s * 0.25, cy - s * 0.15, cx + s * 0.1, cy - s * 0.4, cx + s * 0.05, cy - s * 0.12)
  eye(cx - s * 0.1, cy - s * 0.02, s * 0.06); eye(cx + s * 0.1, cy - s * 0.02, s * 0.06)
  col(C.white); for i = -1, 1 do lg.polygon("fill", cx + i * s * 0.09 - s * 0.03, cy + s * 0.15, cx + i * s * 0.09 + s * 0.03, cy + s * 0.15, cx + i * s * 0.09, cy + s * 0.25) end
end
function D.villager(cx, cy, s)
  col(Theme.rgb("#f0c9a0")); circ(cx, cy - s * 0.2, s * 0.14)
  col(Theme.rgb("#6d8a3a")); lg.rectangle("fill", cx - s * 0.15, cy - s * 0.05, s * 0.3, s * 0.3, 1, 1)
  col(C.ink); lg.setLineWidth(math.max(1, s * 0.04)); lg.line(cx - s * 0.1, cy + s * 0.25, cx - s * 0.12, cy + s * 0.45); lg.line(cx + s * 0.1, cy + s * 0.25, cx + s * 0.12, cy + s * 0.45)
  col(Theme.rgb("#8a5a2b")); lg.line(cx + s * 0.15, cy + s * 0.05, cx + s * 0.4, cy - s * 0.3); lg.setLineWidth(1)
  col(C.ink); circ(cx - s * 0.05, cy - s * 0.22, 1); circ(cx + s * 0.05, cy - s * 0.22, 1)
end
function D.hyena(cx, cy, s)
  col(Theme.rgb("#b59a6a")); lg.ellipse("fill", cx, cy + s * 0.05, s * 0.3, s * 0.25, 12)
  lg.polygon("fill", cx - s * 0.25, cy - s * 0.15, cx - s * 0.35, cy - s * 0.45, cx - s * 0.1, cy - s * 0.25); lg.polygon("fill", cx + s * 0.25, cy - s * 0.15, cx + s * 0.35, cy - s * 0.45, cx + s * 0.1, cy - s * 0.25)
  col(C.inkSoft); for i = -2, 2 do circ(cx + i * s * 0.1, cy - s * 0.05 + (i % 2) * s * 0.08, math.max(1, s * 0.03)) end
  eye(cx - s * 0.1, cy - s * 0.05, s * 0.05, 1); eye(cx + s * 0.1, cy - s * 0.05, s * 0.05, -1)
  col(C.ink); lg.arc("fill", cx, cy + s * 0.12, s * 0.15, 0.1, math.pi - 0.1, 8)
  col(C.white); for i = -2, 2 do lg.polygon("fill", cx + i * s * 0.06 - s * 0.02, cy + s * 0.13, cx + i * s * 0.06 + s * 0.02, cy + s * 0.13, cx + i * s * 0.06, cy + s * 0.2) end
end
function D.vampire(cx, cy, s)
  col(C.black); lg.polygon("fill", cx - s * 0.1, cy - s * 0.1, cx + s * 0.4, cy - s * 0.1, cx + s * 0.45, cy + s * 0.45, cx - s * 0.15, cy + s * 0.45)
  col(Theme.rgb("#e8dcc8")); circ(cx + s * 0.15, cy - s * 0.2, s * 0.13)
  col(C.black); lg.rectangle("fill", cx - s * 0.02, cy - s * 0.4, s * 0.34, s * 0.1); lg.rectangle("fill", cx + s * 0.05, cy - s * 0.5, s * 0.2, s * 0.12)
  col(C.white); lg.polygon("fill", cx + s * 0.1, cy - s * 0.12, cx + s * 0.14, cy - s * 0.12, cx + s * 0.12, cy - s * 0.04)
  col(Theme.rgb("#cfe4ec")); lg.polygon("fill", cx - s * 0.4, cy - s * 0.35, cx - s * 0.15, cy - s * 0.35, cx - s * 0.2, cy, cx - s * 0.35, cy)
  col(C.red); lg.polygon("fill", cx - s * 0.37, cy - s * 0.2, cx - s * 0.18, cy - s * 0.2, cx - s * 0.2, cy, cx - s * 0.35, cy)
  col(C.inkSoft); lg.line(cx - s * 0.275, cy, cx - s * 0.275, cy + s * 0.18); lg.line(cx - s * 0.35, cy + s * 0.18, cx - s * 0.2, cy + s * 0.18)
end
function D.fists(cx, cy, s, two)
  local function fist(x, y)
    col(Theme.rgb("#f0c9a0")); lg.rectangle("fill", x - s * 0.15, y - s * 0.12, s * 0.3, s * 0.25, 2, 2)
    col(C.ink); for i = 0, 3 do lg.line(x - s * 0.13 + i * s * 0.08, y - s * 0.12, x - s * 0.13 + i * s * 0.08, y + s * 0.02) end
    col(Theme.rgb("#6d8a3a")); lg.rectangle("fill", x - s * 0.45, y - s * 0.08, s * 0.3, s * 0.18)
  end
  if two then fist(cx - s * 0.15, cy - s * 0.1); fist(cx + s * 0.25, cy + s * 0.1)
  else fist(cx + s * 0.05, cy); Theme.star(cx + s * 0.3, cy - s * 0.3, s * 0.08, C.gold) end
end
function D.healer(cx, cy, s)
  D.villager(cx - s * 0.1, cy, s)
  col(Theme.rgb("#5a3a7a")); lg.rectangle("fill", cx - s * 0.27, cy - s * 0.4, s * 0.3, s * 0.08)
  col(C.coin); for i = 0, 2 do circ(cx + s * 0.3, cy + s * 0.3 - i * s * 0.08, s * 0.07) end
  Theme.heart(cx + s * 0.3, cy - s * 0.1, s * 0.08)
end
function D.wheel(cx, cy, s)
  col(C.inkSoft); lg.line(cx, cy, cx, cy + s * 0.45)
  for i = 0, 7 do col(i % 2 == 0 and C.red or C.cream); lg.arc("fill", cx, cy - s * 0.05, s * 0.32, i * math.pi / 4, (i + 1) * math.pi / 4, 4) end
  col(C.ink); lg.circle("line", cx, cy - s * 0.05, s * 0.32, 12); circ(cx, cy - s * 0.05, math.max(1.5, s * 0.04))
  col(C.gold); lg.polygon("fill", cx - s * 0.05, cy - s * 0.45, cx + s * 0.05, cy - s * 0.45, cx, cy - s * 0.33)
end
function D.chest(cx, cy, s)
  col(Theme.rgb("#8a5a2b")); lg.rectangle("fill", cx - s * 0.35, cy - s * 0.1, s * 0.7, s * 0.4, 2, 2)
  col(Theme.rgb("#6b4420")); lg.rectangle("fill", cx - s * 0.35, cy - s * 0.3, s * 0.7, s * 0.22, 3, 3)
  col(C.gold); lg.rectangle("fill", cx - s * 0.05, cy - s * 0.12, s * 0.1, s * 0.12)
  for i = -2, 2 do Theme.coin(cx + i * s * 0.14, cy - s * 0.3 - math.abs(i) * s * 0.03, math.max(1.5, s * 0.06)) end
  col(C.ink); lg.rectangle("line", cx - s * 0.35, cy - s * 0.1, s * 0.7, s * 0.4, 2, 2)
end
function D.oldman(cx, cy, s)
  col(Theme.rgb("#5a4a3a")); lg.rectangle("fill", cx - s * 0.16, cy - s * 0.05, s * 0.32, s * 0.45, 2, 2)
  col(Theme.rgb("#e8dcc8")); circ(cx, cy - s * 0.2, s * 0.13)
  col(C.white); lg.polygon("fill", cx - s * 0.1, cy - s * 0.12, cx + s * 0.1, cy - s * 0.12, cx, cy + s * 0.12)
  col(Theme.rgb("#8a5a2b")); lg.line(cx + s * 0.28, cy - s * 0.4, cx + s * 0.3, cy + s * 0.45)
  Theme.star(cx - s * 0.32, cy - s * 0.3, s * 0.06, C.gold); Theme.star(cx - s * 0.2, cy - s * 0.42, s * 0.04, C.gold)
end
function D.scroll(cx, cy, s)
  col(C.creamDark); lg.rectangle("fill", cx - s * 0.3, cy - s * 0.35, s * 0.6, s * 0.7, 2, 2)
  col(C.inkSoft); for i = 0, 4 do lg.line(cx - s * 0.2, cy - s * 0.2 + i * s * 0.12, cx + s * 0.2, cy - s * 0.2 + i * s * 0.12) end
end

local monsterSpecial = { Arachna = "spider", Bagiennik = "frog", ["Wilkołak"] = "wolf", Czort = "devil", Zmora = "ghost", Nocnica = "ghost", ["Cmentarny dziad"] = "skeleton", Utopiec = "tentacles", Szambiarka = "skeleton" }
local villageByKey = {
  { "kalesony", "pants" }, { "bomba", "bomb" }, { "kolce", "spikes" }, { "groch", "peas" }, { "capa", "goat" }, { "kiszonka", "bucket" },
  { "ziele", "herbs" }, { "bunclok", "cauldron" }, { "szpirytus", "bottle" }, { "mana", "orb" }, { "przebranie", "mask" },
  { "krzywy", "villager" }, { "hiena", "hyena" }, { "wampir", "vampire" }, { "mój ci on", "fist" }, { "ustawka", "fists" }, { "świnia", "pig" },
}
local eventByKey = { { "mucha", "fly" }, { "znachor", "healer" }, { "loteria", "wheel" }, { "wieprz", "pigplain" }, { "gorzoła", "bottle" }, { "strzeżone", "chest" }, { "dziad", "oldman" } }

function Art.illustration(card, cx, cy, s)
  local h = hash(card.name)
  local c = Theme.colorOf[card.color] or C.inkSoft
  if card.kind == "monster" then
    local sp = monsterSpecial[card.name]
    if sp then D[sp](cx, cy, s, h, c) else D.creature(cx, cy, s, h, c) end
  elseif card.kind == "event" then
    local lname = card.name:lower()
    for _, kv in ipairs(eventByKey) do
      if lname:find(kv[1], 1, true) then
        if kv[2] == "pigplain" then D.pig(cx, cy, s, h, false) else D[kv[2]](cx, cy, s, h, c) end
        return
      end
    end
    D.scroll(cx, cy, s)
  elseif card.kind == "weapon" then D.weapon(cx, cy, s, card.name)
  elseif card.kind == "potion" then
    D.flask(cx, cy, s, h, card.effect == "heal" and C.red or (card.effect == "extra_die" and Theme.rgb("#3aa88a") or C.yellow))
  else
    local lname = card.name:lower()
    for _, kv in ipairs(villageByKey) do
      if lname:find(kv[1], 1, true) then
        if kv[2] == "fist" then D.fists(cx, cy, s, false)
        elseif kv[2] == "fists" then D.fists(cx, cy, s, true)
        elseif kv[2] == "pig" then D.pig(cx, cy, s, h, lname:find("pazerna") ~= nil)
        elseif kv[2] == "mask" then D.mask(cx, cy, s, h, card.color ~= "yellow" and c or nil)
        else D[kv[2]](cx, cy, s, h, (card.kind == "bonus") and c or nil) end
        return
      end
    end
    D.herbs(cx, cy, s, h, c)
  end
end


-- ------------------------------------------------------------ sprite'y pixel-art
-- Ilustracja jest rysowana raz do małej kanwy 20x20 (portret 16x16), a potem powiększana
-- całkowitym mnożnikiem – dzięki temu każda ilustracja ma wyraźne, równe piksele.
local SPR = 20
local sprites, portraits = {}, {}

local function withCanvas(c, fn)
  local prev = lg.getCanvas()
  lg.push("all")
  lg.origin()
  lg.setStencilTest()
  lg.setCanvas(c)
  lg.clear(0, 0, 0, 0)
  lg.setLineStyle("rough")
  fn()
  lg.pop()
  if prev then lg.setCanvas({ prev, stencil = true }) else lg.setCanvas() end
end

function Art.sprite(card)
  local key = card.kind .. "|" .. card.name .. "|" .. tostring(card.color)
  local c = sprites[key]
  if c then return c end
  c = lg.newCanvas(SPR, SPR)
  c:setFilter("nearest", "nearest")
  withCanvas(c, function() Art.illustration(card, SPR / 2, SPR / 2 - 1, SPR * 0.9) end)
  sprites[key] = c
  return c
end

function Art.portraitSprite(ch)
  local c = portraits[ch.name]
  if c then return c end
  c = lg.newCanvas(16, 16)
  c:setFilter("nearest", "nearest")
  withCanvas(c, function() Art.portrait(ch, 8, 8, 18) end)
  portraits[ch.name] = c
  return c
end

local function drawSprite(spr, cx, cy, k)
  lg.setColor(1, 1, 1, 1)
  local w, h = spr:getWidth() * k, spr:getHeight() * k
  lg.draw(spr, floor(cx - w / 2), floor(cy - h / 2), 0, k, k)
end

-- ------------------------------------------------------------- elementy kart
local function seal(x, y, r, c, label, font)
  x, y = floor(x), floor(y)
  col(C.shadow); circ(x, y + 1, r)
  col(c); circ(x, y, r)
  col(C.ink); lg.circle("line", x, y, r, 10)
  if label then Theme.centerText(label, x, y, { font = font or "tinyB", color = C.white, shadow = true }) end
end

local function ribbon(x, y, w, h, c, label, font)
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  col(C.shadow); lg.polygon("fill", x + 1, y + 1, x + w + 1, y + 1, x + w + 1, y + h + 1, x + w / 2 + 1, y + h * 0.75 + 1, x + 1, y + h + 1)
  col(c); lg.polygon("fill", x, y, x + w, y, x + w, y + h, x + w / 2, y + h * 0.75, x, y + h)
  col(C.ink); lg.polygon("line", x + 0.5, y + 0.5, x + w - 0.5, y + 0.5, x + w - 0.5, y + h - 0.5, x + w / 2, y + h * 0.75, x + 0.5, y + h - 0.5)
  if label then Theme.centerText(label, x + w / 2, y + h * 0.38, { font = font or "smallB", color = C.white, shadow = true }) end
end

local function flag(x, y, w, h, c)
  col(c); lg.polygon("fill", x, y, x + w, y, x + w, y + h, x + w / 2, y + h * 0.7, x, y + h)
  col(C.ink); lg.polygon("line", x + 0.5, y + 0.5, x + w - 0.5, y + 0.5, x + w - 0.5, y + h - 0.5, x + w / 2, y + h * 0.7, x + 0.5, y + h - 0.5)
end

local function wrap(str, x, y, w, font, color, maxH)
  if maxH and Theme.textHeight(str, font, w) > maxH then
    local f = Theme.fonts[font]
    local _, lines = f:getWrap(str, w)
    local n = math.max(1, floor(maxH / f:getHeight()))
    local t = {}
    for i = 1, math.min(n, #lines) do t[i] = lines[i] end
    if #lines > n then t[n] = Theme.cut(t[n], (require("utf8").len(t[n]) or #t[n]) - 2) .. "…" end
    str = table.concat(t, "\n")
  end
  Theme.text(str, x, y, { font = font, color = color, width = w, align = "center" })
end

local function cardText(card)
  if card.kind == "monster" then return card.flavor end
  return card.text or card.flavor
end

-- rama karty: cień, teksturowany papier, podwójna pikselowa ramka
local function cardFrame(x, y, w, h, r, tileName, outline, thick)
  col(C.shadow); lg.rectangle("fill", x + 1, y + 2, w, h, r, r)
  lg.stencil(function() lg.rectangle("fill", x, y, w, h, r, r) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  Theme.tiled(tileName, x, y, w, h)
  lg.setStencilTest()
  col(outline or C.ink)
  if thick then lg.setLineWidth(2); lg.rectangle("line", x + 1, y + 1, w - 2, h - 2, r, r); lg.setLineWidth(1)
  else lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r) end
end

-- -------------------------------------------------------------- karta (awers)
-- opts: selected, dim, faceDown, highlight (kolor ramki), alpha
function Art.draw(card, x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  if opts.faceDown then return Art.drawBack(card and card.deck, x, y, w, h, opts) end
  local r = w >= 60 and 4 or 3
  local big, mid = w >= 100, w >= 70
  local kind = card.kind
  local c = Theme.colorOf[card.color] or C.inkSoft
  cardFrame(x, y, w, h, r, "paper", opts.selected and C.highlight or opts.highlight, opts.selected or opts.highlight)
  -- wewnętrzna ramka
  col(C.creamDark); lg.rectangle("line", x + 2.5, y + 2.5, w - 5, h - 5, r - 1, r - 1)
  if kind == "black" then
    col(C.panel); lg.rectangle("fill", x + 1, y + floor(h * 0.55), w - 2, h - floor(h * 0.55) - 1, r, r); lg.rectangle("fill", x + 1, y + floor(h * 0.55), w - 2, 6)
  elseif kind == "potion" then
    col(C.creamDark); lg.rectangle("fill", x + 1, y + floor(h * 0.6), w - 2, h - floor(h * 0.6) - 1, r, r); lg.rectangle("fill", x + 1, y + floor(h * 0.6), w - 2, 6)
  end
  -- ilustracja (sprite, całkowity mnożnik)
  local k = math.max(1, math.min(4, floor(w / 26)))
  local illY = y + h * (mid and 0.33 or 0.44)
  local illX = (kind == "disguise" or kind == "special") and (x + w * 0.58) or (x + w / 2)
  drawSprite(Art.sprite(card), illX, illY, k)
  if kind == "monster" then
    ribbon(x + 3, y - 1, mid and 14 or 11, mid and 20 or 15, c, tostring(card.strength), mid and "smallB" or "tinyB")
    local iy = y + (mid and 26 or 18)
    local ir = mid and 4 or 3
    if card.fame > 0 then col(C.inkSoft); circ(x + 9, iy, ir + 1); Theme.star(x + 9, iy, ir, C.star); iy = iy + ir * 2 + 3 end
    for _ = 1, card.coins do Theme.coin(x + 9, iy, ir); iy = iy + ir * 2 + 2 end
  elseif kind == "bonus" then
    seal(x + 8, y + 8, mid and 7 or 6, c, "+" .. card.power)
  elseif kind == "disguise" or kind == "special" then
    local bw = mid and 10 or 8
    col(c); lg.rectangle("fill", x + 3, y - 1, bw, floor(h * 0.62))
    col(C.ink); lg.rectangle("line", x + 3.5, y - 0.5, bw - 1, floor(h * 0.62) - 1)
    if (card.power or 0) > 0 then seal(x + 3 + bw / 2, y + 7, mid and 6 or 5, c, "+1") end
    if mid then
      lg.push(); lg.translate(x + 3 + bw / 2 + 1, y + h * 0.6 - 2); lg.rotate(-math.pi / 2)
      Theme.text(card.name:upper(), 0, -5, { font = "tinyB", color = C.white, shadow = true, width = h * 0.6 - 14, align = "left" })
      lg.pop()
    end
  elseif kind == "black" then
    seal(x + 8, y + 8, mid and 7 or 6, C.black); Theme.skull(x + 8, y + 8, mid and 4 or 3, C.cream)
  elseif kind == "weapon" or kind == "potion" then
    local cols = {}
    if kind == "weapon" then for _, cc in ipairs(Cards.COLORS) do if card.bonus[cc] then cols[#cols + 1] = cc end end else cols = { "purple" } end
    for i, cc in ipairs(cols) do flag(x + 3 + (i - 1) * 7, y - 1, 7, 12, cc == "purple" and C.purple or Theme.colorOf[cc]) end
    for i = 1, card.price do Theme.coin(x + w - 7, y + 6 + (i - 1) * 5, 3) end
  elseif kind == "event" then
    flag(x + 3, y - 1, 8, 12, C.creamDark)
  end
  if mid then
    local ny = y + floor(h * 0.6)
    local nameFont = big and "body" or "small"
    if kind == "black" then
      Theme.centerText(card.name:upper(), x + w / 2, y + floor(h * 0.62), { font = "tinyB", color = C.white, width = w - 6 })
      if big then wrap(cardText(card) or "", x + 4, y + floor(h * 0.7), w - 8, "small", C.cream, h * 0.28) end
    elseif kind == "weapon" then
      Theme.centerText(card.name, x + w / 2, ny, { font = nameFont, color = C.ink, width = w - 6 })
      local cols = {}
      for _, cc in ipairs(Cards.COLORS) do if card.bonus[cc] then cols[#cols + 1] = cc end end
      local bw = floor(w / #cols)
      local by = y + floor(h * 0.8)
      for i, cc in ipairs(cols) do
        local ww = (i == #cols) and (w - (i - 1) * bw) or bw
        col(Theme.colorOf[cc]); lg.rectangle("fill", x + (i - 1) * bw + 1, by, ww - 2, h - floor(h * 0.8) - 1, r, r); lg.rectangle("fill", x + (i - 1) * bw + 1, by, ww - 2, 6)
        Theme.centerText("+" .. card.bonus[cc], x + (i - 0.5) * bw, by + (h - floor(h * 0.8)) / 2, { font = big and "largeB" or "smallB", color = C.white, shadow = true })
      end
      if big then wrap(card.flavor or "", x + 4, ny + 10, w - 8, "small", C.inkSoft, h * 0.8 - (ny - y) - 12) end
    elseif kind == "potion" then
      Theme.centerText(card.name, x + w / 2, y + floor(h * 0.66), { font = nameFont, color = C.ink, width = w - 6 })
      if big then wrap(card.text or "", x + 4, y + floor(h * 0.72), w - 8, "small", C.ink, h * 0.26) end
    elseif kind == "disguise" or kind == "special" then
      if big then
        col(C.white[1], C.white[2], C.white[3], 0.75); lg.rectangle("fill", x + 16, y + floor(h * 0.62), w - 20, floor(h * 0.34), 2, 2)
        Theme.text(card.name, x + 18, y + floor(h * 0.63), { font = "body", color = C.ink, width = w - 24 })
        wrap(card.text or "", x + 18, y + floor(h * 0.63) + 12, w - 24, "small", C.ink, h * 0.32 - 12)
      else
        Theme.centerText(card.name, x + 14 + (w - 14) / 2, y + floor(h * 0.78), { font = nameFont, color = C.ink, width = w - 16 })
      end
    else
      Theme.centerText(card.name, x + w / 2, ny, { font = nameFont, color = C.ink, width = w - 6 })
      if big and cardText(card) then wrap(cardText(card), x + 4, ny + 9, w - 8, "small", C.inkSoft, h - (ny - y) - 12) end
    end
  end
  if opts.dim then col(0, 0, 0, 0.5); lg.rectangle("fill", x, y, w, h, r, r) end
end

-- ------------------------------------------------------------------ rewers
local backBanner = { village = { C.yellow, "mask" }, road = { C.black, "skull" }, market = { C.purple, "sword" } }

function Art.drawBack(deck, x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local r = w >= 60 and 4 or 3
  deck = backBanner[deck] and deck or "village"
  cardFrame(x, y, w, h, r, "paper", opts.highlight, opts.highlight ~= nil)
  -- wzór kratki w kolorze talii, z kremowym marginesem
  local m = w >= 40 and 3 or 2
  lg.stencil(function() lg.rectangle("fill", x + m, y + m, w - 2 * m, h - 2 * m, r - 1, r - 1) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  Theme.tiled("back_" .. deck, x + m, y + m, w - 2 * m, h - 2 * m)
  lg.setStencilTest()
  col(C.ink); lg.rectangle("line", x + m + 0.5, y + m + 0.5, w - 2 * m - 1, h - 2 * m - 1, r - 1, r - 1)
  -- emblemat talii
  local b = backBanner[deck]
  local er = math.max(4, floor(w * 0.16))
  col(C.ink); circ(x + w / 2, y + h / 2, er + 1)
  col(b[1]); circ(x + w / 2, y + h / 2, er)
  if b[2] == "skull" then Theme.skull(x + w / 2, y + h / 2, math.max(2, er * 0.5), C.cream)
  elseif b[2] == "sword" then col(C.cream); lg.setLineWidth(math.max(1, floor(er / 4))); lg.line(x + w / 2 - er * 0.55, y + h / 2 + er * 0.55, x + w / 2 + er * 0.55, y + h / 2 - er * 0.55); lg.setLineWidth(1)
  else col(C.ink); lg.rectangle("fill", x + w / 2 - er * 0.5, y + h / 2 - er * 0.3, er, er * 0.6); col(b[1]); circ(x + w / 2 - er * 0.22, y + h / 2 - er * 0.05, math.max(1, er * 0.14)); circ(x + w / 2 + er * 0.22, y + h / 2 - er * 0.05, math.max(1, er * 0.14)) end
end

-- ------------------------------------------------------------------ postać
function Art.portrait(ch, cx, cy, s)
  local h = hash(ch.name)
  local shirt = { Theme.rgb("#6d8a3a"), Theme.rgb("#8a5a2b"), Theme.rgb("#4a5a8a"), Theme.rgb("#a04a4a") }
  col(shirt[hrand(h, 2, 4) + 1]); lg.rectangle("fill", cx - s * 0.2, cy + s * 0.02, s * 0.4, s * 0.34, 1, 1)
  col(Theme.rgb("#f0c9a0")); circ(cx, cy - s * 0.14, s * 0.17)
  col(Theme.rgb("#5a3a1a")); lg.arc("fill", cx, cy - s * 0.18, s * 0.18, math.pi, 2 * math.pi, 8)
  col(C.ink); circ(cx - s * 0.06, cy - s * 0.15, 1); circ(cx + s * 0.06, cy - s * 0.15, 1)
  if hrand(h, 3, 2) == 1 then col(C.ink); lg.rectangle("fill", cx - s * 0.1, cy - s * 0.07, s * 0.2, 2) end
  col(Theme.rgb("#8a5a2b")); lg.line(cx + s * 0.25, cy + s * 0.34, cx + s * 0.42, cy - s * 0.32)
end

-- mały portret (sprite 16x16 × k) w ramce
function Art.drawPortrait(ch, x, y, k)
  local s = 16 * k
  col(C.cream); lg.rectangle("fill", x, y, s + 4, s + 4, 2, 2)
  drawSprite(Art.portraitSprite(ch), x + 2 + s / 2, y + 2 + s / 2, k)
  col(C.ink); lg.rectangle("line", x + 0.5, y + 0.5, s + 3, s + 3, 2, 2)
end

function Art.drawCharacter(ch, x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local r = 4
  cardFrame(x, y, w, h, r, "paper", opts.selected and C.highlight or nil, opts.selected)
  local k = math.max(1, math.min(4, floor(w / 28)))
  drawSprite(Art.portraitSprite(ch), x + w / 2, y + h * 0.25, k)
  local big = w >= 90
  Theme.centerText(ch.name, x + w / 2, y + floor(h * 0.48), { font = big and "body" or "small", color = C.ink, width = w - 4 })
  if big then Theme.centerText(ch.job, x + w / 2, y + floor(h * 0.56), { font = "small", color = C.inkSoft, width = w - 4 }) end
  local bandY = y + floor(h * 0.6)
  col(C.panel); lg.rectangle("fill", x + 1, bandY, w - 2, h - (bandY - y) - 1, r, r); lg.rectangle("fill", x + 1, bandY, w - 2, 6)
  local cols = {}
  for _, cc in ipairs(Cards.COLORS) do if ch.bonus[cc] then cols[#cols + 1] = cc end end
  local bw = big and 16 or 12
  for i, cc in ipairs(cols) do
    col(Theme.colorOf[cc]); lg.rectangle("fill", x + w - 1 - bw * i, bandY, bw, h - (bandY - y) - 1, i == 1 and r or 0, i == 1 and r or 0)
    Theme.centerText("+1", x + w - 1 - bw * i + bw / 2, bandY + (h - (bandY - y)) / 2, { font = "smallB", color = C.white, shadow = true })
  end
  local textW = w - bw * #cols
  if big then
    local maxH = h - (bandY - y) - 5
    local f = Theme.fonts.small
    local _, lines = f:getWrap(ch.traitText, textW - 6)
    local n = math.max(1, floor(maxH / f:getHeight()))
    local txt = ch.traitText
    if #lines > n then
      local last = Theme.cut(lines[n], (require("utf8").len(lines[n]) or #lines[n]) - 2) .. "…"
      txt = (n > 1 and (table.concat(lines, "\n", 1, n - 1) .. "\n") or "") .. last
    end
    Theme.text(txt, x + 3, bandY + 3, { font = "small", color = C.cream, width = textW - 6 })
  end
end

function Art.fameSlotPos(cx, cy, R, i)
  local a = -math.pi / 2 + (i - 1) * math.pi / 3 + math.pi / 6
  return floor(cx + math.cos(a) * R), floor(cy + math.sin(a) * R), math.max(4, R * 0.36)
end

function Art.drawFameRing(cx, cy, R, fame, opts)
  opts = opts or {}
  local legal, removable = {}, {}
  for _, s in ipairs(opts.legal or {}) do legal[s] = true end
  for _, s in ipairs(opts.removable or {}) do removable[s] = true end
  cx, cy = floor(cx), floor(cy)
  col(C.panel); circ(cx, cy, R * 1.5)
  col(C.panelEdge); lg.circle("line", cx, cy, R * 1.5, 16)
  for i = 1, 6 do
    local sx, sy, sr = Art.fameSlotPos(cx, cy, R, i)
    local c = Theme.colorOf[Cards.FAME_RING[i]]
    col(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45); circ(sx, sy, R * 0.3)
    col(c); lg.circle("line", sx, sy, R * 0.3, 10)
    if fame and fame[i] then Theme.star(sx, sy, math.max(2, R * 0.2), C.star) end
    if legal[i] or removable[i] then col(C.highlight); lg.setLineWidth(2); lg.circle("line", sx, sy, sr, 12); lg.setLineWidth(1) end
  end
  col(C.ink); circ(cx, cy, R * 0.32)
  Theme.crown(cx, cy, math.max(2, R * 0.18), (opts.fameCount or 0) >= 7 and C.gold or Theme.rgb("#5a4a2a"))
end

return Art
