local AudioSourceWrap = require("microgame.audio_source_wrap")
local GameConf = require("microgame.conf")
local Input = require("input")

---@class microgame.Manager
---Microgame runner
---@overload fun():microgame.Manager
local GameManager = batteries.class { name = "microgame.Manager" }

function GameManager:new()
    ---Speed level starting from 0.
    self.speed = 0
    ---Difficulty level starting from 0. Increases after each boss round.
    self.difficulty = 0

    ---@private
    ---@type microgame.SourceWrap[]?
    self._audioSrcs = nil

    ---@type microgame.Game?
    self.game = nil

    ---Current game length in seconds.
    self.gameLength = 0.0
    ---Number of seconds left on the timer.
    self.timer = 0.0
    self.tickSpeed = 1.0

    ---@private
    self._audioSrcReleaseFn = function(this)
        if this:isPlaying() then
            this._queueRelease = true
        else
            self:_releaseSourceWrap(this)
        end
    end

    ---@private
    self._audioSrcCloneFn = function(this)
        local clone = self:_addSourceWrap(getmetatable(this).clone(this))
        return clone
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

---@param beats number
function GameManager:setGameLength(beats)
    local t = beats * GameConf.secsPerBeat
    self.gameLength = t
    self.timer = t
end

function GameManager:getTempoScale()
    return GameConf.refGameLength * GameConf.secsPerBeat / self.gameLength
end

---Create a new audio source. Always use this instead of love.audio.newSource
---for audio in a microgame, so that its pitch can be scaled according to the
---tickSpeed variable.
---@param path string
---@param sourceType "static"|"stream"
function GameManager:newAudioSource(path, sourceType)
    local src = AudioSourceWrap(love.audio.newSource(path, sourceType))
    return self:_addSourceWrap(src)
end

---Create a new queueable audio source. Always use this instead of
---love.audio.newQueueableSource, so that its pitch can be scaled according to
---the tickSpeed variable.
---@param sampleRate integer
---@param depth integer
---@param channels integer
---@param bufferCount integer?
---@return love.Source
function GameManager:newQueueableAudioSource(sampleRate, depth, channels, bufferCount)
    local src = AudioSourceWrap(
        love.audio.newQueueableSource(sampleRate, depth, channels, bufferCount)
    )
    return self:_addSourceWrap(src)
end

---@return boolean
function GameManager:isButtonPressed()
    return self._btnState[1] and not self._btnState[2]
end

---@return boolean
function GameManager:isButtonReleased()
    return not self._btnState[1] and self._btnState[2]
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
    self:setGameLength(GameConf.refGameLength - self.speed * 2)
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

    self._timeAccum = 0.0

    -- reset button state
    self._btnState[1] = Input.players[1]:down("gameButton")
    self._btnState[2] = self._btnState[1]
    self._queueBtnPress = false
    self._queueBtnRelease = false
end

---@return boolean? didWin
function GameManager:unloadGame()
    if not self.game then
        return
    end

    local didWin = false

    if self.game.unload then
        self.game:unload()
        didWin = not not self.game.win
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

    return didWin
end

---@param dt number
function GameManager:rawUpdate(dt)
    local device = Input.players[1]

    if device:pressed("gameButton") then
        self._queueBtnPress = true
    end

    if device:released("gameButton") then
        self._queueBtnRelease = true
    end

    if self.game and self.game.rawUpdate then
        self.game:rawUpdate(dt)
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

        self.timer = self.timer - App.tickLength * self.tickSpeed
        if self.timer < 0 then
            self.timer = 0
        end
    end
end

function GameManager:draw()
    if self.game then
        Lg.push("all")

        -- draw background
        Lg.setColor(self.game.backgroundColor)
        Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)
        -- draw game
        Lg.setColor(1, 1, 1)
        self.game:draw()
        
        Lg.pop()
    end
end

---@private
---@param scale number
function GameManager:_setAudioPitchScale(scale)
    for i=#self._audioSrcs, 1, -1 do
        local src = self._audioSrcs[i] --[[@as any]]
        src:_setPitchScale(scale)
        
        if src._queueRelease and not src:isPlaying() then
            self:_releaseSourceWrap(src)
        end
    end
end

---@param src love.Source|microgame.SourceWrap
function GameManager:_addSourceWrap(src)
    src.release = self._audioSrcReleaseFn
    src.clone = self._audioSrcCloneFn
    table.insert(self._audioSrcs, src)
    src:_setPitchScale(self.tickSpeed)
    return src
end

---@param src love.Source|microgame.SourceWrap
function GameManager:_releaseSourceWrap(src)
    table.remove_value(self._audioSrcs, src)
    src.release = getmetatable(src).release
    src.clone = getmetatable(src).clone
    src:release()
end

return GameManager