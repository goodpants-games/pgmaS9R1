-- TODO: title screen
--[[
- funny strobing lights, ala Evil Egg
--]]

local fontres = require("fontres")
local Userdata = require("userdata")
local Input = require("input")
local Sprite = require("sprite")

local scene = Sceneman.scene()
local self

local MARQUEE_TEXT = "        THE OBJECT OF THIS GAME IS TO SUCCESSFULLY COMPLETE AS MANY \"MICROGAMES\" AS YOU CAN BEFORE RUNNING OUT OF LIVES. THESE ARE VARIOUS BRIEF MINIGAMES WHICH ARE CONTROLLED VIA THE SPACE KEY. YOU MAY ALSO PICK UP ITEMS AS YOU PROGRESS, WHICH YOU ACTIVATE IN-GAME WITH THE A, S, OR D KEYS. CAN YOU REACH #1 ON THE LEADERBOARDS...? PRESENTED BY TEAM FIREBEETLE: PKHEAD, CZ43, AND EXOTICCHEESE."
local TITLE_LETTER_ADVANCE = 12
local TITLE_LETTER_COUNT = 8
local TITLE_LETTER_OX = 42
local TITLE_LETTER_OY = 20

local HUE_SHIFT_SHADER_SRC = [[
uniform float u_hue;
uniform float u_sat;

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 smp = Texel(tex, texture_coords);
    vec3 hsv = rgb2hsv(smp.rgb);
    hsv = vec3(hsv.r + u_hue, hsv.g * u_sat, hsv.b);
    return vec4(hsv2rgb(hsv), smp.a) * color;
}
]]

function scene.load(data)
    print("load title")
    self = {}
    Lg.setBackgroundColor(0, 0, 0)

    self.coin_inserted = false
    self.started = false
    self.released_space = true

    self.start_prompt_txt = "INSERT COIN"
    self.start_prompt = Lg.newText(fontres.bold, self.start_prompt_txt)
    self.start_prompt_wrap_limit = 100

    self.info_txt = Lg.newText(fontres.quinque, MARQUEE_TEXT)
    self.info_txt_x = 0
    self.info_txt_w = self.info_txt:getWidth()

    self.controls_prompt_txt = "CONTROLS: Space,A,S,D"
    self.controls_prompt = Lg.newText(fontres.quinque, self.start_prompt_txt)
    self.controls_prompt_wrap_limit = 180
    self.img_title = Lg.newImage("res/sprites/title.png")
    self.title_letters_spr = Sprite.new("/res/sprites/title_letters.json")
    self.title_letters_spr.alignment = "topleft"
    self.title_letters2_spr = Sprite.new("/res/sprites/title_letters2.json")
    self.title_letters2_spr.alignment = "topleft"

    self.hue_shift_shader = Lg.newShader(HUE_SHIFT_SHADER_SRC)

    self.leaderboard_wrap_limit = 100
    self.leaderboard_texts = {}
    for i=1, Userdata.scoreboardCount do
        local entry = Userdata.scoreboard[i]
        self.leaderboard_texts[i] = ("%2d...%02d %s"):format(
            i, entry.score, entry.name
        )
    end

    for i, text in ipairs(self.leaderboard_texts) do
        local txt_obj = Lg.newText(fontres.quinque, text)
        txt_obj:setf(text, self.leaderboard_wrap_limit, "left")
        table.remove(self.leaderboard_texts, i)
        table.insert(self.leaderboard_texts, i, txt_obj)
    end

    self.coin_insert_audio = love.audio.newSource("res/titlescreen/insert coin.wav", "static")
    self.switch_audio = love.audio.newSource("res/titlescreen/switch.wav", "static")
    self.played_switch_audio = false

    self.tick = 0

    self.fade_transparency = 0
end

function scene.unload()
    self.start_prompt:release()
    self.controls_prompt:release()
    self.coin_insert_audio:release()
    self.switch_audio:release()
    self.img_title:release()
    self.info_txt:release()
    self.title_letters_spr:release()
    self.title_letters2_spr:release()
    self.hue_shift_shader:release()
    self = nil
end

function scene.update(dt)
    self.start_prompt:setf(self.start_prompt_txt, self.start_prompt_wrap_limit, "center")
    self.controls_prompt:setf(self.controls_prompt_txt, self.controls_prompt_wrap_limit, "center")

    if self.released_space and Input.players[1]:released("gameButton") then
        self.released_space = false

        if self.coin_inserted and not self.started then
            self.started = true
        elseif not self.coin_inserted then
            self.coin_inserted = true
            self.coin_insert_audio:play()
        end
    elseif not Input.players[1]:down("gameButton") then
        self.released_space = true
    end

    if not self.coin_insert_audio:isPlaying() and self.coin_inserted then
        if not self.played_switch_audio then
            self.played_switch_audio = true
            self.switch_audio:play()
        end
        self.start_prompt_txt = "PRESS TO START!"
    end

    if self.started then
        self.fade_transparency = self.fade_transparency + (3 * dt)
    end

    if self.fade_transparency > 0 then
        Sceneman.switchScene("game_runner")
    end

    self.tick = self.tick + 1
    self.info_txt_x = (self.info_txt_x + 0.75) % self.info_txt_w
end

function scene.draw()
    local hsvToRgb = batteries.colour.hsv_to_rgb

    -- draw game title
    Lg.setColor(1, 1, 1)
    for i=8, 0, -1 do
        local phase = 1/100
        local spr
        if i == 0 then
            spr = self.title_letters_spr
            Lg.setColor(1, 1, 1)
        else
            spr = self.title_letters2_spr
            local r,g,b = hsvToRgb((i/8) + self.tick/60, 0.5, 1-(i/10))
            Lg.setColor(r, g, b)
        end
        
        for j=1, TITLE_LETTER_COUNT do
            local baseDrawX = (j-1) * TITLE_LETTER_ADVANCE + TITLE_LETTER_OX + (i-1)
            local baseDrawY = TITLE_LETTER_OY - (i-1) * 2

            local n = j + i/2
            local drawX = baseDrawX
                + math.cos((self.tick * phase / 2 + n/10) * (math.pi*2)) * 3
            local drawY = baseDrawY
                + math.sin((self.tick * phase + n/10) * (math.pi*2)) * 3

            if j > 4 then
                Lg.setShader(self.hue_shift_shader)

                local shf = self.tick / 120 + j / 10
                self.hue_shift_shader:send("u_hue", shf % 1.0)
                self.hue_shift_shader:send("u_sat", 0.7)
            else
                Lg.setShader()
            end
            spr:drawCel(j, math.round(drawX), math.round(drawY))
        end
    end
    Lg.setShader()

    -- Lg.draw(self.img_title, math.round((Display.scrW - self.img_title:getWidth()) / 2), 20)

    -- Bottom Text
    do
        local textX = Display.scrW/2 - self.start_prompt_wrap_limit/2
        local textY = Display.scrH - 35

        if self.tick % 30 < 15 then
            Lg.setColor(0, 0, 0.7)
            Lg.draw(self.start_prompt, textX+1, textY+1)
            Lg.setColor(1, 1, 1)
            Lg.draw(self.start_prompt, textX, textY)
        end
    end

    -- marquee info text
    do
        Lg.draw(self.info_txt, math.round(-self.info_txt_x), Display.scrH - 17)
        Lg.draw(self.info_txt, math.round(-self.info_txt_x + self.info_txt_w), Display.scrH - 17)
    end

    Lg.draw(self.controls_prompt, Display.scrW/2 - self.controls_prompt_wrap_limit/2, Display.scrH - 25)
    
    -- scoreboard
    local textW = fontres.quinque:getWidth("00...00 XXXXX")
    for i, text in ipairs(self.leaderboard_texts) do
        local wave = math.sin((self.tick/40 + i*0.7) * (math.pi/2))
        local textX = math.round(Display.scrW/2 - textW/2 + wave * 3)
        local textY = math.round(Display.scrH/4 + 8*i)
        local h = self.tick / 20 + i / 9

        Lg.setColor(hsvToRgb(h%1, 0.7, 0.5))
        -- Lg.setColor(0, 0, 0.5)
        Lg.draw(text, textX+1, textY+1)

        if Userdata.scoreboard[i].isUser then
            local s = (math.sin((self.tick/30) * (math.pi*2))+1)/2
            local r,g,b = hsvToRgb(60/365, 0.0, s)
            Lg.setColor(r, g, b)
        else
            Lg.setColor(1, 1, 1)
        end

        Lg.draw(text, textX, textY)
    end

    Lg.setColor(0, 0, 0, math.floor(self.fade_transparency*3)/3)
    Lg.rectangle("fill", 0, 0, Display.scrW, Display.scrH)
end

return scene