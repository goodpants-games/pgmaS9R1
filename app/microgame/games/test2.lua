local Game = batteries.class { name = "microgame.test" }
local GameConf = require("microgame.conf")
local Sprite = require("sprite")

function Game:new()
    self.verb = "Test 2!"
    self.backgroundColor = { 0.0, 0.0, 0.5 }

    self.spr = Sprite.new("res/sprites/placeholder.json")
    self.spr:play("wave")

    self.sprX = math.floor(GameConf.scrW / 2)
    self.sprY = 0
end

function Game:release()
    self.spr:release()
end

function Game:tick()
    self.spr:update(App.tickLength)
    self.sprY = self.sprY + 1
end

function Game:draw()
    Lg.setColor(0.0, 1.0, 0.0)
    self.spr:draw(self.sprX, self.sprY)
end

return Game