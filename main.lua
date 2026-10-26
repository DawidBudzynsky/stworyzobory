-- Stwory z obory – punkt wejścia LÖVE 11.5. Zarządza ekranami i sesją sieciową.
-- Cała grafika trafia na kanwę 640x360 (pixel-art) skalowaną całkowitym mnożnikiem.
local Theme = require("src.ui.theme")
local Settings = require("src.settings")
local Audio = require("src.audio")
local Widgets = require("src.ui.widgets")
local Anim = require("src.ui.anim")

App = { screen = nil, session = nil, overlay = nil }

function App.setScreen(name, ...)
  local S = require("src.ui.screens." .. name)
  App.screen = S.new(...)
  if App.screen.load then App.screen:load() end
end

function App.closeSession()
  if App.session then
    pcall(App.session.close, App.session)
    App.session = nil
  end
  Anim.reset()
end

function App.openOverlay(name, ...)
  local S = require("src.ui.screens." .. name)
  App.overlay = S.new(...)
end

function App.applyFullscreen()
  love.window.setFullscreen(Settings.data.fullscreen and true or false, "desktop")
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setLineStyle("rough")
  love.keyboard.setKeyRepeat(true)
  Settings.load()
  Audio.load()
  Audio.setVolume(Settings.data.volume or 0.7)
  App.applyFullscreen()
  Theme.resize(love.graphics.getDimensions())
  App.setScreen("menu")
  if os.getenv("STWORY_AUTOTEST") then require("tests.autoplay").install() end
end

function love.resize(w, h)
  Theme.resize(w, h)
end

function love.update(dt)
  dt = math.min(dt, 0.05)
  if App.session then
    local ok, err = pcall(App.session.update, App.session)
    if not ok then
      print("Błąd sesji: " .. tostring(err))
      Widgets.toast("Błąd sieci: " .. tostring(err), "error")
    end
  end
  if App.overlay and App.overlay.update then App.overlay:update(dt) end
  if App.screen.update then App.screen:update(dt) end
  Widgets.updateToasts(dt)
  Anim.update(dt)
end

function love.draw()
  Theme.push()
  love.graphics.push()
  if Anim.shake > 0 then
    love.graphics.translate(math.floor((math.random() - 0.5) * Anim.shake), math.floor((math.random() - 0.5) * Anim.shake))
  end
  Theme.drawFelt()
  App.screen:draw()
  if App.overlay then App.overlay:draw() end
  Widgets.drawToasts()
  love.graphics.pop()
  Theme.pop()
end

local function target() return App.overlay or App.screen end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  local vx, vy = Theme.toVirtual(x, y)
  local t = target()
  if t.mousepressed then t:mousepressed(vx, vy) end
end

function love.mousereleased(x, y, button)
  if button ~= 1 then return end
  local vx, vy = Theme.toVirtual(x, y)
  local t = target()
  if t.mousereleased then t:mousereleased(vx, vy) end
end

function love.mousemoved(x, y)
  local vx, vy = Theme.toVirtual(x, y)
  local t = target()
  if t.mousemoved then t:mousemoved(vx, vy) end
end

function love.wheelmoved(dx, dy)
  local t = target()
  if t.wheelmoved then t:wheelmoved(dx, dy) end
end

function love.textinput(txt)
  local t = target()
  if t.textinput then t:textinput(txt) end
end

function love.keypressed(key)
  if key == "f11" then
    Settings.data.fullscreen = not Settings.data.fullscreen
    Settings.save()
    App.applyFullscreen()
    return
  end
  local t = target()
  if t.keypressed and t:keypressed(key) then return end
  if key == "escape" then
    if App.overlay then App.overlay = nil
    elseif App.screen.name == "game" or App.screen.name == "lobby" then App.openOverlay("settings") end
  end
end

function love.quit()
  App.closeSession()
end
