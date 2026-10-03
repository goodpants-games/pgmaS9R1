local GameConf = require("microgame.conf")
local FontRes = require("fontres")

local scene = Sceneman.scene()
local self

local function loadMicrogame(name)
    local chunk = self.gameCache[name]
    if not chunk then
        local filePath = ("/microgame/games/%s.lua"):format(name)
        local err
        chunk, err = love.filesystem.load(filePath)
        if err then
            error(("could not load microgame '%s': %s"):format(name, err))
        end

        self.gameCache[name] = chunk
    end

    -- initialize microgame
    self.game = chunk()()

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

    self.verbText:set(self.game.verb)
    self.verbTextTimer = 1.0

    self.gameTimer = GameConf.refGameLength
end

local function getNextMicrogame()
    -- TODO: smarter algorithm which eliminates nearby duplicates
    return self.gameSet[love.math.random(1, #self.gameSet)]
end

function scene.load()
    self = {}

    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    local font = Lg.newFont("/res/fonts/monogram.ttf", 32, "mono", 1.0)
    self.verbText = Lg.newText(font)

    -- this holds cached microgame classes. don't use require so that these
    -- classes can be freed later, when no longer playing microgames
    self.gameCache = {}

    self.gameSet = {"test1", "test2"}
    self.nextMicrogameToLoad = getNextMicrogame()
end

function scene.unload()
    self.canvas:release()

    self = nil
end

function scene.update()
    if self.nextMicrogameToLoad then
        loadMicrogame(self.nextMicrogameToLoad)
        self.nextMicrogameToLoad = nil
    end

    self.game:tick()

    if self.verbTextTimer > 0.0 then
        self.verbTextTimer = self.verbTextTimer - App.tickLength
    end

    self.gameTimer = self.gameTimer - App.tickLength
    if self.gameTimer < 0 then
        self.gameTimer = 0
        self.nextMicrogameToLoad = getNextMicrogame()
    end
end

function scene.draw()
    local scrX = math.floor((App.scrW - GameConf.scrW) / 2)
    local scrY = math.floor((App.scrH - GameConf.scrH) / 2)

    Lg.push("all")

    -- set up draw bounds
    Lg.translate(scrX, scrY)
    Lg.intersectScissor(scrX, scrY, GameConf.scrW, GameConf.scrH)
    -- draw background
    Lg.setColor(self.game.backgroundColor)
    Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)
    -- draw game
    Lg.setColor(1, 1, 1)
    self.game:draw()

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