local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")

local MAX_PLAYER_SPEED = 3.0
local PLAYER_ACCEL = 0.2

---@class _fruit_catch: microgame.Game
local Game = batteries.class {
    name = "microgame.fruit_catch",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Catch!"
    self.backgroundColor = { 0.1, 0.4, 1.0 }

    -- difficulty 1: Adds 1 anvil (Loes when you catch it)
    -- difficilty 2: Adds Leafy vegetable, moves in wavy pattern and slowly
    --               (means another fruit will spawn while it's falling)
    --               (ensure it won't be impossible!)

    self.basketX = 0
    self.basketY = 135
    self.basketW = 40
    self.basketH = 16
    self.basketXv = 0.0

    self.fruits = {}
    self.nextFruitTicker = 40
    
    self.win = true
    self.teetoeDead = false

    self.sprTeetoe = Sprite.new("/res/microgames/fruit_catch/teetoe.json")
    self:releaseOnUnload(self.sprTeetoe)

    self.music = self.manager:newAudioSource("/res/music/CLASS11.MOD", "stream")
    self:releaseOnUnload(self.music)
    self.music:play()
end

function Game:tick()
    -- basket controls
    if self.teetoeDead then
        local origSgn = math.sign(self.basketXv)
        self.basketXv = self.basketXv - PLAYER_ACCEL * origSgn
        if math.sign(self.basketXv) ~= origSgn then
            self.basketXv = 0
        end
    else
        if self.manager:isButtonDown() then
            self.basketXv = math.min(MAX_PLAYER_SPEED, self.basketXv + PLAYER_ACCEL)
        else
            self.basketXv = math.max(-MAX_PLAYER_SPEED, self.basketXv - PLAYER_ACCEL)
        end
    end
    
    self.basketX = self.basketX + self.basketXv

    if not self.teetoeDead then
        if self.basketX < 0 then
            self.basketX = 0
            self.basketXv = 0
        elseif self.basketX > GameConf.scrW - self.basketW then
            self.basketX = GameConf.scrW - self.basketW
            self.basketXv = 0
        end
    end

    -- spawn next fruit...
    if self.nextFruitTicker == 0 then
        self.nextFruitTicker = 60

        table.insert(self.fruits, {
            x = love.math.random(20, GameConf.scrW - 20),
            y = -20,
            w = 12,
            h = 12,
            yv = 1
        })
    else
        if not self.teetoeDead then
            self.nextFruitTicker = self.nextFruitTicker - 1
        end
    end

    -- tick fruit
    for _, fruit in pairs(self.fruits) do
        fruit.y = fruit.y + fruit.yv
        fruit.yv = fruit.yv + 0.05

        local cx = fruit.x + fruit.w / 2
        local cy = fruit.y + fruit.h / 2
        if cy > self.basketY
           and cy < self.basketY + self.basketH
           and cx > self.basketX
           and cx < self.basketX + self.basketW
        then
            fruit.markedForDeletetion = true
        end

        if fruit.y > App.scrH then
            fruit.markedForDeletetion = true
            print("NOO MY FRUIT")
            self.win = false
            self.teetoeDead = true
            self.sprTeetoe.cel = 2
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
        Lg.setColor(1, 0, 0)
        Lg.rectangle("fill", fruit.x, fruit.y, fruit.w, fruit.h)
    end

    Lg.setColor(0, 0, 0)
    Lg.rectangle("fill", self.basketX, self.basketY, self.basketW, self.basketH)

    Lg.setColor(1, 1, 1)
    self.sprTeetoe:draw(self.basketX + self.basketW / 2, self.basketY + self.basketH)
end

return Game