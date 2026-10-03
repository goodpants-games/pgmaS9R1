local Game = batteries.class { name = "Microgame.Test" }
local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local Input = require("input")

---@param speed number Number of seconds removed from the timer.
---@param level number Difficulty level starting from 0. Increases after each boss round.
function Game:new(speed, level)
    self.verb = "Test 1!"
    self.backgroundColor = { 0.0, 0.5, 0.0 }

    self.spr = Sprite.new("res/sprites/placeholder.json")
    self.spr:play("wave")

    self.sprX = 0
    self.sprY = 0
end

function Game:release()
    self.spr:release()
end

function Game:tick()
    self.spr:update(App.tickLength)
    self.sprX = self.sprX + 1
    self.sprY = self.sprY + 1

    if Input.players[1]:pressed("gameButton") then
        self.sprX = 0
        self.sprY = 0
    end
end

function Game:draw()
    self.spr:draw(self.sprX, self.sprY)
end

return Game --[[@as Microgame]]