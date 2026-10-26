-- Deterministyczny generator liczb losowych (LCG), niezależny od math.random,
-- aby host i testy miały powtarzalne rozdania.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed)
  return setmetatable({ s = (seed or os.time()) % 2147483647 }, Rng)
end

function Rng:next()
  self.s = (self.s * 48271) % 2147483647
  return self.s
end

-- liczba całkowita z [1, n]
function Rng:int(n)
  return (self:next() % n) + 1
end

function Rng:shuffle(t)
  for i = #t, 2, -1 do
    local j = self:int(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

return Rng
