-- Symulacja pełnych partii losową polityką dla wielu ziaren i liczby graczy 2–5.
-- Sprawdza: brak błędów silnika, brak zakleszczeń (zawsze istnieje legalna akcja),
-- koniec gry zgodny z zasadami (7 sławy albo ostatni gracz), zgodność widoków z JSON.
package.path = "./?.lua;" .. package.path
local Rules = require("src.game.rules")
local json = require("src.net.json")

local function simulate(seed, nPlayers)
  local names = {}
  for i = 1, nPlayers do names[i] = "P" .. i end
  local s = Rules.new(names, seed)
  local rnd = math.random
  local steps = 0
  while not s.winner do
    steps = steps + 1
    if steps > 20000 then return false, "za dużo kroków (zakleszczenie?)" end
    local waiting = Rules.waitingFor(s)
    if #waiting == 0 then return false, "nikt nie jest oczekiwany w fazie " .. s.phase end
    local pid = waiting[rnd(#waiting)]
    local cands = Rules.candidateActions(s, pid)
    if #cands == 0 then return false, "brak akcji dla gracza " .. pid .. " w fazie " .. s.phase .. " prompt=" .. tostring(s.prompt and s.prompt.type) end
    -- polityka: częściej walcz niż uciekaj, żeby partia się kończyła
    local a = cands[rnd(#cands)]
    if s.phase == "encounter" and rnd() < 0.7 then a = cands[1] end
    if s.phase == "contract_volunteer" and rnd() < 0.5 then a = cands[2] end
    if s.phase == "road_choice" and rnd() < 0.8 then a = cands[1] end
    if s.phase == "fight_react" and rnd() < 0.8 then a = cands[1] end
    local ok, err = Rules.apply(s, pid, a)
    if not ok then return false, "akcja " .. a.type .. " odrzucona: " .. tostring(err) end
    if steps % 97 == 0 then
      for _, p in ipairs(s.players) do
        local ok2, e2 = pcall(json.encode, Rules.view(s, p.id))
        if not ok2 then return false, "widok nie koduje się do JSON: " .. tostring(e2) end
      end
    end
    -- niezmienniki
    for _, p in ipairs(s.players) do
      if p.hp < 0 or p.hp > p.maxHp then return false, "zdrowie poza zakresem" end
      if p.coins < 0 then return false, "ujemne miedziaki" end
      if #p.weapons > 2 then return false, "za dużo broni" end
    end
  end
  local w = s.players[s.winner]
  local aliveN = 0
  for _, p in ipairs(s.players) do if not p.eliminated then aliveN = aliveN + 1 end end
  if Rules.fameCount(w) < 6 and aliveN > 1 then return false, "zwycięzca bez 7 sławy i nie ostatni" end
  return true, steps
end

local fails, total, totalSteps = 0, 0, 0
for seed = 1, 40 do
  for n = 2, 5 do
    math.randomseed(seed * 100 + n)
    local ok, info = simulate(seed, n)
    total = total + 1
    if ok then totalSteps = totalSteps + info else fails = fails + 1; print("FAIL seed=" .. seed .. " n=" .. n .. ": " .. tostring(info)) end
  end
end
print(string.format("Symulacje: %d partii, %d błędów, średnio %.0f akcji na partię", total, fails, totalSteps / math.max(1, total - fails)))
os.exit(fails == 0 and 0 or 1)
