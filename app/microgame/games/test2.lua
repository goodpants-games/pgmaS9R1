---@class _: Microgame
local Game = batteries.class { name = "microgame.test" }
local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local Input = require("input")

---@param speed number Number of seconds removed from the timer.
---@param level number Difficulty level starting from 0. Increases after each boss round.
function Game:new(speed, level)
    self.verb = "Test 2!"
    self.backgroundColor = { 0.0, 0.0, 0.5 }

    self.spr = Sprite.new("res/sprites/placeholder.json")
    self.spr:play("wave")

    self.sprX = math.floor(GameConf.scrW / 2)
    self.sprY = 0

    self.music = love.audio.newSource("/res/music/CLASS11.MOD", "stream")
    self.music:seek(19.0)
    self.music:play()
end

function Game:release()
    self.music:stop()
    self.music:release()

    self.spr:release()
end

function Game:tick()
    self.spr:update(App.tickLength)
    self.sprY = self.sprY + 1

    if Input.players[1]:pressed("gameButton") then
        self.sprX = love.math.random(0, GameConf.scrW)
    end
end

function Game:draw()
    Lg.setColor(0.0, 1.0, 0.0)
    self.spr:draw(self.sprX, self.sprY)
end

return Game --[[@as Microgame]]