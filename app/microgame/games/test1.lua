local Sprite = require("sprite")
local GameBase = require("microgame.base")

---@class _test1: microgame.Game
local Game = batteries.class {
    name = "Microgame.Test",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)

    self.verb = "Test 1!"
    self.backgroundColor = { 0.0, 0.5, 0.0 }
    self.win = true

    self.spr = Sprite.new("res/sprites/placeholder.json")
    self:releaseOnUnload(self.spr)
    self.spr:play("wave")

    self.sprX = 0
    self.sprY = 0

    self.music = self.manager:newAudioSource("/res/music/CLASS11.MOD", "stream")
    self:releaseOnUnload(self.music)
    self.music:play()
end

function Game:tick()
    self.spr:update(App.tickLength)
    self.sprX = self.sprX + 1
    self.sprY = self.sprY + 1

    if self.manager:isButtonPressed() then
        self.sprX = 0
        self.sprY = 0
    end
end

function Game:draw()
    self.spr:draw(self.sprX, self.sprY)
end

return Game