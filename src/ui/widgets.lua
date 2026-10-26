-- Kontrolki pixel-art: przycisk (z dolną krawędzią jak w Balatro), pole tekstowe, komunikaty.
local Theme = require("src.ui.theme")
local Audio = require("src.audio")
local lg = love.graphics
local floor = math.floor

local W = {}

-- ----------------------------------------------------------------- Button
local Button = {}
Button.__index = Button

function W.button(opts)
  return setmetatable({
    x = opts.x or 0, y = opts.y or 0, w = opts.w or 90, h = opts.h or 18,
    label = opts.label or "", onClick = opts.onClick, enabled = opts.enabled ~= false,
    style = opts.style or "primary", font = opts.font or "smallB", hover = false, visible = true,
  }, Button)
end

local styles = {
  primary = { "btn", "btnDark" }, secondary = { "btn2", "btn2Dark" }, danger = { "btnDanger", "btnDangerDark" }, ok = { "btnOk", "btnOkDark" },
}

function Button:draw()
  if not self.visible then return end
  local c = Theme.colors
  local st = styles[self.style] or styles.primary
  local top, bottom = c[st[1]], c[st[2]]
  if not self.enabled then top, bottom = c.disabled, c.disabledDark end
  local x, y, w, h = floor(self.x), floor(self.y), floor(self.w), floor(self.h)
  local lift = (self.hover and self.enabled) and 1 or 0
  lg.setColor(c.shadow)
  lg.rectangle("fill", x, y + 3, w, h, 3, 3)
  lg.setColor(bottom)
  lg.rectangle("fill", x, y - lift + 2, w, h, 3, 3)
  lg.setColor(top)
  lg.rectangle("fill", x, y - lift, w, h - 2, 3, 3)
  if self.hover and self.enabled then
    lg.setColor(1, 1, 1, 0.18)
    lg.rectangle("fill", x, y - lift, w, floor(h / 2), 3, 3)
  end
  lg.setColor(c.ink)
  lg.rectangle("line", x + 0.5, y - lift + 0.5, w - 1, h + 1, 3, 3)
  local font = self.font
  if Theme.textWidth(self.label, font) > w - 6 then font = "tinyB" end
  Theme.centerText(Theme.fit(self.label, font, w - 6), x + w / 2, y - lift + (h - 2) / 2, { font = font, color = self.enabled and c.btnText or c.creamDark, shadow = self.enabled })
end

function Button:mousemoved(mx, my)
  self.hover = self.visible and Theme.hit(mx, my, self.x, self.y, self.w, self.h)
end

function Button:mousepressed(mx, my)
  if self.visible and self.enabled and Theme.hit(mx, my, self.x, self.y, self.w, self.h) then
    Audio.play("click")
    if self.onClick then self.onClick(self) end
    return true
  end
end

-- -------------------------------------------------------------- TextInput
local TextInput = {}
TextInput.__index = TextInput

function W.textInput(opts)
  return setmetatable({
    x = opts.x, y = opts.y, w = opts.w or 160, h = opts.h or 20, text = opts.text or "", placeholder = opts.placeholder or "",
    focused = false, maxLen = opts.maxLen or 40, numeric = opts.numeric, onEnter = opts.onEnter,
  }, TextInput)
end

function TextInput:draw()
  local c = Theme.colors
  Theme.panel(self.x, self.y, self.w, self.h, { fill = c.cream, border = self.focused and c.highlight or c.ink, radius = 3, shadow = 2 })
  local shown = self.text
  if shown == "" and not self.focused then
    Theme.text(self.placeholder, self.x + 5, self.y + 3, { font = "body", color = c.inkSoft })
  else
    if self.focused and math.floor(love.timer.getTime() * 2) % 2 == 0 then shown = shown .. "_" end
    Theme.text(shown, self.x + 5, self.y + 3, { font = "body", color = c.ink })
  end
end

function TextInput:mousepressed(mx, my)
  self.focused = Theme.hit(mx, my, self.x, self.y, self.w, self.h)
  return self.focused
end

function TextInput:textinput(t)
  if not self.focused then return end
  if self.numeric and not t:match("^%d+$") then return end
  if #self.text < self.maxLen then self.text = self.text .. t end
end

function TextInput:keypressed(key)
  if not self.focused then return end
  if key == "backspace" then
    local byteoffset = require("utf8").offset(self.text, -1)
    if byteoffset then self.text = self.text:sub(1, byteoffset - 1) end
  elseif key == "return" or key == "kpenter" then
    if self.onEnter then self.onEnter(self.text) end
  elseif key == "v" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
    local clip = (love.system.getClipboardText() or ""):gsub("[\r\n]", "")
    if self.numeric then clip = clip:gsub("%D", "") end
    self.text = (self.text .. clip):sub(1, self.maxLen)
  end
end

-- ------------------------------------------------------------------ Toasts
local toasts = {}
function W.toast(text, kind)
  toasts[#toasts + 1] = { text = text, kind = kind or "info", t = 0, life = 3.5 }
  if #toasts > 3 then table.remove(toasts, 1) end
end

function W.updateToasts(dt)
  for i = #toasts, 1, -1 do
    toasts[i].t = toasts[i].t + dt
    if toasts[i].t > toasts[i].life then table.remove(toasts, i) end
  end
end

function W.drawToasts()
  local c = Theme.colors
  local y = 24
  for _, t in ipairs(toasts) do
    local alpha = math.min(1, (t.life - t.t) / 0.4, t.t / 0.15)
    local w = math.min(360, Theme.textWidth(t.text, "body") + 16)
    local x = floor((Theme.VW - w) / 2)
    local fill = t.kind == "error" and c.btnDanger or (t.kind == "ok" and c.btnOk or c.panelLight)
    lg.setColor(fill[1], fill[2], fill[3], alpha)
    lg.rectangle("fill", x, y, w, 18, 3, 3)
    lg.setColor(c.ink[1], c.ink[2], c.ink[3], alpha)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, 17, 3, 3)
    Theme.centerText(t.text, Theme.VW / 2, y + 9, { font = "body", color = { 1, 1, 1, alpha }, width = w - 8 })
    y = y + 22
  end
end

return W
