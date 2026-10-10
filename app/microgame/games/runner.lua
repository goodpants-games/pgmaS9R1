local GameBase = require("microgame.base")
local GameConf = require("microgame.conf")
local Sprite = require("sprite")
local Json = require("json")

local GRAVITY = 0.18
local FLOOR_Y = 64
local SPR_W = 8
local SPR_H = 8

local ACTOR_INITS = {}

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

local function rectCollide(e1, e2)
    return e1.x + e1.w > e2.x
           and e1.y + e1.h > e2.y
           and e1.x < e2.x + e2.w
           and e1.y < e2.y + e2.h
end

---@param mgr microgame.Manager
function Game:new(mgr)
    self:super(mgr)
    self.verb = "Vault!"
    self.resRoot = "res/microgames/runner"

    self.backgroundColor = {batteries.colour.unpack_rgb(0x29adff)}

    -- create pico-8 palette image
    self.p8Pal = love.image.newImageData(16, 1)
    self._isPalModified = false
    self._isPalDirty = false
    self:_resetPal(true)
    self.p8PalTex = Lg.newImage(self.p8Pal)
    self._isPalDirty = false

    self:releaseOnUnload(self.p8Pal)
    self:releaseOnUnload(self.p8PalTex)

    -- create palette shader
    self.palShader = Lg.newShader(P8_PAL_SHADER_SOURCE)
    self:releaseOnUnload(self.palShader)
    self.palShader:send("u_palette", self.p8PalTex)

    -- load resources
    self.res = {}

    local oldResAlignment = Sprite.defaultResourceAlignment
    Sprite.defaultResourceAlignment = "topleft"

    self.res.sresJelpi = self:_loadP8SpriteRes(self:getRes("jelpi"))
    self.res.sresStrider = self:_loadP8SpriteRes(self:getRes("strider"))
    
    self.res.imgGround = Lg.newImage(self:getRes("ground.png"))
    self.res.imgMound = self:_loadP8Image(self:getRes("highground.png"))
    self.res.imgMound2 = self:_loadP8Image(self:getRes("highground2.png"))

    self.res.sndCharge1 = love.sound.newSoundData(self:getRes("charge1.wav"))
    self.res.sndCharge2 = love.sound.newSoundData(self:getRes("charge2.wav"))
    self.res.sndCharge = mgr:newQueueableAudioSource(48000, 16, 1, 2)

    for _, r in pairs(self.res) do
        self:releaseOnUnload(r)
    end
    Sprite.defaultResourceAlignment = oldResAlignment

    -- miscellaneous game state
    self.curTick = 0
    self.tickAccum = 0

    self.spawnWait = 65 - mgr.speed

    self.spawnTimer = 20 - mgr.speed * 5

    -- world data
    self.scrollX = 0
    self.entities = {}

    -- initialize entities
    self:_newEntity("player", 4, FLOOR_Y - SPR_H)
end

function Game:unload()
    for _, obj in pairs(self.entities) do
        if obj.sprite then
            obj.sprite:release()
        end
    end
    self.entities = nil

    self.__super.unload(self)
end

function Game:update()
    if self.res.sndCharge:isPlaying() and self.res.sndCharge:getFreeBufferCount() > 0 then
        self.res.sndCharge:queue(self.res.sndCharge2)
    end
end

function Game:tick()
    -- scroll map
    self.scrollX = self.scrollX + (1.2 * (1.0 + self.manager.speed * 0.1))

    -- spawn an obscatle
    if self.spawnTimer == 0 then
        self.spawnTimer = self.spawnWait

        print("spawn obstacle")

        local t = love.math.random(1, 2)
        local spawnX = self.scrollX + GameConf.scrW/2 
        if t == 1 then
            self:_newEntity("mound", spawnX, FLOOR_Y - 8, "imgMound")
            self:_newEntity("mound", spawnX, FLOOR_Y - 72, "imgMound2")
        else
            self:_newEntity("mound", spawnX, FLOOR_Y - 32, "imgMound")
        end
    else
        self.spawnTimer = self.spawnTimer - 1
    end

    -- tick entities
    for i, ent in pairs(self.entities) do
        if ent.tick then
            ent:tick(self)
        end

        if ent.x + ent.w < self.scrollX then
            ent._die = true
        end
    end

    -- remove entities
    for i=#self.entities, 1, -1 do
        if self.entities[i]._die then
            print("It was destroyed.")
            table.remove(self.entities, i)
        end
    end

    self:_entCollisions()

    -- epilogue
    self.curTick = self.curTick + 1
end

function Game:draw()
    Lg.push()
    Lg.scale(2, 2)
    
    -- draw ground
    do
        local w = self.res.imgGround:getPixelWidth()
        local sx = -math.round(self.scrollX % w)
        Lg.draw(self.res.imgGround, sx, FLOOR_Y)
        Lg.draw(self.res.imgGround, sx + w, FLOOR_Y)
    end

    -- draw entities
    Lg.setShader(self.palShader)
    for _, obj in pairs(self.entities) do
        local drawX = math.round(obj.x + obj.spriteX - self.scrollX)
        local drawY = math.round(obj.y + obj.spriteY)

        self:_resetPal()
        self:_flushPal()
        Lg.setColor(1, 1, 1)

        if obj.draw then
            obj:draw(self, drawX, drawY)
        elseif obj.sprite then
            if obj.sprite.draw then
                obj.sprite:draw(drawX, drawY)
            else
                Lg.draw(obj.sprite, drawX, drawY)
            end
        end
    end

    Lg.setShader()
    Lg.pop()
end

--------------------------------------------------------------------------------

function Game:_entCollisions()
    local plr = self.entities[1]

    -- X entities kinematics
    for _, ent in pairs(self.entities) do
        if ent.collision then
            ent.x = ent.x + ent.xv
        end
    end

    -- X axis actor collisions
    for _, ent in pairs(self.entities) do
        if plr == ent then
            goto continue
        end

        if rectCollide(plr, ent) then
            if plr.xv > 0 then
                plr.x = ent.x - plr.w
            else
                plr.x = ent.x + ent.w
            end
            plr.xv = 0
        end

        ::continue::
    end

    -- Y entities kinematics
    for _, ent in pairs(self.entities) do
        if ent.collision then
            ent.yv = ent.yv + GRAVITY * ent.gmult
            ent.y = ent.y + ent.yv
        end
    end

    -- floor collision
    plr.isOnFloor = false
    if plr.y + plr.h > FLOOR_Y then
        plr.y = FLOOR_Y - plr.h
        plr.yv = 0
        plr.isOnFloor = true
    end

    -- Y axis actor collisions
    for _, ent in pairs(self.entities) do
        if plr == ent then
            goto continue
        end

        if rectCollide(plr, ent) then
            if plr.yv > 0 then
                plr.y = ent.y - plr.h
            else
                plr.y = ent.y + ent.h
            end
            plr.yv = 0
        end

        ::continue::
    end
end

---@param entType string
---@param ... any
function Game:_newEntity(entType, ...)
    local obj = setmetatable({}, ACTOR_INITS[entType])

    self.x = 0
    self.y = 0
    self.xv = 0
    self.yv = 0
    self.w = 0
    self.h = 0
    self.gmult = 1.0

    obj:new(self, ...)
    table.insert(self.entities, obj)
    return obj
end

function Game:_removeEntity(ent)
    if ent.sprite then
        ent.sprite:release()
        ent.sprite = nil
    end

    table.remove_value(self.entities, ent)
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

    print(imgW * imgH)
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

---@param force boolean?
function Game:_resetPal(force)
    if not (self._isPalModified or force) then
        return
    end

    local imgData = self.p8Pal
    imgData:setPixel(0, 0, 0.0, 0.0, 0.0, 0.0)
    for i=1, 15 do
        local col = P8_PAL[i+1]
        local r, g, b = col[1], col[2], col[3]
        imgData:setPixel(i, 0, r, g, b, 1.0)
    end

    self._isPalDirty = true
    self._isPalModified = false
end

function Game:_setPalIdx(srcIdx, dstIdx)
    self._isPalModified = true
    self._isPalDirty = true

    local r, g, b, a = 0.0, 0.0, 0.0, 0.0
    if dstIdx > 0 then
        local col = P8_PAL[dstIdx + 1]
        r, g, b, a = col[1], col[2], col[3], 1.0
    end

    self.p8Pal:setPixel(srcIdx, 0, r, g, b, a)
end

function Game:_flushPal()
    if self._isPalDirty then
        self.p8PalTex:replacePixels(self.p8Pal)
    end
    self._isPalDirty = false
end

function Game:_setDrawColor(idx)
    Lg.setColor((idx + 0.5) / 16, 0.0, 0.0, 1.0)
end








--------------------------------------------------------------------------------
--- ENTITY: player
--------------------------------------------------------------------------------

local Player = {}
Player.__index = Player

---@param game microgame._runner
---@param x number
---@param y number
function Player:new(game, x, y)
    self.collision = true

    self.x = x + 1
    self.y = y + 1
    self.w = 6
    self.h = 7
    self.isOnFloor = false

    self.xv = 0
    self.yv = 0
    self.charge = -1
    self.isCharging = false
    self.isDoingChargeJump = false

    self.sprite = Sprite.new(game.res.sresJelpi)
    self.spriteX = -1
    self.spriteY = -1

    self.isStrobing = false
    self.strobeTick = 0
end

function Player:tick(game)
    -- self.sprite:update(App.tickLength)
    self.x = game.scrollX + 8

    self.gmult = 1.0
    if self.isDoingChargeJump and self.yv < 0 then
        self.gmult = 0.8
    end
    -- self.yv = self.yv + grav
    -- self.x = self.x + self.xv
    -- self.y = self.y + self.yv

    if self.isOnFloor then
        self.isDoingChargeJump = false

        if game.manager:isButtonPressed() then
            self.isCharging = true
        end
    end

    if self.isCharging then
        local stopCharge = false

        if self.charge >= 15 then
            self.yv = -3.8
            self.isDoingChargeJump = true
            stopCharge = true
        elseif self.charge >= 8 and not game.manager:isButtonDown() then
            self.yv = -3
            stopCharge = true
        else
            self.charge = self.charge + 1

            if not game.res.sndCharge:isPlaying() then
                game.res.sndCharge:queue(game.res.sndCharge1)
                game.res.sndCharge:queue(game.res.sndCharge2)
                game.res.sndCharge:play()
            end
        end

        if stopCharge then
            self.charge = -1
            game.res.sndCharge:stop()
            self.isCharging = false
        end

        self.isStrobing = true
    else
        self.isStrobing = self.isDoingChargeJump
    end

    if self.isStrobing then
        self.strobeTick = self.strobeTick + 1
    else
        self.strobeTick = 0
    end
end

---@param game any
---@param drawX number
---@param drawY number
function Player:draw(game, drawX, drawY)
    -- charge palette
    if self.isStrobing then
        local dstColor = math.floor(self.strobeTick / 2) % 7 + 6
        game:_setPalIdx(2, dstColor)
        game:_setPalIdx(8, dstColor)
        game:_setPalIdx(14, dstColor)
        game:_setPalIdx(15, dstColor)
        game:_flushPal()
    end

    self.sprite:draw(drawX, drawY)
end

ACTOR_INITS.player = Player

--------------------------------------------------------------------------------
--- ACTOR: STRIDER
--------------------------------------------------------------------------------

local Strider = {}
Strider.__index = Strider

---@param game microgame._runner
---@param x number
---@param y number
function Strider:new(game, x, y)
    self.doCollision = true

    self.x = x + 1
    self.y = y + 1
    self.w = 6
    self.h = 7

    self.sprite = Sprite.new(game.res.sresStrider)
    self.spriteX = -1
    self.spriteY = -1

    self.sprite:play("walk")
    self.jumpTick = 0
end

function Strider:tick(game)
    self.sprite:update(App.tickLength)

    self.yv = self.yv + GRAVITY
    self.y = self.y + self.yv
    if self.y + self.h > FLOOR_Y then
        self.y = FLOOR_Y - self.h
        self.yv = -1.7
    end

    -- if self.jumpTick == 0 then
    --     self.yv = -2
    -- end

    -- self.jumpTick = (self.jumpTick + 1) % 50
end

function Strider:draw(game, drawX, drawY)
    self.sprite:draw(drawX + 8, drawY, 0, -1, 1)
end

ACTOR_INITS.strider = Strider

--------------------------------------------------------------------------------
--- ACTOR: mound
--------------------------------------------------------------------------------

local Mound = {}
Mound.__index = Mound

---@param game microgame._runner
---@param x number
---@param y number
function Mound:new(game, x, y, resName)
    self.x = x
    self.y = y
    self.w = 16
    self.h = 40

    self.sprite = game.res[resName]
    self.spriteX = 0
    self.spriteY = 0
end

ACTOR_INITS.mound = Mound

--------------------------------------------------------------------------------

return Game