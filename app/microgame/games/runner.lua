local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local Json = require("json")

local GRAVITY = 0.13
local FLOOR_Y = 48
local SPR_W = 8
local SPR_H = 8

P8_PAL = {
    { batteries.colour.unpack_rgb(0x000000) }, -- black
    { batteries.colour.unpack_rgb(0x1d2b53) }, -- dark_blue
    { batteries.colour.unpack_rgb(0x7e2553) }, -- dark_purple
    { batteries.colour.unpack_rgb(0x008751) }, -- dark_green
    { batteries.colour.unpack_rgb(0xab5236) }, -- brown
    { batteries.colour.unpack_rgb(0x5f574f) }, -- dark_gray
    { batteries.colour.unpack_rgb(0xc2c3c7) }, -- light_gray
    { batteries.colour.unpack_rgb(0xfff1e8) }, -- white
    { batteries.colour.unpack_rgb(0xff004d) }, -- red
    { batteries.colour.unpack_rgb(0xffa300) }, -- orange
    { batteries.colour.unpack_rgb(0xffec27) }, -- yellow
    { batteries.colour.unpack_rgb(0x00e436) }, -- green
    { batteries.colour.unpack_rgb(0x29adff) }, -- blue
    { batteries.colour.unpack_rgb(0x83769c) }, -- indigo
    { batteries.colour.unpack_rgb(0xff77a8) }, -- pink
    { batteries.colour.unpack_rgb(0xffccaa) }, -- peach
}

local P8_PAL_SHADER_SOURCE = [[
uniform Image u_palette;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    float pal_idx = (Texel(tex, texture_coords) * color).r;
    return Texel(u_palette, vec2(pal_idx, 0.5));
}
]]

---@class microgame._runner: microgame.Game
local Game = batteries.class {
    name = "microgame.runner",
    extends = GameBase
}

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Runner game"
    self.resRoot = "res/microgames/runner"

    self.backgroundColor = {batteries.colour.unpack_rgb(0x29adff)}

    -- create pico-8 palette image and shader
    self.p8Pal = love.image.newImageData(16, 1)
    self:_resetPal()
    
    self.p8PalTex = Lg.newImage(self.p8Pal)

    self:releaseOnUnload(self.p8Pal)
    self:releaseOnUnload(self.p8PalTex)

    self.palShader = Lg.newShader(P8_PAL_SHADER_SOURCE)
    self:releaseOnUnload(self.palShader)
    self.palShader:send("u_palette", self.p8PalTex)

    self.plrX = 0
    self.plrY = FLOOR_Y - SPR_H
    self.plrXv = 0
    self.plrYv = 0
    self.plrCharge = -1

    local sprresJelpi = self:_loadP8SpriteRes(self:getRes("jelpi"))

    self.sprJelpi = Sprite.new(sprresJelpi)
    self.sprJelpi.alignment = "topleft"
    self:releaseOnUnload(self.sprJelpi)

    self.res = {}
    for _, r in pairs(self.res) do
        self:releaseOnUnload(r)
    end

    self.curTick = 0
    self.tickAccum = 0
end

function Game:tick()
    self.plrYv = self.plrYv + GRAVITY
    self.plrX = self.plrX + self.plrXv
    self.plrY = self.plrY + self.plrYv

    local isOnFloor = false
    if self.plrY + SPR_H > FLOOR_Y then
        self.plrY = FLOOR_Y - SPR_H
        self.plrYv = 0
        isOnFloor = true
    end

    if isOnFloor then
        if self.manager:isButtonReleased() then
            if self.plrCharge > 20 then
                self.plrYv = -4
            else
                self.plrYv = -2
            end

            self.plrCharge = -1
        elseif self.manager:isButtonDown() then
            self.plrCharge = self.plrCharge + 1
        end
    end

    self.curTick = self.curTick + 1
end

function Game:draw()
    Lg.push()
    Lg.scale(2, 2)
    Lg.setShader(self.palShader)

    self:_resetPal()
    if self.plrCharge >= 0 then
        local dstColor = math.floor(self.plrCharge / 2) % 7 + 6
        self:_setPalIdx(2, dstColor)
        self:_setPalIdx(8, dstColor)
        self:_setPalIdx(14, dstColor)
        self:_setPalIdx(15, dstColor)
    end
    self:_flushPal()
    self.sprJelpi:draw(math.round(self.plrX * 2), math.round(self.plrY * 2))

    Lg.setShader()
    Lg.pop()
end

---@param img love.ImageData
local function convertToPalIndices(img)
    local imgW = img:getWidth()
    local imgH = img:getHeight()
    local setPixel = img.setPixel
    local getPixel = img.getPixel
    local packRgb = batteries.colour.pack_rgb

    local indexMap = {}
    for i, c in pairs(P8_PAL) do
        indexMap[packRgb(c[1], c[2], c[3])] = i - 1
    end

    for y=0, imgH - 1 do
        for x=0, imgW - 1 do
            local r, g, b, a = getPixel(img, x, y)
            if a == 0.0 then
                setPixel(img, x, y, 0, 0, 0, 1.0)
            else
                local hex = packRgb(r, g, b)
                local idx = indexMap[hex]
                if not idx then
                    error("could not map color...")
                end

                print((idx + 0.5) / 16)
                setPixel(img, x, y, (idx + 0.5) / 16, 0.0, 0.0, 1.0)
            end
        end
    end
end

---@param fileName string
---@return love.Image
function Game:_loadP8Image(fileName)
    local img = love.image.newImageData(fileName)
    convertToPalIndices(img)
    return Lg.newImage(img)
end

---@param resName string
---@return pklove.SpriteResource
function Game:_loadP8SpriteRes(resName)
    local data = Json.decode(love.filesystem.read("string", resName .. ".json"))
    local img = self:_loadP8Image(resName .. ".png")

    return Sprite.loadResourceFromMemory(data, img)
end

function Game:_resetPal()
    local imgData = self.p8Pal
    imgData:setPixel(0, 0, 0.0, 0.0, 0.0, 0.0)
    for i=1, 15 do
        local col = P8_PAL[i+1]
        local r, g, b = col[1], col[2], col[3]
        imgData:setPixel(i, 0, r, g, b, 1.0)
    end
end

function Game:_setPalIdx(srcIdx, dstIdx)
    local r, g, b, a = 0.0, 0.0, 0.0, 0.0
    if dstIdx > 0 then
        local col = P8_PAL[dstIdx + 1]
        r, g, b, a = col[1], col[2], col[3], 1.0
    end

    self.p8Pal:setPixel(srcIdx, 0, r, g, b, a)
end

function Game:_flushPal()
    self.p8PalTex:replacePixels(self.p8Pal)
end

function Game:_setDrawColor(idx)
    Lg.setColor((idx + 0.5) / 16, 0.0, 0.0, 1.0)
end

return Game