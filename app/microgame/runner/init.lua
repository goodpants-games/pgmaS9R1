local GameConf = require("microgame.conf")
local GameManager = require("microgame.manager")
local FontRes = require("fontres")
local Sprite = require("sprite")

local GAME_SELECT_CHANCE = 0.4 -- ∈ [0, 1)
local GAME_SET = {
    "ssi_swing",
    "bounce",
    "fruit_catch",
    "sling",
    "test1",
    "test2",
}

local BOSS_ROUND_INTERVAL = 20

local SPEED_UP_POINTS = {
    -- level 1
    { 10, 16 },
    -- level 2
    { 9, 15 },
    -- level 3
    { 7, 14 }
}

if Debug.enabled then
    print("INSERT DEBUG SPEED UP POINTS")
    for i=1, 3 do
        table.insert(SPEED_UP_POINTS, 1, { 2, 5 })
    end
end

---@class microgame.Runner: batteries.Class
---@overload fun(params:table):microgame.Runner
---UI for the game
local Runner = batteries.class {
    name = "microgame.Runner"
}

---@class microgame.Runner.State
---@overload fun(runner:microgame.Runner, ...: any):microgame.Runner.State
---@field tick fun(self:microgame.Runner.State)
---@field update fun(self:microgame.Runner.State, dt:number)?
---@field draw fun(self:microgame.Runner.State)
---@field exit fun(self:microgame.Runner.State)?

---@type {[string]:microgame.Runner.State}
local runStates = {}

function Runner:new(params)
    local font = Lg.newFont("/res/fonts/monogram.ttf", 32, "mono", 1.0)
    self.verbText = Lg.newText(font)

    -- this holds cached microgame classes. don't use require so that these
    -- classes can be freed later, when no longer playing microgames
    ---@type {[string]:microgame.Game}
    self.gameCache = {}

    if params.initMicrogame then
        self.gameList = {params.initMicrogame}
    else
        self.gameList = table.shuffle(GAME_SET)
    end
    self.nextMicrogameToLoad = self:_getNextMicrogame()

    self.gameManager = GameManager()

    self.lives = 4
    self.gamesCompleted = 0
    -- current game within difficulty level
    self.round = 0

    ---@type {[string]:any}
    self.res = {}
    self.res.lifeImg = Lg.newImage("/res/img/life.png")
    self.res.bombSpr = Sprite.new("/res/sprites/bomb.json")
    self.res.bombSpr.alignment = "topleft"

    ---@type microgame.Runner.State
    self.state = nil

    self.scrX = math.floor((App.scrW - GameConf.scrW) / 2)
    self.scrY = math.floor((App.scrH - GameConf.scrH) / 2)

    -- god damnit
    self.lostGame = false

    self:_switchState("enterGame")
end

function Runner:release()
    for _, res in pairs(self.res) do
        if res.release then
            res:release()
        end
    end

    self.canvas:release()
end

---@param dt number
function Runner:update(dt)
    self.gameManager:update(dt)
    
    if self.state and self.state.update then
        self.state:update(dt)
    end
end

function Runner:tick()
    if self._queuedStateSwitch then
        if self.state and self.state.exit then
            self.state:exit()
        end

        local data = self._queuedStateSwitch
        self._queuedStateSwitch = nil

        self.state = data.ctor(self, unpack(data.args))
    end

    self.state:tick()
end

function Runner:draw()
    self.state:draw()
    
    -- draw lives counter
    for i=1, self.lives do
        local x = 2
        local y = 2 + (i-1) * 24

        Lg.setColor(1, 1, 1)
        Lg.draw(self.res.lifeImg, x, y)
    end

    -- draw bomb
    Lg.setScissor(0, 0, self.scrX, App.scrH)
    Lg.setColor(1, 1, 1)
    self.res.bombSpr:drawCel(1, 2, 153)
    self.res.bombSpr:drawCel(2, 2, 153)
    Lg.setScissor()
end

---@param newState string
---@param ... any
function Runner:_switchState(newState, ...)
    assert(runStates[newState], ("invalid state '%s'"):format(newState))

    self._queuedStateSwitch = {
        ctor = runStates[newState],
        args = { ... }
    }
end

function Runner:_getNextMicrogame()
    -- traverse through the game list in ascending order. on each iteration,
    -- there is a chance that that game will be picked. once picked, move that
    -- element to the end of the list.
    local gameListLen = #self.gameList
    local selectIdx = 1

    -- TODO: make random selection more evenly distributed across the list,
    --       while still making the first few entries the most likelist to be
    --       picked, while having all of their probabilities add up to 1.

    -- stop on the third-to-last-item to guarantee that it will not pick one of
    -- the last two chosen games
    while selectIdx < gameListLen - 2 do
        if love.math.random() < GAME_SELECT_CHANCE then
            break
        end
        selectIdx = selectIdx + 1
    end

    local selectedGame = table.remove(self.gameList, selectIdx)
    table.insert(self.gameList, selectedGame)

    return selectedGame
end

function Runner:_loadMicrogame(name)
    -- load game constructor from cache, or, if not exists, load from the file
    -- and save it to the cache.
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

    print(("enter game '%s'"):format(name))

    -- initialize microgame
    self.gameManager:loadGame(gameCtor)

    self.verbText:set(self.gameManager.game.verb)
end








--------------------------------------------------------------------------------
--- STATE: enterGame
--------------------------------------------------------------------------------
---@class microgame.Runner.EnterGameState: microgame.Runner.State
local EnterGameState = batteries.class {
    name = "microgame.Runner.EnterGameState"
}
runStates.enterGame = EnterGameState

---@param runner microgame.Runner
function EnterGameState:new(runner)
    self.runner = runner
    self.time = 0
    
    runner.round = runner.round + 1

    -- ouch
    if runner.lostGame then
        runner.lives = runner.lives - 1
    end

    local gameMgr = runner.gameManager
    local levelData = SPEED_UP_POINTS[gameMgr.difficulty + 1]

    self.speedUp = table.index_of(levelData, runner.round) ~= nil
    if self.speedUp then
        gameMgr.speed = gameMgr.speed + 1
    end
end

function EnterGameState:tick()
    local runner = self.runner

    if self.time == 60 then
        runner:_switchState("play")
    end

    self.time = self.time + 1
end

function EnterGameState:draw()
    local runner = self.runner
    local scrX, scrY = runner.scrX, runner.scrY

    Lg.push()
    Lg.translate(scrX, scrY)

    Lg.setColor(0, 0, 0)
    Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)

    Lg.setColor(1, 1, 1)
    Lg.print(tostring(runner.gamesCompleted + 1), 10, 10)

    if self.speedUp then
        Lg.print("SPEED UP!", 10, 30)
    end

    Lg.pop()
end










--------------------------------------------------------------------------------
--- STATE: play
--------------------------------------------------------------------------------
---@class microgame.Runner.PlayState: microgame.Runner.State
local PlayState = batteries.class {
    name = "microgame.Runner.PlayState"
}
runStates.play = PlayState

---@param runner microgame.Runner
function PlayState:new(runner)
    self.runner = runner
    self.verbTextTimer = 1.0
    self.gameTimerMax = GameConf.refGameLength - runner.gameManager.speed * 1
    self.gameTimer = self.gameTimerMax

    runner:_loadMicrogame(runner:_getNextMicrogame())
end

---@param dt number
function PlayState:update(dt)
    
end

function PlayState:exit()
    local runner = self.runner
    runner.gamesCompleted = runner.gamesCompleted + 1
    runner.gameManager:unloadGame()
end

function PlayState:tick()
    local runner = self.runner
    runner.gameManager:tick()
    runner.lostGame = not runner.gameManager.game.win

    if self.verbTextTimer > 0.0 then
        self.verbTextTimer = self.verbTextTimer - App.tickLength
    end

    self.gameTimer = self.gameTimer - App.tickLength * runner.gameManager.tickSpeed
    if self.gameTimer < 0 then
        runner:_switchState("enterGame")

        -- if not self.gameManager.game.win then
        --     self.lives = self.lives - 1
        --     if self.lives == 0 then
        --         love.window.showMessageBox("Loser", "you lost", "info", true)
        --     end
        -- end
        -- self.gameManager.tickSpeed = self.gameManager.tickSpeed + 0.5
    end
end

function PlayState:draw()
    local runner = self.runner
    local scrX, scrY = runner.scrX, runner.scrY

    Lg.push("all")

    -- set up draw bounds
    Lg.translate(scrX, scrY)
    Lg.intersectScissor(scrX, scrY, GameConf.scrW, GameConf.scrH)
    -- draw game
    runner.gameManager:draw()

    Lg.pop()

    -- draw verb text
    if self.verbTextTimer > 0.0 then
        local textW, textH = runner.verbText:getDimensions()
        local drawX = scrX + (GameConf.scrW - textW) / 2
        local drawY = scrY + (GameConf.scrH - textH) / 2

        Lg.setColor(0, 0, 0, 0.5)
        Lg.draw(runner.verbText, drawX + 2, drawY + 2)

        Lg.setColor(1, 1, 1)
        Lg.draw(runner.verbText, drawX, drawY)
    end

    -- timer bar
    Lg.setColor(batteries.color.unpack_rgb(0xffffff))
    runner.res.bombSpr:drawCel(2, 2, 153)
    if self.gameTimer <= GameConf.refGameLength then
        local progress = self.gameTimer / self.gameTimerMax
        local barWidth = GameConf.scrW * progress
        Lg.rectangle("fill", 33 + 2, 153+21, barWidth, 4)
    end
end

--------------------------------------------------------------------------------
return Runner