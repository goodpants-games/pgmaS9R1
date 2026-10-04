local GameConf = require("microgame.conf")
local GameManager = require("microgame.manager")
local FontRes = require("fontres")

local scene = Sceneman.scene()
local self

local GAME_SET = {
    "ssi_swing",
    "bounce",
    "fruit_catch",
}

local function loadMicrogame(name)
    local gameCtor = self.gameCache[name]
    if not gameCtor then
        local filePath = ("/microgame/games/%s.lua"):format(name)
        local chunk, err = love.filesystem.load(filePath)
        if err then
            error(("could not load microgame '%s': %s"):format(name, err))
        end

        gameCtor = chunk() --[[@as microgame.Game]]
        self.gameCache[name] = gameCtor
    end

    -- initialize microgame
    self.gameManager:loadGame(gameCtor)

    self.verbText:set(self.gameManager.game.verb)
    self.verbTextTimer = 1.0

    self.gameTimer = GameConf.refGameLength
end

local function getNextMicrogame()
    -- TODO: smarter algorithm which eliminates nearby duplicates
    return self.gameSet[love.math.random(1, #self.gameSet)]
end

function scene.load(data)
    self = {}

    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    local font = Lg.newFont("/res/fonts/monogram.ttf", 32, "mono", 1.0)
    self.verbText = Lg.newText(font)

    -- this holds cached microgame classes. don't use require so that these
    -- classes can be freed later, when no longer playing microgames
    ---@type {[string]:microgame.Game}
    self.gameCache = {}

    if data.initMicrogame then
        self.gameSet = {data.initMicrogame}
    else
        self.gameSet = GAME_SET
    end
    self.nextMicrogameToLoad = getNextMicrogame()

    self.gameManager = GameManager()
end

function scene.unload()
    self.canvas:release()

    self = nil
end

function scene.update(dt)
    self.gameManager:update(dt)
end

---@diagnostic disable-next-line
function scene.tick()
    if self.nextMicrogameToLoad then
        loadMicrogame(self.nextMicrogameToLoad)
        self.nextMicrogameToLoad = nil
    end

    self.gameManager:tick()

    if self.verbTextTimer > 0.0 then
        self.verbTextTimer = self.verbTextTimer - App.tickLength
    end

    self.gameTimer = self.gameTimer - App.tickLength * self.gameManager.gameSpeed
    if self.gameTimer < 0 then
        self.gameTimer = 0
        self.nextMicrogameToLoad = getNextMicrogame()
        -- self.gameManager.gameSpeed = self.gameManager.gameSpeed + 0.5
    end
end

function scene.draw()
    local scrX = math.floor((App.scrW - GameConf.scrW) / 2)
    local scrY = math.floor((App.scrH - GameConf.scrH) / 2)

    Lg.push("all")

    -- set up draw bounds
    Lg.translate(scrX, scrY)
    Lg.intersectScissor(scrX, scrY, GameConf.scrW, GameConf.scrH)
    -- draw game
    self.gameManager:draw()

    Lg.pop()

    -- draw verb text
    if self.verbTextTimer > 0.0 then
        local textW, textH = self.verbText:getDimensions()
        local drawX = scrX + (GameConf.scrW - textW) / 2
        local drawY = scrY + (GameConf.scrH - textH) / 2

        Lg.setColor(0, 0, 0, 0.5)
        Lg.draw(self.verbText, drawX + 2, drawY + 2)

        Lg.setColor(1, 1, 1)
        Lg.draw(self.verbText, drawX, drawY)
    end

    -- draw timer bar
    if self.gameTimer <= GameConf.refGameLength then
        local progress = self.gameTimer / GameConf.refGameLength
        local barWidth = GameConf.scrW * progress
        Lg.setColor(1, 0, 0)
        Lg.rectangle("fill", scrX, App.scrH - 8, barWidth, 8)
    end
end

return scene