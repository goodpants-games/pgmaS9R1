local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local GameBase = require("microgame.base")

---@class _test2: microgame.Game
local Game = batteries.class {
    name = "microgame.test",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    
    self.verb = "Test 2!"
    self.backgroundColor = { 0.0, 0.0, 0.5 }

    self.spr = Sprite.new("res/sprites/placeholder.json")
    self:releaseOnUnload(self.spr)
    self.spr:play("wave")

    self.sprX = math.floor(GameConf.scrW / 2)
    self.sprY = 0

    self.music = self.manager:newAudioSource("/res/music/CLASS11.MOD", "stream")
    self:releaseOnUnload(self.music)
    self.music:seek(19.0)
    self.music:play()
end

function Game:tick()
    self.spr:update(App.tickLength)
    self.sprY = self.sprY + 1

    if self.manager:isButtonPressed() then
        self.sprX = love.math.random(0, GameConf.scrW)
    end
end

function Game:draw()
    Lg.setColor(0.0, 1.0, 0.0)
    self.spr:draw(self.sprX, self.sprY)
end

return Game