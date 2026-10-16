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
    self.start_prompt = Lg.newText(fontres.monogram, self.start_prompt_txt)
    self.start_prompt_wrap_limit = 100

    self.controls_prompt_txt = "CONTROLS: Space, A, S, D"
    self.controls_prompt = Lg.newText(fontres.monogram, self.start_prompt_txt)
    self.controls_prompt_wrap_limit = 180

    self.leaderboard_wrap_limit = 100
    self.leaderboard_texts = {}
    for i=1, Userdata.scoreboardCount do
        local entry = Userdata.scoreboard[i]
        self.leaderboard_texts[i] = ("%02d - %s"):format(
            entry.score, entry.name
        )
    end

    for i, text in ipairs(self.leaderboard_texts) do
        local txt_obj = Lg.newText(fontres.quinque, text)
        txt_obj:setf(text, self.leaderboard_wrap_limit, "left")
        table.remove(self.leaderboard_texts, i)
        table.insert(self.leaderboard_texts, i, txt_obj)
    end

    self.strobe_colors = {

    }

    self.coin_insert_audio = love.audio.newSource("res/titlescreen/insert coin.wav", "static")
    self.switch_audio = love.audio.newSource("res/titlescreen/switch.wav", "static")
    self.played_switch_audio = false

    self.fade_transparency = 0
end

function scene.unload()
    self = nil
end

function scene.update(dt)
    
end

---@diagnostic disable-next-line
function scene.tick()
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
        self.fade_transparency = self.fade_transparency + (3 * App.tickLength)
    end

    if self.fade_transparency >= 1 then
        Sceneman.switchScene("game_runner")
    end
end

function scene.draw()
    Lg.draw(self.start_prompt, Display.scrW/2 - self.start_prompt_wrap_limit/2, Display.scrH - 30)
    Lg.draw(self.controls_prompt, Display.scrW/2 - self.controls_prompt_wrap_limit/2, Display.scrH - 45)

    for i, text in ipairs(self.leaderboard_texts) do
        Lg.draw(text, Display.scrW/2 - 30, Display.scrH/4 + 8*i)
    end

    Lg.setColor(0, 0, 0, math.floor(self.fade_transparency*3)/3)
    Lg.rectangle("fill", 0, 0, Display.scrW, Display.scrH)
end

return scene