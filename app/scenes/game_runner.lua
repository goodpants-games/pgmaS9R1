local GameRunner = require("microgame.runner")

local scene = Sceneman.scene()
local self

function scene.load(data)
    data = data or {}
    self = {}
    
    Lg.setBackgroundColor(0.5, 0.5, 0.5)
    self.runner = GameRunner(data)
end

function scene.unload()
    self.runner:release()
    self = nil
end

---@diagnostic disable-next-line
function scene.rawUpdate(dt)
    self.runner:update(dt)
end

function scene.update()
    self.runner:tick()
end

function scene.draw()
    self.runner:draw()
end

return scene