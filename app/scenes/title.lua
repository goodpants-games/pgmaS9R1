-- TODO: title screen
--[[
- funny strobing lights, ala Evil Egg
--]]

local fontres = require("fontres")
local Userdata = require("userdata")
local Input = require("input")

local scene = Sceneman.scene()
local self

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

    self.controls_prompt_txt = "CONTROLS: Space,A,S,D"
    self.controls_prompt = Lg.newText(fontres.quinque, self.start_prompt_txt)
    self.controls_prompt_wrap_limit = 180
    self.img_title = Lg.newImage("res/sprites/title.png")

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
end

function scene.draw()
    -- draw game title
    Lg.setColor(1, 1, 1)
    Lg.draw(self.img_title, math.round((Display.scrW - self.img_title:getWidth()) / 2), 20)

    -- Bottom Text
    do
        local textX = Display.scrW/2 - self.start_prompt_wrap_limit/2
        local textY = Display.scrH - 35

        if self.tick % 30 < 15 then
            Lg.draw(self.start_prompt, textX, textY)
        end
    end

    Lg.draw(self.controls_prompt, Display.scrW/2 - self.controls_prompt_wrap_limit/2, Display.scrH - 15)
    
    -- scoreboard
    local hsvToRgb = batteries.colour.hsv_to_rgb
    local textW = fontres.quinque:getWidth("00...00 XXXXX")
    for i, text in ipairs(self.leaderboard_texts) do
        local wave = math.sin((self.tick/40 + i*0.7) * (math.pi/2))
        local textX = math.round(Display.scrW/2 - textW/2 + wave * 3)
        local textY = math.round(Display.scrH/4 + 8*i)
        local h = self.tick / 20 + i / 9

        Lg.setColor(hsvToRgb(h%1, 0.7, 0.5))
        -- Lg.setColor(0, 0, 0.5)
        Lg.draw(text, textX+1, textY+1)

        Lg.setColor(1, 1, 1)
        Lg.draw(text, textX, textY)
    end

    Lg.setColor(0, 0, 0, math.floor(self.fade_transparency*3)/3)
    Lg.rectangle("fill", 0, 0, Display.scrW, Display.scrH)
end

return scene