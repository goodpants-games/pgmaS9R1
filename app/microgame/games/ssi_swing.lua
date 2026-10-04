local Game = batteries.class { name = "microgame.ssi_swing" }
local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local Input = require("input")

---@param speed number Number of seconds removed from the timer.
---@param level number Difficulty level starting from 0. Increases after each boss round.
function Game:new(speed, level)
    self.verb = "Swing!"
    self.backgroundColor = { 0.0, 0.5, 0.0 }

    local resRoot = "/res/microgames/ssi_swing/"

    self.bgImg = Lg.newImage(resRoot .. "bg.png")
    self.shadowImg = Lg.newImage(resRoot .. "shadow16x8.png")

    self.sndOctoAlert = love.audio.newSource(resRoot .. "octopus_alert.wav", "static")
    self.sndOctoDive = love.audio.newSource(resRoot .. "octopus_dive.wav", "static")
    self.sndOctoKill = love.audio.newSource(resRoot .. "octopus_kill.wav", "static")
    self.sndPlrHurt = love.audio.newSource(resRoot .. "player_hurt.wav", "static")
    self.sndPlrSwing = love.audio.newSource(resRoot .. "player_swing.wav", "static")
    self.music = love.audio.newSource(resRoot .. "evildrone.ogg", "stream")
    self.music:setLooping(true)
    self.music:seek(love.math.random() * 2)
    self.music:play()
    self.sndWin = love.audio.newSource(resRoot .. "win.wav", "static")

    self.robotSpr = Sprite.new(resRoot .. "sprites/robot.json")
    self.robotSpr.alignment = "center"

    self.octoSpr = Sprite.new(resRoot .. "sprites/flying_enemy.json")
    self.octoSpr.alignment = "center"
    self.octoSpr:play("idle")

    self.yBase = 138

    self.octoTicker = 40
    self.octoStage = "idle"
    self.octoX = 50
    self.octoY = 10
    self.octoVx = 0
    self.octoVy = 0

    self.plrOx = 0

    self.isSwinging = false

    self.timer = 0
end

function Game:release()
    self.bgImg:release()
    self.shadowImg:release()
    self.sndOctoAlert:stop()
    self.sndOctoAlert:release()
    self.sndOctoDive:stop()
    self.sndOctoDive:release()
    self.sndOctoKill:stop()
    self.sndOctoKill:release()
    self.sndPlrHurt:stop()
    self.sndPlrHurt:release()
    self.sndPlrSwing:stop()
    self.sndPlrSwing:release()
    self.music:stop()
    self.music:release()
    self.sndWin:stop()
    self.sndWin:release()
    self.robotSpr:release()
    self.octoSpr:release()
end

function Game:tick()
    self.robotSpr:update(App.tickLength)
    self.octoSpr:update(App.tickLength)

    -- player logic/animation
    local isPlrAttackActive = false

    if not self.robotSpr.curAnim then
        self.robotSpr:play("idle")
    end

    if self.isSwinging then
        if self.robotSpr.curAnim == "melee_attack" then
            local frame = self.robotSpr:getAnimFrame()
            if frame == 8 then
                self.sndPlrSwing:play()
            end

            if frame >= 9 and frame <= 12 then
                isPlrAttackActive = true
            end
        else
            self.isSwinging = false
        end
    elseif self.robotSpr.curAnim == "idle" then
        if Input.players[1]:pressed("gameButton") then
            self.isSwinging = true
            self.robotSpr:play("melee_attack")
        end
    end

    self.plrOx = math.min(0.0, self.plrOx + 0.2)

    self.octoX = self.octoX + self.octoVx
    local octoCurve = true
    
    -- init
    if self.octoStage == "idle" then
        self.octoTicker = self.octoTicker - 1
        if self.octoTicker == 0 then
            -- enter windup
            self.octoStage = "windup"
            self.octoTicker = 30

            self.octoVx = 3
            self.sndOctoAlert:play()
        end
    
    -- windup
    elseif self.octoStage == "windup" then
        self.octoTicker = self.octoTicker - 1
        if self.octoTicker == 0 then
            -- enter dive
            self.octoStage = "dive"
            self.octoTicker = 120

            self.sndOctoDive:play()
        end

        self.octoVx = self.octoVx * 0.91
    
    -- dive
    elseif self.octoStage == "dive" then
        self.octoVx = -2
        
        if isPlrAttackActive and self.octoX < 25 then
            self.sndOctoKill:play()
            self.octoStage = "dead"
            self.octoSpr:play("dead")
            self.sndWin:play()
            self.music:stop()
            self.octoVx = 2.5
            self.octoVy = 2
        elseif self.octoX < 20 then
            self.octoVx = 2
            self.octoStage = "rebound"
            self.octoTicker = 60
            self.sndPlrHurt:play()
            self.robotSpr:play("hurt")
            self.plrOx = -6
        end
    
    elseif self.octoStage == "rebound" then
        local dx = 50 - self.octoX
        self.octoVx = self.octoVx + dx * 0.01 - self.octoVx * 0.08

        self.octoTicker = self.octoTicker - 1
        if self.octoTicker == 0 then
            self.octoStage = "windup"
            self.octoTicker = 30
            self.octoVx = 3
            self.sndOctoAlert:play()
        end
    
    elseif self.octoStage == "dead" then
        self.win = true

        octoCurve = false
        self.octoVy = self.octoVy - 0.15

        self.octoVx = self.octoVx * 0.95

        if self.octoY < 0 then
            self.octoY = 0
            self.octoVy = self.octoVy * -0.4
        end
    end

    if octoCurve then
        local dx = self.octoX - 20
        self.octoY = 0.008 * dx * dx + 6
    else
        self.octoY = self.octoY + self.octoVy
    end
end

function Game:draw()
    -- draw background
    Lg.draw(self.bgImg, 0, 0, 0, 2, 2)

    -- set scissor box so sprites don't get drawn in front of wall
    local scX, scY, scW, scH = Lg.getScissor()
    Lg.intersectScissor(scX, scY, scW, 142)
    
    -- draw robot
    Lg.setColor(1, 1, 1)
    self.robotSpr:draw(16 + math.round(self.plrOx) * 2, self.yBase - 28, 0, 2, 2)

    -- draw octopus
    local octoX = math.round(self.octoX) * 2
    local octoY = math.round(self.octoY) * 2
    Lg.setColor(1, 1, 1, 0.8)
    Lg.draw(self.shadowImg, octoX - 16, self.yBase - 8, 0, 2, 2)

    Lg.setColor(1, 1, 1)
    self.octoSpr:draw(octoX, self.yBase - octoY - 26, 0, 2, 2)
end

return Game --[[@as Microgame]]