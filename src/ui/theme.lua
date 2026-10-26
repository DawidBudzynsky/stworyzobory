-- Motyw pixel-art: gra renderuje się na kanwie 640x360 i jest skalowana całkowitym mnożnikiem
-- (filtr "nearest", linie "rough", brak MSAA), więc każdy element – także wektorowe ilustracje –
-- ma wyraźne piksele. Czcionki: VT323 (tekst) i Pixelify Sans (nagłówki), obie OFL.
local Theme = {}

Theme.VW, Theme.VH = 640, 360
Theme.scale, Theme.ox, Theme.oy = 1, 0, 0

local function rgb(hex, a)
  return { tonumber(hex:sub(2, 3), 16) / 255, tonumber(hex:sub(4, 5), 16) / 255, tonumber(hex:sub(6, 7), 16) / 255, a or 1 }
end
Theme.rgb = rgb

Theme.colors = {
  felt = rgb("#275a46"), feltDark = rgb("#1b3f31"), feltLight = rgb("#2f6b53"),
  cream = rgb("#f3e9d2"), creamDark = rgb("#d9c9a5"), ink = rgb("#1a1a24"), inkSoft = rgb("#6b6478"),
  red = rgb("#d93a3a"), green = rgb("#7fb33a"), blue = rgb("#3b8fdc"), yellow = rgb("#f0b429"), black = rgb("#2c2f3a"),
  purple = rgb("#8a5fc9"), gold = rgb("#ffd454"), coin = rgb("#d9a24c"), coinDark = rgb("#8a5a1c"),
  heart = rgb("#ea3f4a"), star = rgb("#f6f1e4"), shadow = { 0, 0, 0, 0.45 },
  panel = rgb("#232736"), panelLight = rgb("#30354a"), panelEdge = rgb("#4c5370"), white = { 1, 1, 1, 1 },
  btn = rgb("#f08a2e"), btnDark = rgb("#9c4d10"), btnText = rgb("#fff6e5"),
  btn2 = rgb("#3f8fe0"), btn2Dark = rgb("#1f4f8c"), btnDanger = rgb("#e23d3d"), btnDangerDark = rgb("#7e1a1a"),
  btnOk = rgb("#5fbf3a"), btnOkDark = rgb("#2f6b18"), disabled = rgb("#5c5f6e"), disabledDark = rgb("#363845"),
  highlight = rgb("#ffe066"), dim = { 0, 0, 0, 0.6 },
}
Theme.colorOf = { red = Theme.colors.red, green = Theme.colors.green, blue = Theme.colors.blue, yellow = Theme.colors.yellow, black = Theme.colors.black }

-- ------------------------------------------------------------------ fonts
Theme.fonts = {}
local PIX = "assets/fonts/PixelifySans.ttf"
local VT = "assets/fonts/VT323.ttf"
local spec = {
  tiny = { VT, 12 }, small = { VT, 12 }, body = { VT, 14 }, medium = { VT, 16 }, large = { VT, 20 }, title = { VT, 28 }, huge = { VT, 40 },
  tinyB = { PIX, 10 }, smallB = { PIX, 12 }, bodyB = { PIX, 12 }, mediumB = { PIX, 12 }, largeB = { PIX, 16 }, titleB = { PIX, 24 }, hugeB = { PIX, 32 },
}
for k, v in pairs(spec) do spec[k .. "C"] = v end

function Theme.buildFonts()
  if Theme.fontsBuilt then return end
  Theme.fontsBuilt = true
  for name, s in pairs(spec) do
    local f = love.graphics.newFont(s[1], s[2], "mono")
    f:setFilter("nearest", "nearest")
    Theme.fonts[name] = f
  end
end

-- ----------------------------------------------------------------- canvas
function Theme.resize(w, h)
  Theme.scale = math.max(1, math.floor(math.min(w / Theme.VW, h / Theme.VH)))
  Theme.ox = math.floor((w - Theme.VW * Theme.scale) / 2)
  Theme.oy = math.floor((h - Theme.VH * Theme.scale) / 2)
  Theme.buildFonts()
  if not Theme.canvas then
    Theme.canvas = love.graphics.newCanvas(Theme.VW, Theme.VH)
    Theme.canvas:setFilter("nearest", "nearest")
  end
end

function Theme.toVirtual(x, y)
  return math.floor((x - Theme.ox) / Theme.scale), math.floor((y - Theme.oy) / Theme.scale)
end

-- rysowanie do kanwy, potem skalowanie
function Theme.push()
  love.graphics.setCanvas({ Theme.canvas, stencil = true })
  love.graphics.clear(Theme.colors.feltDark)
  love.graphics.setLineStyle("rough")
  love.graphics.setLineWidth(1)
end

function Theme.pop()
  love.graphics.setCanvas()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(Theme.canvas, Theme.ox, Theme.oy, 0, Theme.scale, Theme.scale)
end

-- ---------------------------------------------------------------- drawing
local lg = love.graphics
local floor = math.floor

function Theme.roundRect(mode, x, y, w, h, r, color)
  if color then lg.setColor(color) end
  lg.rectangle(mode, floor(x), floor(y), floor(w), floor(h), r or 3, r or 3)
end

-- panel w stylu Balatro: cień 2px pod spodem, wypełnienie, jasna krawędź
function Theme.panel(x, y, w, h, opts)
  opts = opts or {}
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  local r = opts.radius or 4
  local sh = opts.shadow or 2
  if sh > 0 then
    lg.setColor(Theme.colors.shadow)
    lg.rectangle("fill", x, y + sh, w, h, r, r)
  end
  lg.setColor(opts.fill or Theme.colors.panel)
  lg.rectangle("fill", x, y, w, h, r, r)
  if opts.border ~= false then
    lg.setLineWidth(opts.lineWidth or 1)
    lg.setColor(opts.border or Theme.colors.panelEdge)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r)
    lg.setLineWidth(1)
  end
end

function Theme.text(str, x, y, opts)
  opts = opts or {}
  local font = Theme.fonts[opts.font or "body"]
  lg.setFont(font)
  local w = opts.width or 2000
  local align = opts.align or "left"
  x, y = floor(x), floor(y)
  if opts.outline then
    lg.setColor(opts.outline)
    lg.printf(str, x + 1, y + 1, w, align)
    lg.printf(str, x - 1, y + 1, w, align)
    lg.printf(str, x + 1, y - 1, w, align)
    lg.printf(str, x - 1, y - 1, w, align)
  elseif opts.shadow ~= false and (opts.font or ""):find("B") then
    lg.setColor(0, 0, 0, 0.6)
    lg.printf(str, x + 1, y + 1, w, align)
  end
  lg.setColor(opts.color or Theme.colors.cream)
  lg.printf(str, x, y, w, align)
end

-- obcina napis do n znaków (bezpiecznie dla UTF-8)
function Theme.cut(str, n)
  local utf8 = require("utf8")
  local len = utf8.len(str) or #str
  if n >= len then return str end
  if n <= 0 then return "" end
  return str:sub(1, utf8.offset(str, n + 1) - 1)
end

-- skraca tekst wielokropkiem, aby zmieścił się w szerokości w
function Theme.fit(str, font, w)
  local f = Theme.fonts[font or "body"]
  if f:getWidth(str) <= w then return str end
  local utf8 = require("utf8")
  local n = utf8.len(str) or #str
  while n > 1 do
    n = n - 1
    local cut = str:sub(1, (utf8.offset(str, n + 1) or (#str + 1)) - 1) .. "…"
    if f:getWidth(cut) <= w then return cut end
  end
  return "…"
end

function Theme.textWidth(str, font)
  return Theme.fonts[font or "body"]:getWidth(str)
end

function Theme.textHeight(str, font, width)
  local f = Theme.fonts[font or "body"]
  local _, lines = f:getWrap(str, width or 2000)
  return #lines * f:getHeight()
end

function Theme.centerText(str, cx, cy, opts)
  opts = opts or {}
  local f = Theme.fonts[opts.font or "body"]
  local w = opts.width or (f:getWidth(str) + 2)
  local h = Theme.textHeight(str, opts.font, w)
  opts.align = "center"
  opts.width = w
  Theme.text(str, cx - w / 2, cy - h / 2, opts)
end

-- ikony (pikselowe, rysowane prostokątami/kołami o małej liczbie segmentów)
function Theme.heart(x, y, r, color)
  lg.setColor(color or Theme.colors.heart)
  x, y = floor(x), floor(y)
  lg.circle("fill", x - r * 0.5, y - r * 0.3, r * 0.55, 8)
  lg.circle("fill", x + r * 0.5, y - r * 0.3, r * 0.55, 8)
  lg.polygon("fill", x - r, y - r * 0.15, x + r, y - r * 0.15, x, y + r)
end

function Theme.star(x, y, r, color)
  local pts = {}
  for i = 0, 9 do
    local a = -math.pi / 2 + i * math.pi / 5
    local rr = (i % 2 == 0) and r or r * 0.45
    pts[#pts + 1] = x + math.cos(a) * rr
    pts[#pts + 1] = y + math.sin(a) * rr
  end
  lg.setColor(color or Theme.colors.star)
  lg.polygon("fill", pts)
end

function Theme.coin(x, y, r)
  x, y = floor(x), floor(y)
  lg.setColor(Theme.colors.coinDark)
  lg.circle("fill", x, y + 1, r, 10)
  lg.setColor(Theme.colors.coin)
  lg.circle("fill", x, y, r, 10)
  lg.setColor(Theme.colors.coinDark)
  lg.circle("line", x, y, r * 0.6, 8)
end

function Theme.crown(x, y, r, color)
  lg.setColor(color or Theme.colors.gold)
  lg.polygon("fill", x - r, y + r * 0.6, x - r, y - r * 0.4, x - r * 0.5, y, x, y - r, x + r * 0.5, y, x + r, y - r * 0.4, x + r, y + r * 0.6)
end

function Theme.skull(x, y, r, color)
  lg.setColor(color or Theme.colors.cream)
  lg.circle("fill", x, y - r * 0.2, r, 10)
  lg.rectangle("fill", x - r * 0.6, y + r * 0.3, r * 1.2, r * 0.6)
  lg.setColor(Theme.colors.black)
  lg.circle("fill", x - r * 0.38, y - r * 0.25, r * 0.3, 6)
  lg.circle("fill", x + r * 0.38, y - r * 0.25, r * 0.3, 6)
  lg.rectangle("fill", x - r * 0.1, y + r * 0.05, r * 0.2, r * 0.25)
end

-- kostka: value 1..5 lub "destroy"; rot (radiany), sq (ściśnięcie 0..1)
function Theme.die(x, y, size, value, rot, sq)
  lg.push()
  lg.translate(floor(x), floor(y))
  lg.rotate(rot or 0)
  lg.scale(1 + (sq or 0) * 0.3, 1 - (sq or 0) * 0.3)
  local r = size * 0.18
  lg.setColor(Theme.colors.shadow)
  lg.rectangle("fill", -size / 2 + 1, -size / 2 + 3, size, size, r, r)
  lg.setColor(Theme.colors.cream)
  lg.rectangle("fill", -size / 2, -size / 2, size, size, r, r)
  lg.setColor(Theme.colors.ink)
  lg.rectangle("line", -size / 2 + 0.5, -size / 2 + 0.5, size - 1, size - 1, r, r)
  if value == "destroy" then
    Theme.skull(0, 0, size * 0.22, Theme.colors.ink)
    lg.setColor(Theme.colors.red)
    lg.setLineWidth(2)
    lg.line(-size * 0.3, -size * 0.3, size * 0.3, size * 0.3)
    lg.line(size * 0.3, -size * 0.3, -size * 0.3, size * 0.3)
    lg.setLineWidth(1)
  else
    local d = size * 0.26
    local pips = { [1] = { { 0, 0 } }, [2] = { { -1, -1 }, { 1, 1 } }, [3] = { { -1, -1 }, { 0, 0 }, { 1, 1 } },
      [4] = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }, [5] = { { -1, -1 }, { 1, -1 }, { 0, 0 }, { -1, 1 }, { 1, 1 } } }
    lg.setColor(Theme.colors.ink)
    for _, p in ipairs(pips[value] or {}) do lg.circle("fill", p[1] * d, p[2] * d, size * 0.09, 6) end
  end
  lg.pop()
end

-- ------------------------------------------------------------- pixel tiles
-- Kafelki wzorów (powtarzane): papier kart i rewersy talii.
local tiles, quads = {}, {}
local function makeTile(w, h, fn)
  local c = love.graphics.newCanvas(w, h)
  c:setFilter("nearest", "nearest")
  c:setWrap("repeat", "repeat")
  local prev = love.graphics.getCanvas()
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.setStencilTest()
  love.graphics.setCanvas(c)
  love.graphics.clear(0, 0, 0, 0)
  fn(w, h)
  love.graphics.pop()
  if prev then love.graphics.setCanvas({ prev, stencil = true }) else love.graphics.setCanvas() end
  return c
end

function Theme.tile(name)
  if tiles[name] then return tiles[name] end
  local c = Theme.colors
  local t
  if name == "paper" then
    t = makeTile(4, 4, function()
      love.graphics.setColor(c.cream); love.graphics.rectangle("fill", 0, 0, 4, 4)
      love.graphics.setColor(c.creamDark[1], c.creamDark[2], c.creamDark[3], 0.5)
      love.graphics.rectangle("fill", 1, 1, 1, 1); love.graphics.rectangle("fill", 3, 3, 1, 1)
    end)
  elseif name == "dark" then
    t = makeTile(4, 4, function()
      love.graphics.setColor(c.panel); love.graphics.rectangle("fill", 0, 0, 4, 4)
      love.graphics.setColor(c.panelLight); love.graphics.rectangle("fill", 0, 0, 1, 1); love.graphics.rectangle("fill", 2, 2, 1, 1)
    end)
  else -- rewersy: back_village / back_road / back_market
    local pal = { back_village = { rgb("#b8862b"), rgb("#f0c850") }, back_road = { rgb("#2b3a4a"), rgb("#5d8a9a") }, back_market = { rgb("#4f3a7a"), rgb("#9a7fd0") } }
    local p = pal[name] or pal.back_village
    t = makeTile(8, 8, function()
      love.graphics.setColor(p[1]); love.graphics.rectangle("fill", 0, 0, 8, 8)
      love.graphics.setColor(p[2])
      for y = 0, 7 do for x = 0, 7 do
        if (x + y) % 4 == 0 or (x - y) % 4 == 0 then love.graphics.rectangle("fill", x, y, 1, 1) end
      end end
      love.graphics.setColor(p[2][1], p[2][2], p[2][3], 0.5); love.graphics.rectangle("fill", 2, 2, 1, 1); love.graphics.rectangle("fill", 6, 6, 1, 1)
    end)
  end
  tiles[name] = t
  return t
end

-- rysuje kafelek wypełniający prostokąt (wymaga wrap=repeat)
function Theme.tiled(name, x, y, w, h)
  local t = Theme.tile(name)
  local key = w .. "x" .. h .. name
  local q = quads[key]
  if not q then
    q = love.graphics.newQuad(0, 0, w, h, t:getWidth(), t:getHeight())
    quads[key] = q
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(t, q, math.floor(x), math.floor(y))
end

function Theme.hit(mx, my, x, y, w, h)
  return mx >= x and mx < x + w and my >= y and my < y + h
end

-- tło stołu (sukno z pikselowym wzorem), rysowane raz do kanwy
function Theme.drawFelt()
  if not Theme.feltCanvas then
    local c = love.graphics.newCanvas(Theme.VW, Theme.VH)
    c:setFilter("nearest", "nearest")
    lg.push("all")
    lg.origin()
    lg.setStencilTest()
    lg.setCanvas(c)
    lg.clear(Theme.colors.felt)
    local dark, light = Theme.colors.feltDark, Theme.colors.feltLight
    -- deseń: ukośne „ściegi” i plamy
    for y = 0, Theme.VH, 4 do
      for x = 0, Theme.VW, 4 do
        local v = (x * 7 + y * 13) % 23
        if v == 0 then lg.setColor(light[1], light[2], light[3], 0.35); lg.rectangle("fill", x, y, 2, 1)
        elseif v == 11 then lg.setColor(dark[1], dark[2], dark[3], 0.45); lg.rectangle("fill", x + 2, y + 2, 1, 1) end
      end
    end
    -- winieta
    for i = 0, 40 do
      lg.setColor(0, 0, 0, 0.012)
      lg.rectangle("fill", i, i, Theme.VW - 2 * i, Theme.VH - 2 * i)
    end
    lg.pop()
    lg.setCanvas({ Theme.canvas, stencil = true })
    Theme.feltCanvas = c
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(Theme.feltCanvas, 0, 0)
end

return Theme
