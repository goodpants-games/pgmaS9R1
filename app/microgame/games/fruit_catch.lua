local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")

local PLAYER_MOVE_SPEED = 100
local POSITION_GRID_COUNT = 5
local POSITION_GRID_SPACING = 30

---@class _fruit_catch: microgame.Game
local Game = batteries.class {
    name = "microgame.fruit_catch",
    extends = GameBase
}

Game.resRoot = "/res/microgames/fruit_catch"

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Catch!"
    self.backgroundColor = { 0.1, 0.4, 1.0 }
    mgr:setGameLength(GameConf.refGameLength - mgr.speed)

    -- difficulty 1: Adds 1 anvil (Loes when you catch it)
    -- difficilty 2: Adds Leafy vegetable, moves in wavy pattern and slowly
    --               (means another fruit will spawn while it's falling)
    --               (ensure it won't be impossible!)

    self.basketX = math.round(Display.scrW / 2)
    self.basketY = 135
    self.basketW = POSITION_GRID_SPACING
    self.basketH = 16
    self.playerGridPos = 0
    self.basketXv = 0.0

    self.fruits = {}
    self.nextFruitTicker = 15
    self.lastFruitSpawnX = self.playerGridPos
    self.nextFruitIndex = 1
    self.dangerFruitIndex = 0
    if mgr.difficulty > 0 then
        self.dangerFruitIndex = love.math.random(1, 4)
    end
    
    self.win = true
    self.playerFailed = false

    self.sprTeetoe = Sprite.new(self:getRes("teetoe.json"))
    self:releaseOnUnload(self.sprTeetoe)
    self.sprFruit = Sprite.new(self:getRes("fruit.json"))
    self:releaseOnUnload(self.sprFruit)

    self.music = self.manager:newAudioSource("/res/music/CLASS11.MOD", "stream")
    self:releaseOnUnload(self.music)
    self.music:play()
end

function Game:tick()
    -- basket controls
    if not self.playerFailed then
        if self.manager:isButtonPressed() then
            self.playerGridPos = (self.playerGridPos + 1) % POSITION_GRID_COUNT
        end

        local targetX = self:_gridToScreen(self.playerGridPos)

        local dx = targetX - self.basketX
        if dx < 0 then
            self.basketX = math.max(self.basketX - PLAYER_MOVE_SPEED, targetX)
        elseif dx > 0 then
            self.basketX = math.min(self.basketX + PLAYER_MOVE_SPEED, targetX)
        end
    end

    -- spawn next fruit...
    if self.nextFruitTicker == 0 then
        self.nextFruitTicker = 40
        self:_newFruit()
    else
        if not self.playerFailed then
            self.nextFruitTicker = self.nextFruitTicker - 1
        end
    end

    -- tick fruit
    for _, fruit in pairs(self.fruits) do
        fruit.y = fruit.y + fruit.yv
        -- fruit.yv = fruit.yv + 0.08

        local cx = fruit.x + fruit.w / 2
        local cy = fruit.y + fruit.h / 2
        if cy > self.basketY
           and cy < self.basketY + self.basketH
           and cx > self.basketX
           and cx < self.basketX + self.basketW
        then
            if fruit.isDanger or not self.playerFailed then
                fruit.markedForDeletetion = true

                if fruit.isDanger then
                    self.sprTeetoe.cel = 3
                    self.playerFailed = true
                    self.win = false
                end
            end
        end

        if fruit.y > App.scrH then
            fruit.markedForDeletetion = true

            if not self.playerFailed and not fruit.isDanger then
                self.win = false
                self.playerFailed = true
                self.sprTeetoe.cel = 2
            end
        end
    end

    -- remove fruit
    for i=#self.fruits, 1, -1 do
        if self.fruits[i].markedForDeletetion then
            table.remove(self.fruits, i)
        end
    end
end

function Game:draw()
    for _, fruit in pairs(self.fruits) do
        Lg.setColor(1, 1, 1)
        self.sprFruit:drawCel(fruit.sprite, fruit.x, fruit.y)
    end

    -- if not self.playerFailed then
    --     Lg.setColor(0, 0, 0)
    --     Lg.rectangle("fill", self.basketX - self.basketW / 2, self.basketY, self.basketW, self.basketH)
    -- end

    Lg.setColor(1, 1, 1)
    self.sprTeetoe:draw(self.basketX, self.basketY + self.basketH)
end

function Game:_newFruit()
    local isDanger = self.nextFruitIndex == self.dangerFruitIndex
    local maxDist = 4 - self.manager.speed
    local gridX = (self.lastFruitSpawnX + love.math.random(0, maxDist)) % POSITION_GRID_COUNT
    local yv = 2 + self.manager.speed
    if isDanger then
        yv = yv * 1.25
    end

    self.lastFruitSpawnX = gridX

    local obj = {
        x = self:_gridToScreen(gridX),
        y = isDanger and -30 or -20,
        w = 12,
        h = 12,
        yv = yv,
        sprite = isDanger and 4 or love.math.random(1, 3),
        isDanger = isDanger,
    }

    table.insert(self.fruits, obj)
    self.nextFruitIndex = self.nextFruitIndex + 1
    return obj
end

---@param gridPos integer
---@return number
function Game:_gridToScreen(gridPos)
    -- position grid count should be an odd number
    assert(POSITION_GRID_COUNT % 2 == 1)

    local pos
    if gridPos <= math.floor(POSITION_GRID_COUNT / 2) then
        pos = gridPos
    else
        pos = gridPos - POSITION_GRID_COUNT
    end

    return math.round(Display.scrW / 2 + pos * POSITION_GRID_SPACING)
end

return Game