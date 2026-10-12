local Sprite = require("sprite")
local GameBase = require("microgame.base")

local GRAVITY = 0.45

---@class microgame._bow: microgame.Game
local Game = batteries.class {
    name = "microgame.bow",
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

    self.arrowSpr = Sprite.new(resRoot.."arrow.json")
    self:releaseOnUnload(self.arrowSpr)
    self.arrowSpr.alignment = "center"

    self.music = self.manager:newAudioSource("/res/music/CLASS11.MOD", "stream")
    self:releaseOnUnload(self.music)
    self.music:seek(5.6)
    self.music:play()

    self.bowmanX = 16
    self.bowmanY = 140

    self.targetX = 170
    self.targetY = love.math.random(50, 120)
    self.targetSizeY = 64 * 0.5 --if your updating the target sprite make sure you update this to reflect the new height in pixels
    self.hitTarget = false

    self.arrowX = 35
    self.arrowY = 128
    self.arrowVx = 0
    self.arrowVy = 0
    self.arrowTilt = 0
    self.arrowWidth = 12 --same thing here but for the arrow. update it to reflect the new width in pixels
    self.arrowVisible = false
    
    self.groundY = 172
end

function Game:tick()
    self.bowmanSpr:update(App.tickLength)
    
    if self.manager:isButtonDown() then
        if self.shot == false then
            self.drawn = true
            self.arrowVisible = true
            self.bowmanSpr:play("BowDrawn")

            self.shotPower = self.shotPower + (0.003 / App.tickLength)
        end
    else
        if self.drawn == true and self.shot == false then
            self.shot = true
            self.bowmanSpr:play("BowRelease")
        end
    end

    if self.shot == true and self.hitTarget == false then
        self.arrowX = self.arrowX + self.arrowVx
        self.arrowY = self.arrowY + self.arrowVy
        self.arrowVy = self.arrowVy + GRAVITY
        self.arrowTilt = math.rad(math.clamp(self.arrowVy * 5, -90, 90))

        if self.arrowX + self.arrowWidth/2 >= self.targetX and self.arrowY > self.targetY - self.targetSizeY/2 and self.arrowY < self.targetY + self.targetSizeY/2 and
        self.arrowX < 175 then
            self.arrowX = self.targetX - self.arrowWidth/2
            self.hitTarget = true
            self.win = true
        end
    end
end

function Game:draw()
    self.bowmanSpr:draw(self.bowmanX, self.bowmanY, 0, 1, 1)
    self.targetSpr:draw(self.targetX, self.targetY, 0, 1, 0.5)

    if self.arrowVisible then
        self.arrowSpr:draw(self.arrowX, self.arrowY, self.arrowTilt, 1, 1)
    end

    if self.drawn and not self.shot then
        local predictX = self.bowmanX + 28
        local predictY = self.bowmanY - 13
        local predictVx = math.cos(self.throwAng) * self.shotPower
        local predictVy = math.sin(self.throwAng) * self.shotPower
        self.arrowVx = math.cos(self.throwAng) * self.shotPower
        self.arrowVy = math.sin(self.throwAng) * self.shotPower
        for i=0, 59 do
            if i % 4 == 3 then
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