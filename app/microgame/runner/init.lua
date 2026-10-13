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

local BOSS_ROUND_INTERVAL = 20
local MAX_LIVES = 4
local UI_ITEM_SLOT_POSITIONS = {
    { x = 218, y = 13 },
    { x = 218, y = 38 },
    { x = 218, y = 63 },
}
local UI_ITEM_SLOT_WIDTH = 18
local UI_ITEM_SLOT_HEIGHT = 12

local SPEED_UP_POINTS = {
    -- level 1
    { 8, 14 },
    -- level 2
    { 6, 12 },
    -- level 3
    { 4, 8 }
}
local SHOP_POINTS = {
    -- level 1
    { 1, 14 },
    -- level 2
    { 1, 6, 12 },
    -- level 3
    { 1, 10 }
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
    self.res.lifeSpr = Sprite.new("/res/sprites/hearts.json")
    self.res.lifeSpr.alignment = "topleft"

    self.res.bombSpr = Sprite.new("/res/sprites/bomb_timer.json")
    self.res.bombSpr.alignment = "topleft"

    self.res.bombFuseRopeImg = Lg.newImage("/res/sprites/bomb_timer_rope.png")
    self.res.bombFuseRopeImg:setWrap("repeat", "repeat")
    
    self.res.bombFuseFlameSpr = Sprite.new("/res/sprites/bomb_timer_fuse.json")
    self.res.shellImg = Lg.newImage("res/sprites/arcade_bars.png")
    self.res.bombFuseRopeQuad = Lg.newQuad(0,0, 0,0, 1,1)

    self.res.itemsSpr = Sprite.new("/res/sprites/items.json")
    self.res.itemsSpr.alignment = "center"

    self.res.imgBgBlackGradient = Lg.newImage("/res/img/bg_black_gradient.png")
    
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

function Runner:release()
    for _, res in pairs(self.res) do
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

    Lg.setColor(1, 1, 1)
    Lg.draw(self.res.shellImg, 0, 0)
    
    -- draw lives counter
    for i=1, 4 do
        local x = 1
        local y = 10 + (i-1) * 25
        local c = 1
        if i <= self.lives then
            c = 2
            if i > self.lives - self.lifeShields then
                c = 3
            end
        end

        Lg.setColor(1, 1, 1)
        self.res.lifeSpr:drawCel(c, x, y)
    end

    -- draw items
    local itemsSpr = self.res.itemsSpr --[[@as pklove.Sprite]]
    local drawOx = UI_ITEM_SLOT_WIDTH / 2
    local drawOy = UI_ITEM_SLOT_HEIGHT / 2
    for i=1, #self.items do
        local item = self.items[i]
        local drawPos = UI_ITEM_SLOT_POSITIONS[i]

        local imgName = item.id or "nil"
        Lg.setColor(1, 1, 1)
        itemsSpr:play(imgName)
        itemsSpr:draw(math.round(drawPos.x + drawOx), math.round(drawPos.y + drawOy))
    end

    -- draw bomb
    -- Lg.setScissor(0, 0, self.scrX, App.scrH)
    -- Lg.setColor(1, 1, 1)
    -- self.res.bombSpr:drawCel(1, 2, 153)
    -- self.res.bombSpr:drawCel(2, 2, 153)
    -- Lg.setScissor()
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
---@param ... any
local function nextRoundCallback(self, ...)
    self.canUseItems = false
    self.round = self.round + 1

    -- ouch
    if self.lostGame then
        if self.lifeShields > 0 then
            self.lifeShields = self.lifeShields - 1
        else
            self.lives = self.lives - 1
        end

        -- restart game when out of lives
        if self.lives == 0 and not Debug.enabled then
            Sceneman.switchScene("game_runner", {})
        end
    end

    local gameMgr = self.gameManager
    local levelData = SHOP_POINTS[gameMgr.difficulty + 1]
    print("level", gameMgr.difficulty)
    local enterShop = table.index_of(levelData, self.round) ~= nil

    if enterShop then
        return runStates.itemSelect(self, ...)
    else
        return runStates.enterGame(self, ...)
    end
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
    
    self.bossRound = runner.round % BOSS_ROUND_INTERVAL == 0

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
    if true then
        local progress = gameMgr.timer / gameMgr.gameLength
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
--- STATE: itemSelect
--------------------------------------------------------------------------------
local ITEM_SET = {
    "reroll",
    "moreTime",
    "slow",
    "shield",
    "save1"
    -- "save2"
}

local ITEM_DESCS = {
    reroll = {
        name = "Dice",
        desc = "Reroll your destiny."
    },
    moreTime = {
        name = "Watch",
        desc = "If only we could have more time."
    },
    slow = {
        name = "Timeglass",
        desc = "The world around you seems to move at a slower pace."
    },
    shield = {
        name = "Life Shield",
        desc = "Safety, but at what cost?"
    },
    save1 = {
        name = "Disk",
        desc = "Your devices remember more than you do."
    }
}

local Color = batteries.colour
local ITEM_SQUARE_WIDTH = 40
local ITEM_SQUARE_HEIGHT = 40
local CONFIRM_LENGTH = 60
local CONFIRM_MIN = 10

---@class microgame.Runner.ItemSelectState: microgame.Runner.State
local ItemSelectState = batteries.class {
    name = "microgame.Runner.ItemSelectState"
}
runStates.itemSelect = ItemSelectState

---@param runner microgame.Runner
function ItemSelectState:new(runner)
    self.runner = runner

    -- determine if it should first ask the user to discard an item, because
    -- their inventory is full
    self.removeItem = true
    for i=1, 3 do
        if not runner.items[i].id then
            self.removeItem = false
            break        
        end
    end

    local itemSet = table.shuffle(table.shallow_copy(ITEM_SET))

    self.items = {}
    for i=1, 2 do
        self.items[i] = {
            id = itemSet[i],
            x = GameConf.scrW / 2 + (i-1) * (ITEM_SQUARE_WIDTH + 10),
            y = 0,

            ticks = self.removeItem and 0 or 120,

            bgColor = 0x1d1d1d,
            strokeColor = 0xff0000,
            itemColor = 0xffffff
        }
    end

    self.selectedItem = 1

    -- center items
    local avgX = 0
    for _, item in pairs(self.items) do
        avgX = avgX + item.x
    end
    avgX = avgX / #self.items

    for _, item in pairs(self.items) do
        item.x = item.x - avgX + GameConf.scrW / 2
    end

    self.tickCnt = 0

    self.pressedBtn = false
    self.releasedBtn = false
    self.heldBtn = false

    self.confirmTimer = 0
    self.itemNameText = Lg.newText(FontRes.monogram)
    self.itemNameDesc = Lg.newText(FontRes.monogram)

    self.res = {}
    self.res.beetleSpr = Sprite.new("/res/sprites/firebeetle/firebeetle_shop.json")
    self.res.beetleSpr:play("think")

    self:_updateText()
end

function ItemSelectState:exit()
    for _, res in pairs(self.res) do
        if res.typeOf and res:typeOf("Source") and res.stop then
            res:stop()
        end

        if res.release then
            res:release()
        end
    end
end

function ItemSelectState:rawUpdate(dt)
    local device = Input.players[1]
    self.pressedBtn = device:pressed("gameButton")
    self.releasedBtn = device:released("gameButton")
    self.heldBtn = device:down("gameButton")
end

function ItemSelectState:auxButtonPressed(idx)
    local runner = self.runner
    if self.removeItem then
        runner.items[idx].id = nil
        runner.items[idx].data = nil

        self.removeItem = false
    end
end

function ItemSelectState:tick()
    local runner = self.runner
    local pressedBtn = self.pressedBtn
    local releasedBtn = self.releasedBtn
    local heldBtn = self.heldBtn

    self.res.beetleSpr:update(App.tickLength)

    self.pressedBtn = false
    self.releasedBtn = false

    if heldBtn then
        self.confirmTimer = self.confirmTimer + 1
    end

    if releasedBtn then
        if not self.removeItem and self.confirmTimer < CONFIRM_MIN then
            self.selectedItem = self.selectedItem + 1
            if self.selectedItem > #self.items then
                self.selectedItem = 1
            end
            self:_updateText()
        end

        self.confirmTimer = 0
    end

    for i, item in pairs(self.items) do
        local hue = (self.tickCnt + i * 13) / 40
        local val = 1.0

        if i == self.selectedItem and not self.removeItem then
            item.bgColor = 0x1d1d1d
            item.itemColor = 0xffffff
        else
            val = 0.5
            item.bgColor = 0x000000
            item.itemColor = 0x7f7f7f
        end

        if not self.removeItem then
            item.ticks = item.ticks + 1
        end

        local animTick = math.max(0, item.ticks - (i-1) * 12)

        local r, g, b = Color.hsv_to_rgb(hue, 0.5, val)
        item.strokeColor = Color.pack_rgb(r, g, b)
        item.y = math.sin(animTick / 60 * math.pi*2) * 4
        -- item.bgColor = 0x000000
    end

    if self.confirmTimer == CONFIRM_LENGTH then
        if not self.removeItem then
            for _, item in ipairs(runner.items) do
                if item.id == nil then
                    item.id = self.items[self.selectedItem].id
                    item.data = nil
                    break
                end
            end
        end

        runner:_switchState("enterGame")    
    end

    self.tickCnt = self.tickCnt + 1
end

function ItemSelectState:draw()
    local runner = self.runner
    local scrX, scrY = runner.scrX, runner.scrY
    local cx = GameConf.scrW / 2
    local cy = GameConf.scrH / 2
    local uiBase = cy + 12

    Lg.push()
    Lg.translate(scrX, scrY)
    Lg.setFont(FontRes.monogram)

    Lg.setColor(1, 1, 1)
    Lg.draw(runner.res.imgBgBlackGradient, 0, 0)
    -- Lg.setColor(0, 0, 0)
    -- Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)

    if self.removeItem then
        self:_itemDiscardDraw()
    end

    Lg.push()
    Lg.translate(0, uiBase)
    for _, item in pairs(self.items) do
        self:_drawItem(item)
    end
    Lg.pop()

    self:_drawConfirmTimer(uiBase + 30)

    -- draw item description
    if self.removeItem then
        local text =
[[Your inventory is full!
Use an item to discard it.
Hold the button to skip.]]

        -- fix text being fucked up idk
        Lg.setColor(0, 0, 0)
        Lg.printf(text, 1, uiBase + 35, GameConf.scrW, "center")
        Lg.setColor(1, 1, 1)
        Lg.printf(text, 0, uiBase + 34, GameConf.scrW, "center")

    else
        Lg.setColor(0, 0, 0)
        Lg.draw(self.itemNameText, 1, uiBase + 35)
        Lg.setColor(1, 1, 1)
        Lg.draw(self.itemNameText, 0, uiBase + 34)

        local drawX = math.round(cx - 160/2)
        local drawY = math.round(uiBase + 44)
        Lg.setColor(0, 0, 0)
        Lg.draw(self.itemNameDesc, drawX+1, drawY+1)
        Lg.setColor(0.5, 0.5, 0.5)
        Lg.draw(self.itemNameDesc, drawX, drawY)
    end

    -- draw beetle thing
    local counterY = 64

    do
        local sx, sy, sw, sh = Lg.getScissor()
        Lg.intersectScissor(scrX, scrY, GameConf.scrW, counterY)
        Lg.setColor(1, 1, 1)
        self.res.beetleSpr:draw(cx, 40)
        Lg.setScissor(sx, sy, sw, sh)

        Lg.setColor(1, 0, 0)
        Lg.rectangle("fill", 0, counterY, GameConf.scrW, 2)
    end

    Lg.pop()
end

function ItemSelectState:_itemDiscardDraw()
    local cy = GameConf.scrH / 2

    Lg.setColor(1, 1, 1)
    Lg.printf("Your inventory is full!\nUse an item to discard it.\nHold the button to skip.", 0, cy + 34, GameConf.scrW, "center")
end

function ItemSelectState:_drawConfirmTimer(y)
    -- draw confirm timer
    if self.confirmTimer > 10 then
        local x = math.round(GameConf.scrW / 2)
        local y = math.round(y)
        local t = (self.confirmTimer - CONFIRM_MIN) / (CONFIRM_LENGTH - CONFIRM_MIN)
        local w = math.round(t * 100)
        local r,g,b = Color.hsv_to_rgb(t, 1, 1)
        Lg.setColor(r, g, b)
        self:_centerRect("fill", x, y, w, 8)
    end
end

function ItemSelectState:_updateText()
    local item = ITEM_DESCS[self.items[self.selectedItem].id]
    self.itemNameText:setf(item.name, GameConf.scrW, "center")

    self.itemNameDesc:clear()
    self.itemNameDesc:setf(item.desc, 160, "center")
end

function ItemSelectState:_drawItem(item)
    local itemsSpr = self.runner.res.itemsSpr--[[@as pklove.Sprite]]
    local itemX = math.round(item.x)
    local itemY = math.round(item.y)

    Lg.setColor(Color.unpack_rgb(item.bgColor))
    self:_centerRect("fill", itemX, itemY, ITEM_SQUARE_WIDTH, ITEM_SQUARE_HEIGHT)

    Lg.setColor(Color.unpack_rgb(item.strokeColor))
    Lg.setLineWidth(2)
    self:_centerRect("line", itemX, itemY, ITEM_SQUARE_WIDTH, ITEM_SQUARE_HEIGHT)

    itemsSpr:play(item.id)
    Lg.setColor(Color.unpack_rgb(item.itemColor))
    itemsSpr:draw(itemX, itemY, 0, 2, 2)
end

---@param mode "fill"|"line"
---@param x number
---@param y number
---@param w number
---@param h number
function ItemSelectState:_centerRect(mode, x, y, w, h)
    Lg.rectangle(mode, x - w/2, y - h/2, w, h)
end

---@param text love.Text
---@param x number
---@param y number
---@param sx number?
---@param sy number?
function ItemSelectState:_centerText(text, x, y, sx, sy)
    x = math.round(x - text:getWidth() / 2)
    y = math.round(y)
    Lg.draw(text, x, y, 0, sx or 1, sy or 1)
end

--------------------------------------------------------------------------------
return Runner