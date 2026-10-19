local GameConf = require("microgame.conf")
local FontRes = require("fontres")
local Sprite = require("sprite")
local Input = require("input")

---@class microgame.Runner.Shop: batteries.Class
---@overload fun(runner:microgame.Runner):microgame.Runner.Shop
local Shop = batteries.class {
    name = "microgame.Runner.Shop"
}

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

---@param runner microgame.Runner
function Shop:new(runner)
    self.runner = runner
    self.done = false

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

    self.res.music = love.audio.newSource("/res/music/shop.ogg", "stream")
    self.res.music:setLooping(true)
    self.res.music:setVolume(0.6)

    self.res.select =
        love.audio.newSource("/res/sounds/name_entry/move.wav", "static")
    self.res.hold =
        love.audio.newSource("/res/sounds/shop_confirm_hold.wav", "static")
    self.res.hold:setVolume(0.5)
    self.res.discard =
        love.audio.newSource("/res/sounds/name_entry/select.wav", "static")

    self:_updateText()
end

function Shop:exit()
    for _, res in pairs(self.res) do
        if res.typeOf and res:typeOf("Source") and res.stop then
            res:stop()
        end

        if res.release then
            res:release()
        end
    end
end

function Shop:rawUpdate(dt)
    local device = Input.players[1]
    self.pressedBtn = device:pressed("gameButton")
    self.releasedBtn = device:released("gameButton")
    self.heldBtn = device:down("gameButton")
end

function Shop:auxButtonPressed(idx)
    local runner = self.runner
    if self.removeItem then
        runner.items[idx].id = nil
        runner.items[idx].data = nil

        self.removeItem = false
        self.res.discard:play()
        self:_updateText()
    end
end

function Shop:tick()
    local runner = self.runner
    local pressedBtn = self.pressedBtn
    local releasedBtn = self.releasedBtn
    local heldBtn = self.heldBtn

    self.res.beetleSpr:update(App.tickLength)

    self.pressedBtn = false
    self.releasedBtn = false

    if heldBtn then
        self.confirmTimer = self.confirmTimer + 1

        if self.confirmTimer == CONFIRM_MIN then
            self.res.hold:setPitch(1.5)
            self.res.hold:play()
        end
    end

    if releasedBtn then
        self.res.hold:stop()

        if not self.removeItem and self.confirmTimer < CONFIRM_MIN then
            self.selectedItem = self.selectedItem + 1
            if self.selectedItem > #self.items then
                self.selectedItem = 1
            end
            self.res.select:stop()
            self.res.select:play()
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

        self.done = true
    end

    self.tickCnt = self.tickCnt + 1
end

function Shop:draw()
    local runner = self.runner
    local scrX, scrY = runner.scrX, runner.scrY
    local cx = GameConf.scrW / 2
    local cy = GameConf.scrH / 2
    local uiBase = cy + 12

    Lg.setFont(FontRes.monogram)

    Lg.setColor(1, 1, 1)
    Lg.draw(runner.res.imgBgBlackGradient, 0, 0)
    -- Lg.setColor(0, 0, 0)
    -- Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)

    Lg.push()
    Lg.translate(0, uiBase)
    for _, item in pairs(self.items) do
        self:_drawItem(item)
    end
    Lg.pop()

    self:_drawConfirmTimer(uiBase + 30)

    -- draw item description
    if self.removeItem then
        local drawX = math.round(cx - 160/2)
        local drawY = uiBase + 34

        Lg.setColor(0, 0, 0)
        Lg.draw(self.itemNameDesc, drawX+1, drawY+1)
        Lg.setColor(1, 1, 1)
        Lg.draw(self.itemNameDesc, drawX, drawY)

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
        Lg.setScissor(0, 0, GameConf.scrW, counterY)
        Lg.setColor(1, 1, 1)
        self.res.beetleSpr:draw(cx, 40)
        Lg.setScissor()

        Lg.setColor(1, 0, 0)
        Lg.rectangle("fill", 0, counterY, GameConf.scrW, 2)
    end
end

function Shop:_drawConfirmTimer(y)
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

function Shop:_updateText()
    local item = ITEM_DESCS[self.items[self.selectedItem].id]
    self.itemNameText:setf(item.name, GameConf.scrW, "center")

    self.itemNameDesc:clear()

    local text = item.desc
    if self.removeItem then
        text = [[Your inventory is full!
Use an item to discard it.
Hold the button to skip.]]
    end

    self.itemNameDesc:setf(text, 160, "center")
end

function Shop:_drawItem(item)
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
function Shop:_centerRect(mode, x, y, w, h)
    Lg.rectangle(mode, x - w/2, y - h/2, w, h)
end

---@param text love.Text
---@param x number
---@param y number
---@param sx number?
---@param sy number?
function Shop:_centerText(text, x, y, sx, sy)
    x = math.round(x - text:getWidth() / 2)
    y = math.round(y)
    Lg.draw(text, x, y, 0, sx or 1, sy or 1)
end

return Shop