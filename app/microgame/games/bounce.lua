local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")

-- TODO: i swear sometimes the ball touches the top but then gets reflected
--       downwarsd? what??

---@class _pong: microgame.Game
local Game = batteries.class {
    name = "microgame.pong",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Bounce!"
    self.backgroundColor = { 0.0, 0.0, 0.0 }

    self.paddleRest = 160.0

    -- self.manager.speed = 2
    -- self.manager.difficulty = 2

    self.paddleW = 40 - self.manager.difficulty * 8
    self.paddleH = 4
    self.paddleX = math.round((GameConf.scrW - self.paddleW) / 2.0)
    self.paddleY = 160.0
    self.paddleVx = 0.0
    self.paddleVy = 0.0
    self.paddleR = 0.0
    self.paddleRv = 0.0
    self.paddleFrozen = true

    local ballSpawnDir
    if love.math.random() > 0.5 then
        ballSpawnDir = 1
    else
        ballSpawnDir = -1
    end
    local ballSpawnOfs = math.lerp(0.6, 1.0, love.math.random())
    self.ballX = GameConf.scrW / 2 + ballSpawnDir*ballSpawnOfs * self.paddleW*0.4
    self.ballY = 20.0
    self.ballVx = 0.0
    self.ballVy = 0.0
    self.ballR = 8.0
    self.ballSquash = 0.0
    self.ballSquashVel = 0.0
    self.ballG = 0.05 * (self.manager.speed * 0.5 + 1)

    self.startTimer = 1
    self.win = true

    local resRoot = "/res/microgames/bounce/"
    self.snd = {
        fail = mgr:newAudioSource(resRoot.."fail.wav", "static"),
        paddleBounce = mgr:newAudioSource(resRoot.."paddle_bounce.wav", "static"),
        wallBounce = mgr:newAudioSource(resRoot.."wall_bounce.wav", "static"),
    }
    for _, v in pairs(self.snd) do
        self:releaseOnUnload(v)
    end

    self.music = mgr:newAudioSource(resRoot.."music.ogg", "stream")
    self:releaseOnUnload(self.music)
    self.music:setVolume(0.5)
    self.music:play()
end

function Game:tick()
    -- paddle controls
    if not self.paddleFrozen then
        if self.manager:isButtonDown() then
            self.paddleVx = 3.0
        else
            self.paddleVx = -3.0
        end

        self.paddleX = self.paddleX + self.paddleVx
        self.paddleY = self.paddleY + self.paddleVy

        self.paddleVy = self.paddleVy + (self.paddleRest - self.paddleY) * 0.1 - self.paddleVy * 0.1
        self.paddleX = math.clamp(self.paddleX, 0, GameConf.scrW - self.paddleW)
    end

    self.paddleRv = self.paddleRv + (0 - self.paddleR) * 0.08 - self.paddleRv * 0.05
    self.paddleR = self.paddleR + self.paddleRv

    -- ball kinematics
    if self.startTimer > 0 then
        self.startTimer = self.startTimer - 1
    else
        for _=1, 4 do
            self.ballX = self.ballX + self.ballVx / 4
            self.ballY = self.ballY + self.ballVy / 4

            self.ballVy = self.ballVy + self.ballG

            -- edge collision
            local playWallBounce = false
            if self.ballX - self.ballR < 0 then
                self.ballX = self.ballR
                self.ballVx = -self.ballVx
                playWallBounce = true
            end
            if self.ballY - self.ballR < 0 then
                self.ballY = self.ballR
                self.ballVy = -self.ballVy
                playWallBounce = true
            end
            if self.ballX + self.ballR > GameConf.scrW then
                self.ballX = GameConf.scrW - self.ballR
                self.ballVx = -self.ballVx
                playWallBounce = true
            end

            if playWallBounce and self.win then
                self.snd.wallBounce:setPitch(love.math.random() * 0.2 + 1.0)
                self.snd.wallBounce:seek(0)
                self.snd.wallBounce:play()
            end

            self:_ball_paddle_collision()
        end
    end

    self.ballSquashVel = self.ballSquashVel + (0 - self.ballSquash) * 0.6 - self.ballSquashVel * 0.1
    self.ballSquash = self.ballSquash + self.ballSquashVel

    if self.ballY > GameConf.scrH then
        if self.win then
            self.snd.fail:play()
        end

        self.win = false
        self.paddleFrozen = true
    end
end

function Game:_ball_paddle_collision()
    local contactX = math.clamp(self.ballX, self.paddleX, self.paddleX + self.paddleW)
    local contactY = math.clamp(self.ballY, self.paddleY, self.paddleY + self.paddleH)
    local contactDx = self.ballX - contactX
    local contactDy = self.ballY - contactY
    local contactDistSq = contactDx * contactDx + contactDy * contactDy
    if contactDistSq < self.ballR * self.ballR then
        local contactDist = math.sqrt(contactDistSq)
        local nx = contactDx / contactDist
        local ny = contactDy / contactDist

        -- don't perform collision resolution if ball is already moving away
        -- from paddle
        local vdot = self.ballVx * nx + self.ballVy * ny
        if vdot < 0 then
            self.ballX = contactX + nx * self.ballR
            self.ballY = contactY + ny * self.ballR

            local ballSpd = math.sqrt(self.ballVx * self.ballVx + self.ballVy * self.ballVy)
            self.paddleVx = self.paddleVx - nx * ballSpd * 0.5
            self.paddleVy = self.paddleVy - ny * ballSpd * 0.5

            -- calculate torque on paddle
            local centerDx = contactX - (self.paddleX + self.paddleW/2)
            local centerDy = contactY - (self.paddleY + self.paddleH/2)
            local angleFac = centerDx * -ny + centerDy * nx
            self.paddleRv = self.paddleRv - angleFac * vdot * 0.001
            
            if self.paddleFrozen then
                local ang
                local ofsFromCenter = self.ballX - (self.paddleX + self.paddleW / 2.0)
                ang = ofsFromCenter * math.rad(2.0)
                ang = ang * (self.manager.difficulty * 0.5 + 1)

                self.ballVx = math.sin(ang) * ballSpd
                self.ballVy = -math.cos(ang) * ballSpd
            else
                self.ballVx = self.ballVx - nx * vdot * 2
                self.ballVy = self.ballVy - ny * vdot * 2
            end

            self.ballSquash = -0.5
            self.paddleFrozen = false

            self.snd.paddleBounce:setPitch(love.math.random() * 0.2 + 0.9)
            self.snd.paddleBounce:seek(0)
            self.snd.paddleBounce:play()
        end
    end
end

function Game:draw()
    -- draw paddle
    Lg.setColor(1, 1, 1)
    Lg.push()
    Lg.translate(
        math.round(self.paddleX + self.paddleW/2),
        math.round(self.paddleY + self.paddleH/2))
    Lg.rotate(self.paddleR)
    Lg.rectangle("fill", math.round(-self.paddleW/2), math.round(-self.paddleH/2), self.paddleW, self.paddleH)
    Lg.pop()

    -- draw ball
    Lg.setColor(1, 1, 1)
    Lg.setLineStyle("rough")

    local rx = self.ballR * math.pow(2.0, self.ballSquash)
    local ry = self.ballR * math.pow(2.0, -self.ballSquash)
    Lg.ellipse("line", math.round(self.ballX) + 0.5, math.round(self.ballY) + 0.5, rx, ry)
end

return Game