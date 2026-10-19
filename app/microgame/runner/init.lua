local GameConf = require("microgame.conf")
local GameManager = require("microgame.manager")
local FontRes = require("fontres")
local Sprite = require("sprite")
local Input = require("input")

local GAME_SET = {
    "ssi_swing",
    "bounce",
    "fruit_catch",
    "sling",
    "runner",
    "button",
    "flower",
    "bow",
}

local MAX_LIVES = GameConf.maxLives
local SPEED_UP_POINTS = GameConf.speedUpPoints
local SHOP_POINTS = GameConf.shopPoints

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
---@field auxButtonPressed fun(self:microgame.Runner.State, idx:integer)?
---@field permittedItems string[]?

---@class microgame.Runner.Item
---@field id string?
---@field data any

---@type {[string]:microgame.Runner.State}
local runStates = {}

---@type {[string]:fun(item:microgame.Runner.Item, state:any):boolean?}
local itemUseProcedures = {}

function Runner:new(params)
    local font = Lg.newFont("/res/fonts/monogram.ttf", 32, "mono", 1.0)
    self.verbText = Lg.newText(font)

    -- this holds cached microgame classes. don't use require so that these
    -- classes can be freed later, when no longer playing microgames
    ---@type {[string]:microgame.Game}
    self.gameCache = {}

    -- disable speed up points when speed/difficulty is manually specified
    if params.difficulty or params.speed then
        for _, t in pairs(SPEED_UP_POINTS) do
            table.clear(t)
        end
    end

    if params.initMicrogame then
        self.gameList = {params.initMicrogame}
    else
        self.gameList = table.shuffle(GAME_SET)
    end
    self.gameListIdx = 1
    ---@type string?
    self.forceGame = nil

    self.gameManager = GameManager()
    self.gameManager.difficulty = params.difficulty or 0
    self.gameManager.speed = params.speed or 0

    self.lives = MAX_LIVES
    self.lifeShields = 0
    self.gamesCompleted = 0
    -- current game within difficulty level
    self.round = 0

    ---@type {[string]:any}
    self.res = {}

    self.res.bombSpr = Sprite.new("/res/sprites/bomb_timer.json")
    self.res.bombSpr.alignment = "topleft"

    self.res.bombFuseRopeImg = Lg.newImage("/res/sprites/bomb_timer_rope.png")
    self.res.bombFuseRopeImg:setWrap("repeat", "repeat")
    
    self.res.bombFuseFlameSpr = Sprite.new("/res/sprites/bomb_timer_fuse.json")
    self.res.bombFuseRopeQuad = Lg.newQuad(0,0, 0,0, 1,1)

    self.res.itemsSpr = Sprite.new("/res/sprites/items.json")
    self.res.itemsSpr.alignment = "center"

    self.res.imgBgBlackGradient = Lg.newImage("/res/img/bg_black_gradient.png")
    self.res.beetleFaceSpr = Sprite.new("/res/sprites/firebeetle_face.json")

    self.res.asrcBorderExpand =
        love.audio.newSource("/res/sounds/border_expand.wav", "static")
    self.res.asrcBorderExpand:setVolume(0.5)
    self.res.asrcBorderContract =
        love.audio.newSource("/res/sounds/border_contract.wav", "static")
    self.res.asrcBorderContract:setVolume(0.5)
    
    do
        local function newSndData(nm)
            return love.sound.newSoundData(
                ("/res/music/game_intermission/%s.wav"):format(nm)
            )
        end

        self.res.intermissionSnddata = {
            statusLose = newSndData("status_lose"),
            statusWin = newSndData("status_win"),
            speedUp = newSndData("effect_speed_up"),
            stageScreen = newSndData("stage"),
            gameOver = newSndData("game_over"),
        }
    end
    
    ---@type microgame.Runner.State
    self.state = nil

    self.scrX = math.floor((App.scrW - GameConf.scrW) / 2)
    self.scrY = math.floor((App.scrH - GameConf.scrH) / 2)

    -- god damnit
    self.lostGame = false

    ---@type microgame.Runner.Item[]
    self.items = {}
    for i=1, 3 do
        self.items[i] = { id = nil }
    end

    self.pressedAuxButtons = { false, false, false }
    self.canUseItems = false

    self:_nextRound()
end

local function releaseResTable(resTable)
    for _, res in pairs(resTable) do
        if res.stop then
            res:stop()
        end
        if res.release then
            res:release()
        end
    end
end

function Runner:release()
    releaseResTable(self.res.intermissionSnddata)
    self.res.intermissionSnddata = nil
    releaseResTable(self.res)

    for i=1, 3 do
        Display.items[i] = "nil"
    end
end

function Runner:_releaseResources(resTable)
    for _, res in pairs(resTable) do
        if res.stop then
            res:stop()
        end
        if res.release then
            res:release()
        end
    end
end

---@param dt number
function Runner:update(dt)
    if Debug.enabled and not IS_PACKAGED then
        if love.keyboard.isDown("f2") then
            self:_debugCommand()
        end
    end

    local device = Input.players[1]
    if device:pressed("auxButton1") then
        self.pressedAuxButtons[1] = true
    end
    if device:pressed("auxButton2") then
        self.pressedAuxButtons[2] = true
    end
    if device:pressed("auxButton3") then
        self.pressedAuxButtons[3] = true
    end

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

    for i=1, #self.pressedAuxButtons do
        if self.pressedAuxButtons[i] then
            if self.state.auxButtonPressed then
                self.state:auxButtonPressed(i)
            end

            self.pressedAuxButtons[i] = false
            self:_useItem(i)
        end
    end
end

function Runner:draw()
    self.state:draw()
    
    -- update life display
    for i=1, 4 do
        local color = "off"
        if i <= self.lives then
            color = "red"
            if i > self.lives - self.lifeShields then
                color = "blue"
            end
        end

        Display.heartLeds[i] = color
    end

    -- draw items
    for i=1, #self.items do
        local item = self.items[i]

        local imgName = item.id or "nil"
        Display.items[i] = imgName
    end
end

function Runner:getTickSpeed()
    return 1.0 + self.lifeShields * 0.5
end

---@param newState string|function
---@param ... any
function Runner:_switchState(newState, ...)
    if type(newState) == "function" then
        self._queuedStateSwitch = {
            ctor = newState,
            args = { ... }
        }
    else
        assert(runStates[newState], ("invalid state '%s'"):format(newState))

        self._queuedStateSwitch = {
            ctor = runStates[newState],
            args = { ... }
        }
    end
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

---@param idx integer
function Runner:_useItem(idx)
    if not self.canUseItems then
        return
    end

    local item = self.items[idx]
    local itemId = item.id
    local permittedItems = self.state.permittedItems
    if not (permittedItems and table.index_of(permittedItems, itemId)) then
        return
    end

    if not itemUseProcedures[itemId](item, self.state) then
        item.id = nil
        item.data = nil
    end
    self.canUseItems = false
    print("set it to false", self.canUseItems)
end

---@param self microgame.Runner
local function nextRoundCallback(self)
    self.canUseItems = false
    self.round = self.round + 1

    return runStates.gameIntermission(self, {
        lostGame = self.lostGame
    })
end

function Runner:_nextRound()
    self:_switchState(nextRoundCallback)
end

function Runner:_debugCommand()
    while true do
        io.write(">")
        local args = {}
        for arg in string.gmatch(io.read("*l"), "[^%s+]+") do
            table.insert(args, arg)
        end

        if args[1] == "continue" then
            break
        end

        if args[1] == "help" then
            print("continue")
            print("set_item <idx> <name>")
            print("give_item <name>")
            print("set_speed <spd>")
            print("set_level <lvl>")
            goto continue
        end

        if args[1] == "set_item" then
            local item = self.items[tonumber(args[2])]
            item.id = args[3]
            item.data = nil
            goto continue
        end

        if args[1] == "give_item" then
            for _, item in ipairs(self.items) do
                if item.id == nil then
                    item.id = args[2]
                    item.data = nil
                    break
                end
            end

            goto continue
        end

        if args[1] == "set_speed" then
            self.gameManager.speed = tonumber(args[2])--[[@as integer]]
            goto continue
        end

        if args[1] == "set_level" then
            self.gameManager.difficulty = tonumber(args[2])--[[@as integer]]
            goto continue
        end

        if args[1] == "set_lives" then
            self.lives = math.clamp(tonumber(args[2])--[[@as integer]], 0, 4)
            goto continue
        end

        warn("unknown command")
        ::continue::
    end

    love.window.minimize()
    love.window.restore()
end









--------------------------------------------------------------------------------
--- Item Database
--------------------------------------------------------------------------------

-- reroll --
function itemUseProcedures.reroll(item, state)
    ---@type microgame.Runner
    local runner = state.runner

    state.gameName = GAME_SET[math.random(1, #GAME_SET)]
    runner:_loadMicrogame(state.gameName)
    runner.gameManager.tickSpeed = runner.gameManager.tickSpeed * 1.5
    state.verbTextTimer = 1.0
end

-- moreTime --
function itemUseProcedures.moreTime(item, state)
    ---@type microgame.Runner
    local runner = state.runner
    local gameMgr = runner.gameManager
    gameMgr.timer = math.min(gameMgr.gameLength, gameMgr.timer + 2)

    if gameMgr.game.onTimerIncrease then
        gameMgr.game:onTimerIncrease()
    end
end

-- slow --
function itemUseProcedures.slow(item, state)
    ---@type microgame.Runner
    local runner = state.runner
    local gameMgr = runner.gameManager
    gameMgr.tickSpeed = gameMgr.tickSpeed * 0.5
end

-- shield --
function itemUseProcedures.shield(item, state)
    ---@type microgame.Runner
    local runner = state.runner
    local gameMgr = runner.gameManager

    runner.lifeShields = runner.lifeShields + 1
    gameMgr.tickSpeed = runner:getTickSpeed()
end

-- save1 --
function itemUseProcedures.save1(item, state)
    item.id = "save2"
    item.data = state.gameName

    return true
end

-- save2 --
function itemUseProcedures.save2(item, state)
    ---@type microgame.Runner
    local runner = state.runner
    runner.forceGame = item.data
end










--------------------------------------------------------------------------------
--- STATE: gameIntermission
--------------------------------------------------------------------------------
runStates.gameIntermission = require("microgame.runner.game_intermission")


--------------------------------------------------------------------------------
--- STATE: play
--------------------------------------------------------------------------------
local PLAY_STATE_PERMITTED_ITEMS = {
    "reroll", "moreTime", "slow", "shield", "save1", "save2",
}

---@class microgame.Runner.PlayState: microgame.Runner.State
local PlayState = batteries.class {
    name = "microgame.Runner.PlayState"
}
runStates.play = PlayState

---@param runner microgame.Runner
function PlayState:new(runner)
    self.permittedItems = PLAY_STATE_PERMITTED_ITEMS
    self.runner = runner
    runner.canUseItems = true
    self.verbTextTimer = 1.0

    if runner.forceGame then
        self.gameName = runner.forceGame
        runner.forceGame = nil
    else
        self.gameName = runner:_getNextMicrogame()
    end

    runner.res.bombFuseFlameSpr:play("fuse")
    runner:_loadMicrogame(self.gameName)
    runner.gameManager.tickSpeed = runner:getTickSpeed()
end

---@param dt number
function PlayState:rawUpdate(dt)
    
end

function PlayState:exit()
    local runner = self.runner
    runner.gamesCompleted = runner.gamesCompleted + 1
    runner.gameManager.tickSpeed = 1.0
    
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
    
    if runner.gameManager.timer == 0 then
        runner:_nextRound()

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
    local gameMgr = runner.gameManager

    -- draw game
    runner.gameManager:draw()

    -- draw verb text
    if self.verbTextTimer > 0.0 then
        local textW, textH = runner.verbText:getDimensions()
        local drawX = (GameConf.scrW - textW) / 2
        local drawY = (GameConf.scrH - textH) / 2

        Lg.setColor(0, 0, 0, 0.5)
        Lg.draw(runner.verbText, drawX + 2, drawY + 2)

        Lg.setColor(1, 1, 1)
        Lg.draw(runner.verbText, drawX, drawY)
    end

    -- timer bar
    local bombDrawX = 3
    local bombSpr = runner.res.bombSpr --[[@as pklove.Sprite]]
    
    Lg.setColor(0, 0, 0, 0.5)
    bombSpr:drawCel(1, bombDrawX + 1, 157 + 1)
    Lg.setColor(1, 1, 1)

    bombSpr:drawCel(1, bombDrawX, 157)
    bombDrawX = bombDrawX + 29
    if true then
        local progress = gameMgr.timer / gameMgr.gameLength
        local barWidth = ((GameConf.scrW - 8) - bombDrawX) * progress

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