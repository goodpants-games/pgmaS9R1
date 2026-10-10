local Sprite = require("sprite")
local GameBase = require("microgame.base")

local GRAVITY = 0.45

---@class _test1: microgame.Game
local Game = batteries.class {
    name = "Microgame.Bow",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Shoot!"
    self.backgroundColor = {0.3, 0.6, 1.0}

    self.shot = false
    self.drawn = false

    self.throwAng = math.rad(320)
    self.shotPower = 0

    local resRoot = "/res/microgames/bow/"

    self.bowmanSpr = Sprite.new(resRoot.."bowman.json")
    self:releaseOnUnload(self.bowmanSpr)
    self.bowmanSpr.alignment = "center"
    self.bowmanSpr:play("Standing")

    self.targetSpr = Sprite.new(resRoot.."target.json")
    self:releaseOnUnload(self.targetSpr)
    self.bowmanSpr.alignment = "center"

    self.music = self.manager:newAudioSource("/res/music/CLASS11.MOD", "stream")
    self:releaseOnUnload(self.music)
    self.music:seek(5.6)
    self.music:play()

    self.bowmanX = 16
    self.bowmanY = 140

    self.targetX = 170
    self.targetY = love.math.random(40, 120)

    self.groundY = 172
end

function Game:tick()
    self.bowmanSpr:update(App.tickLength)
    
    if self.manager:isButtonDown() then
        if self.shot == false then
            self.drawn = true
            self.bowmanSpr:play("BowDrawn")

            self.shotPower = self.shotPower + (0.003 / App.tickLength)
        end
    else
        if self.drawn == true then
            self.shot = true
            self.bowmanSpr:play("BowRelease")
        end
    end
end

function Game:draw()
    self.bowmanSpr:draw(self.bowmanX, self.bowmanY, 0, 1, 1)
    self.targetSpr:draw(self.targetX, self.targetY, 0, 1, 0.8)

    if self.drawn and not self.shot then
        local predictX = self.bowmanX + 28
        local predictY = self.bowmanY - 13
        local predictVx = math.cos(self.throwAng) * self.shotPower
        local predictVy = math.sin(self.throwAng) * self.shotPower
        for i=0, 59 do
            if i % 2 == 0 then
                Lg.setColor(1, 1, 1)
                Lg.rectangle("fill", predictX - 2, predictY - 2, 4, 4)
            end

            predictX = predictX + predictVx
            predictY = predictY + predictVy
            predictVy = predictVy + GRAVITY
        end
    end

    Lg.setColor(0.2, 0.8, 0.4)
    Lg.rectangle("fill", 0, self.groundY, 180, 180 - self.groundY)
end

return Game