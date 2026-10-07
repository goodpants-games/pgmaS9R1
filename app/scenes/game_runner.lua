local GameRunner = require("microgame.runner")

local scene = Sceneman.scene()
local self

function scene.load(data)
    self = {}
    
    Lg.setBackgroundColor(0.5, 0.5, 0.5)
    self.runner = GameRunner(data)
end

function scene.unload()
    self.runner:release()
    self = nil
end

function scene.update(dt)
    self.runner:update(dt)
end

---@diagnostic disable-next-line
function scene.tick()
    self.runner:tick()
end

function scene.draw()
    self.runner:draw()
end

return scene