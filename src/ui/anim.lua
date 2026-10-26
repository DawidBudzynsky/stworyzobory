-- Animacje: pozycje kart (płynne dążenie do celu), unoszące się napisy, kostka (tweeny flux),
-- wstrząs ekranu i „pop” liczb.
local flux = require("src.lib.flux")

local Anim = { floats = {}, dice = nil, shake = 0, pops = {} }

local visuals = {}
-- Rejestruje cel karty; zwraca jej bieżącą (animowaną) pozycję.
function Anim.cardVisual(id, tx, ty, ts, tr)
  local v = visuals[id]
  if not v then
    v = { x = tx, y = ty, s = ts or 1, r = tr or 0 }
    visuals[id] = v
  end
  v.tx, v.ty, v.ts, v.tr = tx, ty, ts or 1, tr or 0
  v.alive = true
  return v
end

function Anim.spawnAt(id, x, y, s)
  if not visuals[id] then visuals[id] = { x = x, y = y, s = s or 1, r = 0, tx = x, ty = y, ts = s or 1, tr = 0, alive = true } end
end

function Anim.forget(id) visuals[id] = nil end
function Anim.reset() visuals = {}; Anim.floats = {}; Anim.dice = nil; Anim.pops = {}; Anim.shake = 0 end

function Anim.float(text, x, y, color, font)
  Anim.floats[#Anim.floats + 1] = { text = text, x = x, y = y, t = 0, color = color, font = font or "largeB" }
end

-- Kostka: wpada z góry, koziołkuje, odbija się i zatrzymuje na wartości.
function Anim.rollDice(x, y, value, pid)
  local d = { x = x, y = y - 90, rot = -1.2, sq = 0, value = value, pid = pid, t = 0, done = false, landed = false, show = 1 }
  Anim.dice = d
  flux.to(d, 0.45, { y = y, rot = 0 }):ease("quadin"):oncomplete(function()
    d.landed = true
    d.sq = 0.5
    Anim.shake = 3
    flux.to(d, 0.12, { sq = -0.15 }):ease("quadout"):after(d, 0.15, { sq = 0 }):ease("quadout"):oncomplete(function() d.done = true end)
  end)
end

-- „pop” skali dla liczb (np. siła), key = identyfikator
function Anim.pop(key, amount)
  local p = Anim.pops[key] or { s = 1 }
  Anim.pops[key] = p
  p.s = amount or 1.5
  flux.to(p, 0.35, { s = 1 }):ease("backout")
end
function Anim.popScale(key) return (Anim.pops[key] and Anim.pops[key].s) or 1 end

function Anim.update(dt)
  flux.update(dt)
  local k = 1 - math.exp(-dt * 14)
  for id, v in pairs(visuals) do
    if v.alive then
      v.x = v.x + (v.tx - v.x) * k
      v.y = v.y + (v.ty - v.y) * k
      v.s = v.s + (v.ts - v.s) * k
      v.r = v.r + (v.tr - v.r) * k
      v.alive = false
    else
      visuals[id] = nil
    end
  end
  for i = #Anim.floats, 1, -1 do
    local f = Anim.floats[i]
    f.t = f.t + dt
    if f.t > 1.4 then table.remove(Anim.floats, i) end
  end
  if Anim.dice then
    local d = Anim.dice
    d.t = d.t + dt
    if not d.landed then d.show = ({ 1, 2, 3, 4, 5, "destroy" })[math.floor(d.t * 18) % 6 + 1] else d.show = d.value end
    if d.done and d.t > 3.5 then Anim.dice = nil end
  end
  Anim.shake = math.max(0, Anim.shake - dt * 12)
end

return Anim
