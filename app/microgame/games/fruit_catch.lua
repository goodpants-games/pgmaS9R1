local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")

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

    self.basketX = 0
    self.basketY = 140
    self.basketW = 40
    self.basketXv = 0.0

    self.fruits = {}
    self.nextFruitTicker = 40
    
    self.win = true

    self.sprTeetoe = Sprite.new("/res/microgames/fruit_catch/teetoe.json")
    self:releaseOnUnload(self.sprTeetoe)

    self.music = self.manager:newAudioSource("/res/music/CLASS11.mod", "stream")
    self:releaseOnUnload(self.music)
    self.music:play()
end

function Game:tick()
    -- basket controls
    if self.manager:isButtonDown() then
        self.basketXv = math.min(2.0, self.basketXv + 0.3)
    else
        self.basketXv = math.max(-2.0, self.basketXv - 0.3)
    end
    self.basketX = self.basketX + self.basketXv
    if self.basketX < 0 then
        self.basketX = 0
        self.basketXv = 0
    elseif self.basketX > GameConf.scrW - self.basketW then
        self.basketX = GameConf.scrW - self.basketW
        self.basketXv = 0
    end

    -- spawn next fruit...
    if self.nextFruitTicker == 0 then
        self.nextFruitTicker = 60

        table.insert(self.fruits, {
            x = love.math.random(20, GameConf.scrW - 20),
            y = -20,
            w = 12,
            h = 12,
        })
    else
        self.nextFruitTicker = self.nextFruitTicker - 1
    end

    -- tick fruit
    for _, fruit in pairs(self.fruits) do
        fruit.y = fruit.y + 2
    end
end

function Game:draw()
    for _, fruit in pairs(self.fruits) do
        Lg.setColor(1, 0, 0)
        Lg.rectangle("fill", fruit.x, fruit.y, fruit.w, fruit.h)
    end

    Lg.setColor(0, 0, 0)
    Lg.rectangle("fill", self.basketX, self.basketY, self.basketW, 20)

    Lg.setColor(1, 1, 1)
    self.sprTeetoe:draw(self.basketX + self.basketW / 2, self.basketY + 10.0)
end

return Game