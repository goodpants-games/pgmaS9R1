local Sprite = require("sprite")

local scene = Sceneman.scene()

local self

function scene.load()
    self = {}
    self.spr = Sprite.new("res/sprites/placeholder.json")
    self.spr:play("wave")

    Lg.setBackgroundColor(0.5, 0.5, 0.5)
end

function scene.unload()
    self.spr:release()
    self = nil
end

function scene.update(dt)
    self.spr:update(dt)
end

function scene.draw()
    Lg.setColor(0, 0, 0)
    self.spr:draw(App.mousex + 2, App.mousey + 2)

    Lg.setColor(1, 1, 1)
    self.spr:draw(App.mousex, App.mousey)
end

return scene