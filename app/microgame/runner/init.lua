local GameConf = require("microgame.conf")
local GameManager = require("microgame.manager")
local FontRes = require("fontres")
local Sprite = require("sprite")

local GAME_SET = {
    "ssi_swing",
    "bounce",
    "fruit_catch",
    "sling",
    "runner",
    "button",
    "flower",
}

local BOSS_ROUND_INTERVAL = 20
local MAX_LIVES = 4

local SPEED_UP_POINTS = {
    -- level 1
    { 8, 14 },
    -- level 2
    { 6, 12 },
    -- level 3
    { 4, 8 }
}

if false then
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
---@field rawUpdate fun(self:microgame.Runner.State, dt:number)?
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

        -- disable speed up points when testing a single game
        for _, t in pairs(SPEED_UP_POINTS) do
            table.clear(t)
        end
    else
        self.gameList = table.shuffle(GAME_SET)
    end
    self.gameListIdx = 1

    self.gameManager = GameManager()
    self.gameManager.difficulty = params.difficulty or 0
    self.gameManager.speed = params.speed or 0

    self.lives = MAX_LIVES
    self.gamesCompleted = 0
    -- current game within difficulty level
    self.round = 0

    ---@type {[string]:any}
    self.res = {}
    self.res.lifeSpr = Sprite.new("/res/sprites/hearts.json")
    self.res.lifeSpr.alignment = "topleft"

    self.res.bombSpr = Sprite.new("/res/sprites/bomb_timer.json")
    self.res.bombSpr.alignment = "topleft"

    self.res.bombFuseRopeImg = Lg.newImage("/res/sprites/bomb_timer_rope.png")
    self.res.bombFuseRopeImg:setWrap("repeat", "repeat")
    
    self.res.bombFuseFlameSpr = Sprite.new("/res/sprites/bomb_timer_fuse.json")
    self.res.shellImg = Lg.newImage("res/sprites/arcade_bars.png")
    self.res.bombFuseRopeQuad = Lg.newQuad(0,0, 0,0, 1,1)
    
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
end

---@param dt number
function Runner:update(dt)
    self.gameManager:rawUpdate(dt)
    
    if self.state and self.state.rawUpdate then
        self.state:rawUpdate(dt)
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

    Lg.draw(self.res.shellImg, 0, 0)
    
    -- draw lives counter
    for i=1, 4 do
        local x = 1
        local y = 10 + (i-1) * 25
        local c = 1
        if i <= self.lives then
            c = 2
        end

        Lg.setColor(1, 1, 1)
        self.res.lifeSpr:drawCel(c, x, y)
    end

    -- draw bomb
    -- Lg.setScissor(0, 0, self.scrX, App.scrH)
    -- Lg.setColor(1, 1, 1)
    -- self.res.bombSpr:drawCel(1, 2, 153)
    -- self.res.bombSpr:drawCel(2, 2, 153)
    -- Lg.setScissor()
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
    print("GAME ID", self.gameListIdx)
    local selectedGame = self.gameList[self.gameListIdx]
    self.gameListIdx = self.gameListIdx + 1

    if self.gameListIdx > #self.gameList then
        print("=== SHUFFLE GAME QUEUE ===")
        self.gameListIdx = 1

        -- handle last two games specially to ensure that they are never played
        -- again too soon
        local game1 = table.remove(self.gameList)
        local game2 = table.remove(self.gameList)
        local idx

        table.shuffle(self.gameList)

        idx = math.min(
            #self.gameList + 1,
            love.math.random(3, #self.gameList)
        )
        table.insert(self.gameList, idx, game1)
        
        idx = math.min(
            #self.gameList + 1,
            love.math.random(3, #self.gameList)
        )
        table.insert(self.gameList, idx, game2)
    end

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
    self.bossRound = runner.round % BOSS_ROUND_INTERVAL == 0

    -- ouch
    if runner.lostGame then
        runner.lives = runner.lives - 1
        -- restart game when out of lives
        if runner.lives == 0 and not Debug.enabled then
            Sceneman.switchScene("game_runner", {})
        end
    end

    local gameMgr = runner.gameManager
    local levelData = SPEED_UP_POINTS[gameMgr.difficulty + 1]

    self.speedUp = table.index_of(levelData, runner.round) ~= nil

    if self.speedUp then
        gameMgr.speed = gameMgr.speed + 1
    end

    if self.bossRound then
        gameMgr.speed = 0
        gameMgr.difficulty = gameMgr.difficulty + 1
        runner.round = 0

        if runner.lives < MAX_LIVES then
            runner.lives = runner.lives + 1
        end
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

    local txt = ""
    if self.speedUp then
        txt = txt .. "SPEED UP!"
    end
    if self.bossRound then
        txt = txt .. "LEVEL UP!"
    end
    
    Lg.print(txt, 10, 30)

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

    runner.res.bombFuseFlameSpr:play("fuse")

    runner:_loadMicrogame(runner:_getNextMicrogame())
end

---@param dt number
function PlayState:rawUpdate(dt)
    
end

function PlayState:exit()
    local runner = self.runner
    runner.gamesCompleted = runner.gamesCompleted + 1
    
    local didWin = runner.gameManager:unloadGame()
    softassert(didWin ~= nil, "unloaded empty game")
    if didWin == nil then didWin = true end

    runner.lostGame = not didWin
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

    runner.res.bombFuseFlameSpr:update(App.tickLength)
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
    local bombDrawX = 32
    local bombSpr = runner.res.bombSpr --[[@as pklove.Sprite]]
    
    Lg.setColor(0, 0, 0, 0.5)
    bombSpr:drawCel(1, bombDrawX + 1, 157 + 1)
    Lg.setColor(1, 1, 1)

    bombSpr:drawCel(1, bombDrawX, 157)
    bombDrawX = bombDrawX + 29
    if self.gameTimer <= GameConf.refGameLength then
        local progress = self.gameTimer / self.gameTimerMax
        local barWidth = (GameConf.scrW - bombDrawX + 30 - 6) * progress

        ---@type love.Quad
        local q = runner.res.bombFuseRopeQuad
        q:setViewport(0, 0, barWidth, 4, 4, 4)

        -- draw fuse rope shadow
        Lg.setColor(0, 0, 0)
        Lg.rectangle("fill", bombDrawX+1, 172+1, barWidth, 4)
        -- draw fuse rope
        Lg.setColor(1, 1, 1)
        Lg.draw(runner.res.bombFuseRopeImg, q, bombDrawX, 172)
        -- draw flame shadow
        local bombFuse = runner.res.bombFuseFlameSpr
        Lg.setColor(0, 0, 0)
        bombFuse:draw(bombDrawX + barWidth + 5, 170+1)
        -- draw flame
        Lg.setColor(1, 1, 1)
        bombFuse:draw(bombDrawX + barWidth + 4, 170)
    end
end

--------------------------------------------------------------------------------
return Runner