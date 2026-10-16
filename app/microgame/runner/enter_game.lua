local GameConf = require("microgame.conf")
local FontRes = require("fontres")

---@class microgame.Runner.EnterGameState: microgame.Runner.State
local EnterGameState = batteries.class {
    name = "microgame.Runner.EnterGameState"
}

---@param runner microgame.Runner
function EnterGameState:new(runner, data)
    data = data or {}

    local speed = runner.gameManager.speed
    if data.gameOver then
        speed = 0
    end

    self.runner = runner
    self.time = 0
    self.state = 1
    self.stateTimer = 0
    self.displayLength = 60 - speed * 15
    self.effectAnimSpeed = 3 * (1 + speed * 0.25)
    self.strobeColorMask = { 1, 1, 1 }
    self.interpStrobeColorMask = { 1, 1, 1 }

    -- control parameters for the seizure pattern
    self.patternStart = 1
    self.patternEnd = 1

    self.bossRound = false
    self.speedUp = false
    self.gameOver = not not data.gameOver -- force coercion to bool
    local gameMgr = runner.gameManager
    
    if not self.gameOver then
        local levelData = GameConf.speedUpPoints[gameMgr.difficulty + 1]

        self.bossRound = runner.round % GameConf.bossRoundInterval == 0
        self.speedUp = table.index_of(levelData, runner.round) ~= nil
    end

    if self.speedUp then
        gameMgr.speed = gameMgr.speed + 1
    end

    if self.bossRound then
        gameMgr.speed = 0
        gameMgr.difficulty = math.min(gameMgr.difficulty + 1, 2)
        runner.round = 0

        if runner.lives < GameConf.maxLives then
            runner.lives = runner.lives + 1
        end
    end

    if runner.lostGame then
        self:_setStrobeColorMask(1, 0.2, 0.2, true)
    end
end

---@param r number
---@param g number
---@param b number
---@param now boolean?
function EnterGameState:_setStrobeColorMask(r, g, b, now)
    local mask = self.strobeColorMask
    mask[1], mask[2], mask[3] = r, g, b

    if now then
        local rmask = self.interpStrobeColorMask
        rmask[1], rmask[2], rmask[3] = mask[1], mask[2], mask[3]
    end
end

---@return number r, number g, number b
function EnterGameState:_getStrobeColorMask()
    local mask = self.interpStrobeColorMask
    return mask[1], mask[2], mask[3]
end

function EnterGameState:tick()
    local runner = self.runner

    -- interpolate strobe color mask
    do
        local dmask = self.strobeColorMask
        local rmask = self.interpStrobeColorMask

        for i=1, 3 do
            rmask[i] = math.lerp(rmask[i], dmask[i], 0.1)
        end
    end

    if self.state == 1 then
        local START_MAX = 105
        local END_MAX = 50

        if self.patternStart < START_MAX then
            self.patternStart = math.round(math.min(START_MAX, self.patternStart + self.effectAnimSpeed))
        elseif self.patternEnd < END_MAX then
            self.patternEnd = math.round(math.min(END_MAX, self.patternEnd + self.effectAnimSpeed))
        else
            self.state = 2
        end
    
    elseif self.state == 2 then
        self.stateTimer = self.stateTimer + 1
        local stages = 2
        if self.bossRound or self.speedUp then
            stages = 3
        end
        if self.gameOver then
            stages = 4
        end

        if self.stateTimer == self.displayLength * stages then
            self.state = 3
        end

        if self.stateTimer == self.displayLength then
            if self.speedUp then
                self:_setStrobeColorMask(1, 0.2, 1)    
            else
                self:_setStrobeColorMask(1, 1, 1)
            end
        end
    
    elseif self.state == 3 then
        if self.patternEnd > 1 then
            self.patternEnd = math.round(math.max(self.patternEnd - self.effectAnimSpeed, 1))
        elseif self.patternStart > 1 then
            self.patternStart = math.round(math.max(self.patternStart - self.effectAnimSpeed, 1))
        elseif self.gameOver then
            Sceneman.switchScene("game_end", runner.gamesCompleted)
        else
            self.runner:_switchState("play")
        end
    end

    self.time = self.time + 1
end

function EnterGameState:draw()
    local runner = self.runner
    Lg.clear(0, 0, 0)

    local cx = math.round(Display.scrW / 2)
    local cy = math.round(Display.scrH / 2)
    local hsvToRgb = batteries.colour.hsv_to_rgb
    local beetleFaceSpr = runner.res.beetleFaceSpr

    if self.patternEnd > 1 then
        -- beetle win/lose sprites
        if self.stateTimer < self.displayLength then
            Lg.setColor(1, 1, 1)
            local sprCel = 1
            if runner.lostGame then
                sprCel = 2
            end
            for i=0, 12 do
                local x = cx + i * 30 - (self.time%30) - 30
                local yBase = cy + math.sin((self.time/10 + i/6) * (math.pi/2)) * 6
                beetleFaceSpr:drawCel(sprCel, x, yBase)
                -- beetleFaceSpr:drawCel(sprCel, x, yBase + 34)
            end
        elseif self.gameOver then
            local oldFont = Lg.getFont()

            Lg.setFont(FontRes.bold)
            local textH = FontRes.bold:getHeight() * 2
            local textX = cx - 40*3/2 + 1
            local textY = cy - textH * 3/2

            local text = "GAME\nOVER!"

            Lg.setColor(0, 0, 0.7)
            Lg.printf(text, textX + 2, textY + 2, 40, "center", 0, 3, 3)
            
            Lg.setColor(0.8, 0, 0)
            Lg.printf(text, textX, textY, 40, "center", 0, 3, 3)

            Lg.setFont(oldFont)
        elseif (self.speedUp or self.bossRound) and self.stateTimer < self.displayLength * 2 then
            local oldFont = Lg.getFont()

            local textH = FontRes.chunkyNumerals:getHeight()
            local textX = cx - 40*3/2 + 1
            local textY = cy - textH * 2

            local text
            if self.bossRound then
                text = "LEVEL\nUP!"
            else
                text = "SPEED\nUP!"
            end

            Lg.setFont(FontRes.bold)

            Lg.setColor(0, 0, 0.7)
            Lg.printf(text, textX + 2, textY + 2, 40, "center", 0, 3, 3)

            if self.time % 6 < 3 then
                Lg.setColor(1, 1, 0)
            else
                Lg.setColor(1, 0, 1)
            end
            Lg.printf(text, textX, textY, 40, "center", 0, 3, 3)

            Lg.setFont(oldFont)
        else
            local oldFont = Lg.getFont()

            Lg.setFont(FontRes.chunkyNumerals)
            local textW = FontRes.chunkyNumerals:getWidth("00") - 1
            local textH = FontRes.chunkyNumerals:getHeight()
            local textX = cx - textW * 2
            local textY = cy - textH * 2

            local str = ("%02d"):format(runner.gamesCompleted+1)

            Lg.setColor(0, 0, 0.7)
            Lg.print(str, textX + 2, textY + 2, 0, 4, 4)
            Lg.setColor(1, 1, 1)
            Lg.print(str, textX, textY, 0, 4, 4)

            Lg.setFont(oldFont)
        end
    end

    local maskR, maskG, maskB = self:_getStrobeColorMask()
    for i=self.patternStart, self.patternEnd, -1 do
        local w = 5 + (i-1) * 2
        local h = 5 + (i-1) * 2
        local x = math.round(cx - w/2) - 0.5
        local y = math.round(cy - h/2) - 0.5

        local r, g, b
        if false and ((i-1) - self.time/2)%6 == 0 then
            r,g,b = 0, 0, 0
        else
            local hue = ((i-1)%12 - self.time/4)/30
            r,g,b = hsvToRgb(hue, 0.5, 0.9)
        end
        
        Lg.setColor(r * maskR, g * maskG, b * maskB)
        Lg.rectangle(i == 1 and "fill" or "line", x, y, w, h)
    end

    --[[
    Lg.setColor(0, 0, 0)
    Lg.rectangle("fill", 0, 0, GameConf.scrW, GameConf.scrH)

    Lg.setColor(1, 1, 1)
    Lg.print(tostring(runner.gamesCompleted + 1), 10, 10)

    local txt = ""
    if self.speedUp then
        txt = txt .. "SPEED UP!"
    end
    if self.bossRound then
        txt = txt .. "LEVEL UP!"
    end
    
    Lg.print(txt, 10, 30)
    --]]
end

return EnterGameState