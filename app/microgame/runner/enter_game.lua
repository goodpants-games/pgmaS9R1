local GameConf = require("microgame.conf")
local FontRes = require("fontres")

---@class microgame.Runner.EnterGameState: microgame.Runner.State
local EnterGameState = batteries.class {
    name = "microgame.Runner.EnterGameState"
}

---@param runner microgame.Runner
function EnterGameState:new(runner)
    self.runner = runner
    self.time = 0
    self.state = 1
    self.stateTimer = 0

    -- control parameters for the seizure pattern
    self.patternStart = 1
    self.patternEnd = 1
    
    self.bossRound = runner.round % GameConf.bossRoundInterval == 0

    local gameMgr = runner.gameManager
    local levelData = GameConf.speedUpPoints[gameMgr.difficulty + 1]

    self.speedUp = table.index_of(levelData, runner.round) ~= nil

    if self.speedUp then
        gameMgr.speed = gameMgr.speed + 1
    end

    if self.bossRound then
        gameMgr.speed = 0
        gameMgr.difficulty = gameMgr.difficulty + 1
        runner.round = 0

        if runner.lives < GameConf.maxLives then
            runner.lives = runner.lives + 1
        end
    end
end

function EnterGameState:tick()
    local runner = self.runner

    if self.state == 1 then
        if self.patternStart < 105 then
            self.patternStart = self.patternStart + 4
        elseif self.patternEnd < 40 then
            self.patternEnd = self.patternEnd + 4
        else
            self.state = 2
        end
    
    elseif self.state == 2 then
        self.stateTimer = self.stateTimer + 1
        if self.stateTimer == 30 then
            self.state = 3
        end
    
    elseif self.state == 3 then
        if self.patternEnd > 1 then
            self.patternEnd = math.max(self.patternEnd - 4, 1)
        elseif self.patternStart > 1 then
            self.patternStart = math.max(self.patternStart - 4, 1)
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

    if self.patternEnd > 1 then
        local oldFont = Lg.getFont()

        Lg.setFont(FontRes.chunkyNumerals)
        Lg.setColor(1, 1, 1)
        local textW = FontRes.chunkyNumerals:getWidth("00")
        local textH = FontRes.chunkyNumerals:getHeight()

        local str = ("%02d"):format(runner.gamesCompleted+1)
        Lg.print(str, cx - textW*2, cy - textH*2, 0, 4, 4)

        Lg.setFont(oldFont)
    end

    for i=self.patternStart, self.patternEnd, -1 do
        local w = 5 + (i-1) * 2
        local h = 5 + (i-1) * 2
        local x = math.round(cx - w/2) + 0.5
        local y = math.round(cy - h/2) + 0.5

        local r, g, b
        if false and ((i-1) - self.time/2)%6 == 0 then
            r,g,b = 0, 0, 0
        else
            local hue = ((i-1)%12 - self.time/4)/30
            r,g,b = hsvToRgb(hue, 0.7, 0.9)
        end
        
        Lg.setColor(r, g, b)
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