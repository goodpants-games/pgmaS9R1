local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")

-- TODO! limit max angle away from 1->2 checkpoint on fastest speed setting
--       otherwise it may be impossible for the player to win

local GRAVITY = 0.45
local LAUNCH_POWER = 9
local AIM_ANGLE_DELTA = math.rad(1.2)
local AIM_PHASE_LENGTH = 120
local AIM_MAX_ANGLE = AIM_PHASE_LENGTH / 4 * AIM_ANGLE_DELTA

---@class _sling: microgame.Game
local Game = batteries.class {
    name = "microgame.sling",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Sling!"
    self.backgroundColor = { batteries.colour.unpack_rgb(0xd8a2bf) }

    self.resRoot = "/res/microgames/sling/"
    self.plrImg = Lg.newImage(self:getRes("player.png"))
    self:releaseOnUnload(self.plrImg)

    self.plrLocked = true
    self.plrX = GameConf.scrW / 2
    self.plrY = GameConf.scrH - 20
    self.plrVx = 0
    self.plrVy = 0

    self.throwAng = -math.pi / 2
    self.throwTicker = 0

    local speedFac = 1.0 + mgr.speed * 0.5
    self.aimPhaseLength = math.round(AIM_PHASE_LENGTH / speedFac)
    self.aimAngleDelta = AIM_ANGLE_DELTA * (AIM_PHASE_LENGTH / self.aimPhaseLength)

    self.checkpoints = {}
    local baseX = self.plrX
    local baseY = self.plrY
    local minAng = -math.pi / 2 - AIM_MAX_ANGLE
    local maxAng = -math.pi / 2 + AIM_MAX_ANGLE

    local newestCheckpoint
    for ci=1, math.min(2, self.manager.difficulty + 1) do
        local newX, newY
        for j=1, 1000 do -- max iterations in case something very bad happens
            local ang = math.lerp(minAng, maxAng, love.math.random())
            local vx = math.cos(ang) * LAUNCH_POWER
            local vy = math.sin(ang) * LAUNCH_POWER
            local time = math.lerp(10, 30, love.math.random())

            newX, newY = self:_approximate_arc(baseX, baseY, vx, vy, time)

            if (newX > 20 and newX < GameConf.scrW - 20) and
               (newY - vy > 20)
            then
                goto foundPosition
            end

            print("ci", ci)
            print("newX", newX)
            print("newY", newY)
            print("Another iteration")
        end

        softerror("Something very bad happened")

        ::foundPosition::
        newX = math.round(newX)
        newY = math.round(newY)
        newestCheckpoint = self:_add_checkpoint(newX, newY)
        baseX, baseY = newX, newY
    end

    newestCheckpoint.last = true
end

function Game:_add_checkpoint(x, y)
    local checkpoint = {
        x = x, y = y,
        disabled = false,
        last = false
    }
    table.insert(self.checkpoints, checkpoint)
    return checkpoint
end

function Game:_approximate_arc(px, py, vx, vy, ticks)
    return
        px + vx * ticks,
        py + vy * ticks + 0.5 * GRAVITY * ticks * ticks
end

function Game:tick()
    if self.win then
        return
    end

    if self.plrLocked then
        local aimPhaseLen = self.aimPhaseLength
        local aimAngDelta = self.aimAngleDelta
        if (self.throwTicker + aimPhaseLen / 4) % aimPhaseLen < aimPhaseLen / 2 then
            self.throwAng = self.throwAng + aimAngDelta
        else
            self.throwAng = self.throwAng - aimAngDelta
        end

        -- self.plrX = App.mousex
        -- self.plrY = App.mousey
        self.throwTicker = (self.throwTicker + 1) % aimPhaseLen

        if self.manager:isButtonPressed() then
            self.plrLocked = false
            self.plrVx = math.cos(self.throwAng) * LAUNCH_POWER
            self.plrVy = math.sin(self.throwAng) * LAUNCH_POWER
        end
    else
        self.plrX = self.plrX + self.plrVx
        self.plrY = self.plrY + self.plrVy
        self.plrVy = self.plrVy + GRAVITY

        for _, cp in pairs(self.checkpoints) do
            if cp.disabled then
                goto continue
            end

            local dx = cp.x - self.plrX
            local dy = cp.y - self.plrY
            local dsq = dx * dx + dy * dy

            if dsq < 20 * 20 then
                local dist = math.sqrt(dsq)
                local dxn = dx / dist
                local dyn = dy / dist
                
                self.plrVx = self.plrVx + dxn * 2 - self.plrVx * 0.2
                self.plrVy = self.plrVy + dyn * 2 - self.plrVy * 0.2
            end

            if dsq < 2 * 2 then
                self.plrX = cp.x
                self.plrY = cp.y
                self.plrVx = 0
                self.plrVy = 0
                self.plrLocked = true
                cp.disabled = true

                if cp.last then
                    self.win = true
                end
                break
            end

            ::continue::
        end
    end
end

function Game:draw()
    -- checkpoints
    for _, checkpoint in pairs(self.checkpoints) do
        if checkpoint.last then
            Lg.setColor(1, 1, 0)
        else
            Lg.setColor(1, 0, 1)
        end

        Lg.circle("fill", checkpoint.x, checkpoint.y, 8)
    end

    -- path prediction
    if self.plrLocked and not self.win then
        local predictX = self.plrX
        local predictY = self.plrY
        local predictVx = math.cos(self.throwAng) * LAUNCH_POWER
        local predictVy = math.sin(self.throwAng) * LAUNCH_POWER
        for i=0, 59 do
            if i % 5 == 4 then
                Lg.setColor(1, 1, 1)
                Lg.rectangle("fill", predictX - 2, predictY - 2, 4, 4)
            end

            predictX = predictX + predictVx
            predictY = predictY + predictVy
            predictVy = predictVy + GRAVITY
        end

        --[[
        local dist = 1000
        local endX0 = math.cos(-math.pi / 2 + AIM_MAX_ANGLE)
        local endY0 = math.sin(-math.pi / 2 + AIM_MAX_ANGLE)
        local endX1 = math.cos(-math.pi / 2 - AIM_MAX_ANGLE)
        local endY1 = math.sin(-math.pi / 2 - AIM_MAX_ANGLE)
        Lg.setColor(1, 0, 0)
        Lg.line(self.plrX, self.plrY,
                self.plrX + endX0 * dist, self.plrY + endY0 * dist)
        Lg.line(self.plrX, self.plrY,
                self.plrX + endX1 * dist, self.plrY + endY1 * dist)
        --]]
    end

    -- player
    Lg.setColor(1, 1, 1)
    Lg.draw(self.plrImg, math.round(self.plrX), math.round(self.plrY),
            0,
            2, 2,
            self.plrImg:getWidth() / 2, self.plrImg:getHeight() / 2)
end

return Game