local scene = Sceneman.scene()

local self

function scene.load()
    self = {}
end

function scene.unload()
    self = nil
end

return scene