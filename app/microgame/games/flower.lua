local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")

local PETAL_BASE_RADIUS = 20
local CURSOR_TORQUE = math.rad(0.2)

---@class microgame._flower: microgame.Game
local Game = batteries.class {
    name = "microgame.flower",
    extends = GameBase
}

Game.resRoot = "/res/microgames/flower"

local SCALE_MAJOR = {0,2,4,5,7,9,11,12}
local SCALE_OCTATONIC = {0,2,3,5,6,8,9,11,12}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Pluck!"
    self.win = false
    self.backgroundColor = { batteries.colour.unpack_rgb(0x7570ff) }
    mgr:setGameLength(GameConf.refGameLength - mgr.speed)

    self.flowerX = math.round(GameConf.scrW / 2)
    self.flowerY = math.round(GameConf.scrH / 2)
    self.flowerR = 40

    self.cursorAng = -math.pi / 2
    self.cursorRotVel = 0
    self.cursorRotSpeed = math.rad(2 + self.manager.speed * 1)

    -- scale corresponds to # of petals
    self.musicScale = SCALE_MAJOR
    
    -- initialize petals
    local petalRadius = PETAL_BASE_RADIUS - mgr.difficulty * 3
    local petalCount = #self.musicScale
    self.petals = {}
    for i=1, petalCount do
        local ang = (i-1) / petalCount * math.pi*2 - math.pi/2
        local petal = self:_createPetal(ang, petalRadius)
        table.insert(self.petals, petal)
    end

    self.petalCount = petalCount
    self.petalsPlucked = 0

    self.cursorActive = false
    self.maxAngleError = math.rad(({24, 17, 12})[mgr.difficulty+1])

    self.heartIsBroken = petalCount % 2 == 1

    self.sprHeart = Sprite.new(self:getRes("heart.json"))
    self:releaseOnUnload(self.sprHeart)

    -- initialize resources
    self.res = {}
    self.res.sndPluck = mgr:newAudioSource(self:getRes("pluck.wav"), "static")
    self.res.sndOops = mgr:newAudioSource(self:getRes("oops.wav"), "static")
    self.res.sndWin = mgr:newAudioSource(self:getRes("win.wav"), "static")
    self.res.music = mgr:newAudioSource(self:getRes("flowers.ogg"), "stream")
    self.res.music:setVolume(0.5)
    self.res.music:setPitch(mgr:getTempoScale())
    self.res.music:play()

    for _, res in pairs(self.res) do
        self:releaseOnUnload(res)
    end
end

function Game:onTimerIncrease()
    self.res.music:setLooping(true)
end

function Game:tick()
    -- update falling petals
    for _, petal in pairs(self.petals) do
        if not petal.attached then
            petal.yv = petal.yv + 0.1
            petal.x = petal.x + petal.xv
            petal.y = petal.y + petal.yv
        end
    end

    -- update cursor
    if self.cursorActive then
        self.cursorRotVel = math.min(self.cursorRotVel + CURSOR_TORQUE, self.cursorRotSpeed)
        self.cursorAng = self.cursorAng + self.cursorRotVel
    end

    if self.manager:isButtonPressed() then
        if not self.cursorActive then
            self.cursorActive = true
            self.cursorRotVel = self.cursorRotSpeed
        end

        self:_pluck()
    end
end

function Game:draw()
    -- draw petals
    for _, petal in pairs(self.petals) do
        Lg.setColor(1, 1, 1)
        Lg.circle("fill", petal.x, petal.y, petal.r)
    end

    -- draw pistil
    Lg.setColor(batteries.colour.unpack_rgb(0xffc18f))
    Lg.circle("fill", self.flowerX, self.flowerY, self.flowerR)

    if self.heartIsBroken then
        self.sprHeart.cel = 2
    else
        self.sprHeart.cel = 1
    end
    self.sprHeart:draw(self.flowerX, self.flowerY + 4)
    
    -- draw cursor
    local cursorX = math.cos(self.cursorAng) * 30 + self.flowerX
    local cursorY = math.sin(self.cursorAng) * 30 + self.flowerY
    Lg.setColor(1, 0, 0)

    do
        local rectW = 8
        local rectH = 20
        Lg.push()
        Lg.translate(cursorX, cursorY)
        Lg.rotate(self.cursorAng + math.pi/2)
        Lg.rectangle("fill", -rectW/2, -rectH/2, rectW, rectH)
        Lg.pop()
    end
end

--------------------------------------------------------------------------------

---@param ang number
---@param r number
---@return table
function Game:_createPetal(ang, r)
    local petal = {}

    local distFromCenter = self.flowerR + r/2
    petal.x = math.cos(ang) * distFromCenter + self.flowerX
    petal.y = math.sin(ang) * distFromCenter + self.flowerY
    petal.r = r
    petal.xv = 0
    petal.yv = 0
    petal.attached = true
    petal.ang = ang

    return petal
end

function Game:_pluck()
    local targetPetal
    local minAngDiff = self.maxAngleError
    for i, petal in pairs(self.petals) do
        if petal.attached then
            local angDiff = math.angle_difference(petal.ang, self.cursorAng)
            
            if math.abs(angDiff) < minAngDiff then
                targetPetal = petal
                minAngDiff = angDiff
            end
        end
    end

    if targetPetal then
        print("min ang diff", math.deg(minAngDiff))

        targetPetal.attached = false
        targetPetal.xv = math.cos(targetPetal.ang) * 2
        targetPetal.yv = math.sin(targetPetal.ang) * 2

        local snd = self.res.sndPluck:clone()
        snd:setPitch(self:_getSoundPitch())
        snd:play()
        snd:release()

        self.petalsPlucked = self.petalsPlucked + 1
        self.heartIsBroken = not self.heartIsBroken

        if self.petalsPlucked == self.petalCount then
            self.res.sndWin:play()
            self.win = true
        end
    else
        local snd = self.res.sndOops:clone()
        snd:setPitch(self:_getSoundPitch() + (love.math.random()*2-1) * 0.1)
        snd:play()
        snd:release()

        self.cursorRotVel = -math.rad(2)
    end
end

---@return number
function Game:_getSoundPitch()
    local i = math.min(#self.musicScale, self.petalsPlucked+1)
    return math.pow(2.0, self.musicScale[i] / 12)
end

--------------------------------------------------------------------------------

return Game