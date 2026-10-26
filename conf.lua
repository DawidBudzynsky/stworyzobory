function love.conf(t)
  t.identity = "stwory-z-obory"
  t.version = "11.5"
  t.window.title = "Stwory z obory"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 960
  t.window.minheight = 540
  t.window.resizable = true
  t.window.vsync = 1
  t.window.msaa = 0
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
end
