local Sprite = require("sprite")

---Handles arcade shell rendering, and encapsulating all other rendering into
---its screen.
local Display = {}

local UI_ITEM_SLOT_POSITIONS = {
    { x = 218, y = 13 },
    { x = 218, y = 38 },
    { x = 218, y = 63 },
}
local UI_ITEM_SLOT_WIDTH = 18
local UI_ITEM_SLOT_HEIGHT = 12

---@alias Display.HeartLedMode
---| "off"
---| "red"
---| "blue"

Display.scrW = App.scrH
Display.scrH = App.scrH
Display.scrX = math.floor((App.scrW - Display.scrW) / 2)
Display.scrY = math.floor((App.scrH - Display.scrH) / 2)
---@type love.Canvas
Display.canvas = nil

---@type {[Display.HeartLedMode]:integer}
local HEART_LED_FRAME_NUMBERS = {
    ["off"]  = 1,
    ["red"]  = 2,
    ["blue"] = 3
}

---@type Display.HeartLedMode[]
Display.heartLeds = { "off", "off", "off", "off" }
Display.items = { "nil", "nil", "nil" }

-- resources
local res = {}

function Display.init()
    res.shellImg = Lg.newImage("res/sprites/arcade_bars.png")

    res.lifeSpr = Sprite.new("/res/sprites/hearts.json")
    res.lifeSpr.alignment = "topleft"

    res.itemsSpr = Sprite.new("/res/sprites/items.json")
    res.itemsSpr.alignment = "center"
end

---Tick the display. Should only be called from main.lua.
function Display.tick()

end

---Draw the display. Should only be called from main.lua.
function Display.draw()
    Lg.push("all")
    Lg.setScissor(Display.scrX, Display.scrY, Display.scrW, Display.scrH)
    Lg.translate(Display.scrX, Display.scrY)
    Sceneman.draw()
    Lg.pop()

    Lg.setColor(1, 1, 1)
    Lg.draw(res.shellImg, 0, 0)

    -- draw lives counter
    for i=1, 4 do
        local x = 1
        local y = 10 + (i-1) * 25

        local c = HEART_LED_FRAME_NUMBERS[Display.heartLeds[i]]
        Lg.setColor(1, 1, 1)
        res.lifeSpr:drawCel(c, x, y)
    end

    -- draw items
    local itemsSpr = res.itemsSpr --[[@as pklove.Sprite]]
    local drawOx = UI_ITEM_SLOT_WIDTH / 2
    local drawOy = UI_ITEM_SLOT_HEIGHT / 2
    for i=1, #Display.items do
        local item = Display.items[i]
        local drawPos = UI_ITEM_SLOT_POSITIONS[i]

        local imgName = item
        Lg.setColor(1, 1, 1)
        itemsSpr:play(imgName)
        itemsSpr:draw(math.round(drawPos.x + drawOx), math.round(drawPos.y + drawOy))
    end
end

return Display