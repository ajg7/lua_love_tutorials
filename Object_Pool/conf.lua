function love.conf(t)
    t.title = "Object Pool Tutorial"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = true
    t.window.minwidth = 400
    t.window.minheight = 300
    
    -- Enable modules we need
    t.modules.audio = false     -- We don't need audio for this tutorial
    t.modules.physics = false   -- No physics simulation needed
    t.modules.touch = false     -- Desktop only
    t.modules.video = false     -- No video playback
    
    -- Keep these enabled
    t.modules.graphics = true
    t.modules.keyboard = true
    t.modules.event = true
    t.modules.timer = true
    t.modules.window = true
end