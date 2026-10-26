local Theme = require("src.ui.theme")
local W = require("src.ui.widgets")
local T = require("src.net.transport")
local Settings = require("src.settings")

local S = {}
S.__index = S

function S.new()
  local s = setmetatable({ name = "lobby", buttons = {}, t = 0 }, S)
  local sess = App.session
  s.isHost = sess and sess:isHost()
  if s.isHost then
    s.lanIp = T.localIp("8.8.8.8") or "?"
    s.tsIp = T.localIp("100.100.100.100")
    if s.tsIp and not s.tsIp:match("^100%.") then s.tsIp = nil end
    s.buttons[#s.buttons + 1] = W.button({ x = 356, y = 268, w = 180, h = 22, label = "Rozpocznij grę", style = "ok", onClick = function()
      if sess:canStart() then sess:startGame() end
    end })
    s.buttons[#s.buttons + 1] = W.button({ x = 356, y = 298, w = 180, h = 18, label = "Kopiuj adres", style = "secondary", onClick = function()
      love.system.setClipboardText((s.tsIp or s.lanIp) .. ":" .. sess.port)
      W.toast("Skopiowano adres do schowka", "ok")
    end })
  else
    s.buttons[#s.buttons + 1] = W.button({ x = 356, y = 268, w = 180, h = 22, label = "Połącz ponownie", style = "secondary", onClick = function()
      if sess.reconnect then sess:reconnect() end
    end })
  end
  s.buttons[#s.buttons + 1] = W.button({ x = 104, y = 298, w = 120, h = 18, label = "Opuść pokój", style = "danger", onClick = function()
    App.closeSession(); App.setScreen("menu")
  end })
  return s
end

function S:update(dt)
  self.t = self.t + dt
  local sess = App.session
  if not sess then App.setScreen("menu"); return end
  if sess:isHost() then
    self.buttons[1].enabled = sess:canStart()
    if sess.state then App.setScreen("game") end
  else
    if sess.status == "game" and sess.view then
      Settings.data.session = { host = sess.host, port = sess.port, token = sess.token }
      Settings.save()
      App.setScreen("game")
    end
    self.buttons[1].visible = sess.status == "error" and not sess.hostQuit
  end
end

function S:draw()
  local c = Theme.colors
  local sess = App.session
  if not sess then return end
  Theme.centerText("Pokój gry", Theme.VW / 2, 30, { font = "titleB", color = c.gold })
  Theme.panel(104, 56, 220, 232, { fill = c.panel })
  Theme.text("Gracze (2–5):", 112, 62, { font = "smallB", color = c.creamDark })
  local players = {}
  if sess:isHost() then
    for _, p in ipairs(sess.players) do players[#players + 1] = { name = p.name, connected = p.connected } end
  elseif sess.lobby then
    for _, p in ipairs(sess.lobby.players) do players[#players + 1] = p end
  end
  for i = 1, 5 do
    local y = 80 + (i - 1) * 28
    local p = players[i]
    if p then
      Theme.panel(112, y, 204, 22, { fill = c.panelLight, radius = 3, shadow = 1 })
      Theme.text(i .. ". " .. p.name .. (i == 1 and "  (host)" or ""), 118, y + 4, { font = "body", color = c.cream })
      love.graphics.setColor(p.connected and c.btnOk or c.btnDanger); love.graphics.circle("fill", 306, y + 11, 3, 6)
      if not p.connected then Theme.text("rozłączony", 236, y + 5, { font = "small", color = c.btnDanger }) end
    else
      Theme.text(i .. ". —", 118, y + 4, { font = "body", color = c.inkSoft })
    end
  end
  Theme.panel(356, 56, 220, 200, { fill = c.panel })
  if sess:isHost() then
    Theme.text("Jak dołączyć:", 364, 62, { font = "smallB", color = c.creamDark })
    Theme.text("Port: " .. sess.port, 364, 78, { font = "large", color = c.gold })
    Theme.text("Adres LAN:", 364, 102, { font = "small", color = c.creamDark })
    Theme.text(self.lanIp, 364, 112, { font = "large", color = c.cream })
    Theme.text("Adres Tailscale:", 364, 136, { font = "small", color = c.creamDark })
    Theme.text(self.tsIp or "nie wykryto (sprawdź: tailscale ip -4)", 364, 146, { font = self.tsIp and "large" or "small", color = self.tsIp and c.cream or c.creamDark })
    Theme.text("Gracze wybierają „Dołącz do gry” i wpisują adres oraz port. Gdy wszyscy są, kliknij „Rozpocznij grę”.", 364, 172, { font = "small", color = c.cream, width = 204 })
    if #sess.log > 0 then Theme.text(sess.log[#sess.log], 364, 230, { font = "small", color = c.creamDark, width = 204 }) end
  else
    local status = ({ connecting = "Łączenie z " .. sess.host .. ":" .. sess.port .. "…", lobby = "Połączono. Czekamy, aż host rozpocznie grę.", game = "Gra się rozpoczyna…", error = "Błąd: " .. tostring(sess.error), closed = "Rozłączono." })[sess.status] or sess.status
    Theme.text(status, 364, 62, { font = "body", color = sess.status == "error" and c.btnDanger or c.cream, width = 204 })
    if sess.status == "connecting" then Theme.text("Proszę czekać" .. string.rep(".", math.floor(self.t * 2) % 4), 364, 100, { font = "body", color = c.creamDark }) end
    Theme.text("Jeśli połączenie nie działa:\n• sprawdź adres i port u hosta,\n• host musi odblokować port w zaporze (LAN),\n• przez Tailscale oba komputery muszą być w tej samej sieci.", 364, 140, { font = "small", color = c.creamDark, width = 204 })
  end
  for _, b in ipairs(self.buttons) do b:draw() end
end

function S:mousemoved(x, y) for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end end
function S:mousepressed(x, y) for _, b in ipairs(self.buttons) do if b:mousepressed(x, y) then return end end end

return S
