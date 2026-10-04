local AudioSourceWrap = require("microgame.audio_source_wrap")
local GameConf = require("microgame.conf")
local Input = require("input")

---@class microgame.Manager
---@overload fun():microgame.Manager
local GameManager = batteries.class { name = "microgame.Manager" }

function GameManager:new()
    ---Number of seconds removed from the timer.
    self.speed = 0
    ---Difficulty level starting from 0. Increases after each boss round.
    self.difficulty = 0

    ---@private
    ---@type microgame.SourceWrap[]?
    self._audioSrcs = nil

    ---@type microgame.Game?
    self.game = nil

    self.timer = 0.0
    self.tickSpeed = 1.0

    ---@private
    self._audioSrcReleaseFn = function(this)
        table.remove_value(self._audioSrcs, this)
        this.release = getmetatable(this).release
        this:release()
    end

    ---@private
    self._timeAccum = 0.0

    ---@private
    self._btnState = { false, false }
    ---@private
    self._queueBtnPress = false
    ---@private
    self._queueBtnRelease = false
end

---Create a new audio source. Always use this instead of love.audio.newSource
---for audio in a microgame, so that its pitch can be scaled according to the
---tickSpeed variable.
---@param path string
---@param sourceType "static"|"stream"
function GameManager:newAudioSource(path, sourceType)
    local src = AudioSourceWrap(path, sourceType)
    src.release = self._audioSrcReleaseFn
    table.insert(self._audioSrcs, src)
    return src
end

---@return boolean
function GameManager:isButtonPressed()
    return self._btnState[1] and not self._btnState[2]
end

---@return boolean
function GameManager:isButtonDown()
    return self._btnState[1]
end

function GameManager:loadGame(gameCtor)
    self:unloadGame()
    self._audioSrcs = {}
    self._gameResources = {}

    -- initialize microgame
    self.game = gameCtor(self)

    -- validate fields
    if not self.game.verb then
        error("microgame did not define verb")
    end
    if not self.game.tick then
        error("microgame did not define tick procedure")
    end
    if not self.game.draw then
        error("microgame did not define draw procedure")
    end
    if not self.game.backgroundColor then
        self.game.backgroundColor = { 0.0, 0.0, 0.0 }
    end

    self.timer = GameConf.refGameLength
    self._timeAccum = 0.0
end

function GameManager:unloadGame()
    if not self.game then
        return
    end

    if self.game.unload then
        self.game:unload()
    end
    
    for _, res in pairs(self._gameResources) do
        if res:typeOf("Source") then
            (res--[[@as love.Source]]):stop()
        end
        res:release()
    end

    self.game = nil
    self._audioSrcs = nil
    self._gameResources = nil
end

---@param dt number
function GameManager:update(dt)
    local device = Input.players[1]

    if device:pressed("gameButton") then
        self._queueBtnPress = true
    end

    if device:released("gameButton") then
        self._queueBtnRelease = true
    end
end

function GameManager:tick()
    if self.game then
        self._timeAccum = self._timeAccum + self.tickSpeed
        self:_setAudioPitchScale(self.tickSpeed)

        while self._timeAccum >= 1.0 do
            self._btnState[2] = self._btnState[1]

            if self._queueBtnPress then
                self._btnState[1] = true
                self._queueBtnPress = false
            elseif self._queueBtnRelease then
                self._btnState[1] = false
                self._queueBtnRelease = false
            end

            self.game:tick()
            self._timeAccum = self._timeAccum - 1.0
        end
    end
end

function GameManager:draw()
    if self.game then
        -- draw background
        Lg.setColor(self.game.backgroundColor)
        Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)
        -- draw game
        Lg.setColor(1, 1, 1)
        self.game:draw()
    end
end

---@private
---@param scale number
function GameManager:_setAudioPitchScale(scale)
    for _, src in pairs(self._audioSrcs) do
        src:_setPitchScale(scale)
    end
end

return GameManager