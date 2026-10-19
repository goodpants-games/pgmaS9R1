local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local FontRes = require("fontres")

local MAX_USER_ERROR = 35
local USER_ERROR_SPEED_SCALE = 5

---@class _button: microgame.Game
local Game = batteries.class {
    name = "microgame.button",
    extends = GameBase
}

Game.resRoot = "/res/microgames/button"
Game.verb = "Press!"
Game.controls = {"tap"}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.backgroundColor = { 1.0, 1.0, 1.0 }

    print(self:getRes("button.json"))
    self.sprButton = Sprite.new(self:getRes("button.json"))
    self:releaseOnUnload(self.sprButton)

    self.sndBeep = self.manager:newAudioSource(self:getRes("beep.wav"), "static")
    self:releaseOnUnload(self.sndBeep)

    self.sndLose = self.manager:newAudioSource(self:getRes("scary.wav"), "static")
    self:releaseOnUnload(self.sndLose)

    local winSounds = love.filesystem.getDirectoryItems(self:getRes("win_sounds"))
    local chosenWinSound = "win_sounds/" .. winSounds[love.math.random(1, #winSounds)]

    self.musWin = self.manager:newAudioSource(self:getRes(chosenWinSound), "stream")
    self:releaseOnUnload(self.musWin)

    self.text = Lg.newText(FontRes.monogram)
    self:releaseOnUnload(self.text)

    self.isButtonDown = true
    self.gameEnded = false

    self.maxUserError = MAX_USER_ERROR - USER_ERROR_SPEED_SCALE * mgr.speed

    self.beepTickLen = math.floor(30 / mgr:getTempoScale())
    self.beepTickTicker = 0

    local maxTime = mgr.gameLength * 60 - MAX_USER_ERROR - 8
    maxTime = math.ceil(maxTime / self.beepTickLen)

    self.beepTicksWait = love.math.random(1, maxTime)
    self.beepTicks = self.beepTicksWait + 1
    print(self.beepTicks)

    self.curTick = 0

    if self.manager.difficulty > 0 then
        self.pressEffect = ({"win", "lose"})[love.math.random(1, 2)]
    else
        self.pressEffect = "win"
    end

    self.bgFlash = 0
    self.bgFlashMax = self.beepTickLen
    self.flashColor = 0x000000
end

function Game:tick()
    if self.bgFlash > 0 then
        self.bgFlash = self.bgFlash - 1
    end

    self.isButtonDown = self.manager:isButtonDown()

    if not self.gameEnded then
        if self.beepTicks > 0 then
            if self.beepTickTicker == 0 then
                self.beepTickTicker = self.beepTickLen
                self.beepTicks = self.beepTicks - 1

                if self.beepTicks == 0 then
                    self.sndBeep:stop()

                    if self.pressEffect == "win" then
                        self.sndBeep:setPitch(3/2)
                        self.flashColor = 0x00ff00
                        self.text:set("PRESS")
                    else
                        self.sndBeep:setPitch(math.sqrt(2))
                        self.flashColor = 0xff0000
                        self.text:set("NO")
                    end

                    self.sndBeep:play()
                    self.activateTick = self.curTick
                    self.bgFlash = self.bgFlashMax
                else
                    self.sndBeep:stop()
                    self.sndBeep:play()
                    self.text:set("WAIT")
                    self.bgFlash = self.bgFlashMax
                end
            end
            self.beepTickTicker = self.beepTickTicker - 1
        end

        local lose = false
        local diff = self.curTick - self.beepTickLen * self.beepTicksWait

        local btnPressed = self.manager:isButtonPressed()
        if diff < 0 then
            lose = btnPressed
        elseif self.pressEffect == "lose" then
            lose = btnPressed
        elseif self.pressEffect == "win" then
            if diff >= self.maxUserError then
                lose = true
            elseif btnPressed then
                self.win = true
                self.gameEnded = true

                self.flashColor = 0x007700
                self.bgFlashMax = 99999999
                self.bgFlash = self.bgFlashMax
                self.text:set("^.^ ")
                self.musWin:play()
            end
        end

        if lose then
            self.sndLose:stop()
            self.sndLose:play()
            self.gameEnded = true

            self.flashColor = 0x770000
            self.bgFlashMax = 99999999
            self.bgFlash = self.bgFlashMax
            self.text:set("FAIL")
        end
    end

    if self.isButtonDown then
        self.sprButton.cel = 2
    else
        self.sprButton.cel = 1
    end

    self.curTick = self.curTick + 1
end

function Game:unload()
    if not self.gameEnded and self.pressEffect == "lose" then
        print("win on end")
        self.win = true
    end

    self.__super.unload(self)
end

function Game:draw()
    if self.bgFlash > 0 then
        local r, g, b = batteries.colour.unpack_rgb(self.flashColor)
        Lg.setColor(r, g, b, self.bgFlash / self.bgFlashMax)
        Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)

        Lg.setColor(1, 1, 1)
        local textW, textH = self.text:getDimensions()
        for y=1, 20 do
            for x=1, 20 do
                Lg.draw(self.text, (x-1) * (textW*2) - 9, (y-1) * (textH*2) - 9, 0, 2, 2)
            end
        end
    end

    Lg.setColor(1, 1, 1)
    self.sprButton:draw(GameConf.scrW / 2, GameConf.scrH / 2)
end

return Game