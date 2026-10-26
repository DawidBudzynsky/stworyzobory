-- Dźwięki generowane proceduralnie (bez plików): klik, karta, kostka, wygrana, przegrana.
local Audio = { volume = 0.7, sources = {} }

local RATE = 22050

local function gen(seconds, fn)
  local n = math.floor(seconds * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  for i = 0, n - 1 do
    local t = i / RATE
    local v = fn(t, i / n)
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    sd:setSample(i, v)
  end
  return love.audio.newSource(sd, "static")
end

local function env(p, a, r) -- obwiednia: szybki atak, wybrzmienie
  if p < a then return p / a end
  return math.max(0, 1 - (p - a) / r)
end

function Audio.load()
  local ok = pcall(function()
    Audio.sources.click = gen(0.06, function(t, p) return math.sin(t * 2 * math.pi * 900) * env(p, 0.05, 0.9) * 0.4 end)
    Audio.sources.card = gen(0.12, function(t, p) return (math.random() * 2 - 1) * env(p, 0.1, 0.7) * 0.25 * (1 - p) end)
    Audio.sources.flip = gen(0.15, function(t, p) return (math.random() * 2 - 1) * env(p, 0.02, 0.5) * 0.2 + math.sin(t * 2 * math.pi * (300 + 600 * p)) * 0.15 * (1 - p) end)
    Audio.sources.dice = gen(0.5, function(t, p)
      local k = math.floor(p * 7)
      local ph = (p * 7) % 1
      return (math.random() * 2 - 1) * env(ph, 0.05, 0.4) * 0.35 * (1 - p * 0.5) + math.sin(t * 2 * math.pi * (1200 + k * 150)) * env(ph, 0.02, 0.3) * 0.2
    end)
    Audio.sources.coin = gen(0.25, function(t, p) return (math.sin(t * 2 * math.pi * 1760) + math.sin(t * 2 * math.pi * 2640) * 0.5) * env(p, 0.02, 0.9) * 0.25 end)
    Audio.sources.hurt = gen(0.3, function(t, p) return math.sin(t * 2 * math.pi * (220 - 120 * p)) * env(p, 0.02, 0.9) * 0.4 end)
    Audio.sources.win = gen(1.2, function(t, p)
      local notes = { 523, 659, 784, 1047 }
      local k = math.min(4, math.floor(p * 4) + 1)
      local ph = (p * 4) % 1
      return (math.sin(t * 2 * math.pi * notes[k]) + math.sin(t * 2 * math.pi * notes[k] * 2) * 0.3) * env(ph, 0.05, 0.9) * 0.3
    end)
    Audio.sources.lose = gen(0.8, function(t, p) return math.sin(t * 2 * math.pi * (200 - 80 * p)) * env(p, 0.05, 0.9) * 0.35 end)
    Audio.sources.fame = gen(0.5, function(t, p) return (math.sin(t * 2 * math.pi * 880) + math.sin(t * 2 * math.pi * 1320) * 0.6) * env(p, 0.02, 0.95) * 0.3 end)
  end)
  Audio.ok = ok
end

function Audio.play(name)
  local s = Audio.sources[name]
  if not s or Audio.volume <= 0 then return end
  s:stop()
  s:setVolume(Audio.volume)
  s:play()
end

function Audio.setVolume(v) Audio.volume = math.max(0, math.min(1, v)) end

return Audio
