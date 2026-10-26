-- Ustawienia zapisywane w katalogu zapisu LÖVE (JSON).
local json = require("src.net.json")

local Settings = {
  data = { name = "", volume = 0.7, fullscreen = false, lastHost = "", lastPort = "29999", session = nil },
}

function Settings.load()
  local ok, txt = pcall(love.filesystem.read, "settings.json")
  if ok and txt then
    local ok2, t = pcall(json.decode, txt)
    if ok2 and type(t) == "table" then
      for k, v in pairs(t) do Settings.data[k] = v end
    end
  end
end

function Settings.save()
  pcall(love.filesystem.write, "settings.json", json.encode(Settings.data))
end

return Settings
