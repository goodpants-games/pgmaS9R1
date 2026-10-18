local GameConf = require("microgame.conf")
local FontRes = require("fontres")

---@class microgame.Runner.EnterGameState: microgame.Runner.State
local EnterGameState = batteries.class {
    name = "microgame.Runner.EnterGameState"
}

-- more state machines within state machines
---@class microgame.Runner.EnterGameState.Substate
---@field enter fun()?
---@field exit fun()?
---@field update (fun():string?)?
---@field draw fun()?

---@type {[string]:fun(master:microgame.Runner.EnterGameState):microgame.Runner.EnterGameState.Substate}
local subStates = {}

---@param runner microgame.Runner
function EnterGameState:new(runner, data)
    data = data or {}

    self.runner = runner
    self.time = 0

    ---@type string?
    self.subStateName = nil
    ---@type microgame.Runner.EnterGameState.Substate?
    self.subState = nil
    ---@type string?
    self.nextSubState = nil

    self.stateTimer = 0
    ---@type "expand"|"idle"|"contract"
    self.borderState = "expand"
    self.gameOver = runner.lostGame and runner.lives == 1 and runner.lifeShields == 0

    local speed = runner.gameManager.speed
    if self.gameOver then
        speed = 0
    end

    self.stateSpeed = 60 / (60 - speed * 8)
    self.effectAnimSpeed = 3 * (1 + speed * 0.25)
    self.strobeColorMask = { 1, 1, 1 }
    self.interpStrobeColorMask = { 1, 1, 1 }
    self.musicQueue = love.audio.newQueueableSource(48000, 16, 2, 4)

    -- control parameters for the seizure pattern
    self.patternStart = 1
    self.patternEnd = 1

    local gameMgr = runner.gameManager
    local levelData = GameConf.speedUpPoints[gameMgr.difficulty + 1]

    self.bossRound = runner.round % GameConf.bossRoundInterval == 0
    self.speedUp = table.index_of(levelData, runner.round) ~= nil

    self.musicQueue:setPitch(self.stateSpeed)
    self.musicQueue:setVolume(0.5)

    if runner.lostGame then
        self:_setStrobeColorMask(1, 0.2, 0.2, true)
        self.musicQueue:queue(runner.res.intermissionSnddata.statusLose)
    else
        self.musicQueue:queue(runner.res.intermissionSnddata.statusWin)
    end

    -- local sndData = runner.res.intermissionSnddata
    
    --[[
    if self.gameOver then
        self.musicQueue:queue(sndData.statusLose)
        self.musicQueue:queue(sndData.gameOver)
        self:_setStrobeColorMask(1, 0.2, 0.2, true)

        table.insert(self.stateSequence, "winStatus")
        table.insert(self.stateSequence, "gameOver")
    else
        local levelData = GameConf.speedUpPoints[gameMgr.difficulty + 1]

        self.bossRound = runner.round % GameConf.bossRoundInterval == 0
        self.speedUp = table.index_of(levelData, runner.round) ~= nil

        table.insert(self.stateSequence, "winStatus")
        if runner.lostGame then
            self.musicQueue:queue(sndData.statusLose)
            self:_setStrobeColorMask(1, 0.2, 0.2, true)
        else
            self.musicQueue:queue(sndData.statusWin)
        end

        if self.speedUp or self.bossRound then
            self.musicQueue:queue(sndData.speedUp)
        end

        if self.speedUp then
            table.insert(self.stateSequence, "speedUp")
            -- gameMgr.speed = gameMgr.speed + 1
        end

        if self.bossRound then
            -- gameMgr.speed = 0
            -- gameMgr.difficulty = math.min(gameMgr.difficulty + 1, 2)
            -- runner.round = 0

            -- if runner.lives < GameConf.maxLives then
            --     runner.lives = runner.lives + 1
            -- end
        end
        
        self.musicQueue:queue(sndData.stageScreen)
    end

    self.musicQueue:setPitch(60 / self.displayLength)
    self.musicQueue:setVolume(0.5)
    --]]

    runner.res.asrcBorderExpand:play()
    self.nextSubState = "lifeStatus"
end

function EnterGameState:exit(runner)
    self.musicQueue:stop()
    self.musicQueue:release()
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

    if self.borderState == "expand" then
        local START_MAX = 105
        local END_MAX = 50

        if self.patternStart < START_MAX then
            self.patternStart = math.round(math.min(START_MAX, self.patternStart + self.effectAnimSpeed))
        elseif self.patternEnd < END_MAX then
            self.patternEnd = math.round(math.min(END_MAX, self.patternEnd + self.effectAnimSpeed))
        else
            self.borderState = "idle"

            runner.res.asrcBorderExpand:stop()
            self.musicQueue:play()
        end

    elseif self.borderState == "contract" then
        if self.patternEnd > 1 then
            self.patternEnd = math.round(math.max(self.patternEnd - self.effectAnimSpeed, 1))
        elseif self.patternStart > 1 then
            self.patternStart = math.round(math.max(self.patternStart - self.effectAnimSpeed, 1))
        else
            runner.res.asrcBorderContract:stop()
            if self.gameOver then
                Sceneman.switchScene("game_end", runner.gamesCompleted)
            else
                self.runner:_switchState("play")
            end
        end
    
    elseif self.borderState == "idle" then
    end

    -- update substate
    if self.nextSubState then
        if self.subState and self.subState.exit then
            self.subState.exit()
        end

        self.subStateName = self.nextSubState
        self.nextSubState = nil
        self.subState = subStates[self.subStateName](self)
        
        if self.subState and self.subState.enter then
            self.subState.enter()
        end
    end

    if self.subState and self.subState.update then
        self.nextSubState = self.subState.update()
    end
    
    -- elseif self.state == 2 then
    --     self.stateTimer = self.stateTimer + 1
    --     local stages = 2
    --     if self.bossRound or self.speedUp then
    --         stages = 3
    --     end
    --     if self.gameOver then
    --         stages = 4
    --     end

    --     if self.stateTimer == self.displayLength * stages then
    --         self.state = 3

    --         runner.res.asrcBorderContract:play()
    --     end

    --     if self.stateTimer == self.displayLength and not self.gameOver then
    --         if self.speedUp then
    --             self:_setStrobeColorMask(1, 0.2, 1)    
    --         else
    --             self:_setStrobeColorMask(1, 1, 1)
    --         end
    --     end
    
    -- elseif self.state == 3 then
    --     if self.patternEnd > 1 then
    --         self.patternEnd = math.round(math.max(self.patternEnd - self.effectAnimSpeed, 1))
    --     elseif self.patternStart > 1 then
    --         self.patternStart = math.round(math.max(self.patternStart - self.effectAnimSpeed, 1))
    --     elseif self.gameOver then
    --         Sceneman.switchScene("game_end", runner.gamesCompleted)
    --     else
    --         self.runner:_switchState("play")
    --         runner.res.asrcBorderContract:stop()
    --     end
    -- end

    self.time = self.time + 1
end

function EnterGameState:draw()
    local runner = self.runner
    Lg.clear(0, 0, 0)

    local cx = math.round(Display.scrW / 2)
    local cy = math.round(Display.scrH / 2)
    local hsvToRgb = batteries.colour.hsv_to_rgb

    if self.patternEnd > 1 and self.subState and self.subState.draw then
        self.subState.draw()
    end

    --[[
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
    --]]

    -- draw rainbow ripple border
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
        if i == 1 then
            Lg.rectangle("fill", x, y, w+1, h+1)
        else
            Lg.rectangle("line", x, y, w, h)
        end
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

--------------------------------------------------------------------------------

function subStates.lifeStatus(master)
    local self = {}
    local needEnter = true
    local nextSubstate
    local time = 0

    local sndData = master.runner.res.intermissionSnddata

    function self.exit()
        if nextSubstate == "stage" then
            master:_setStrobeColorMask(1.0, 1.0, 1.0)
        end
    end

    function self.update()
        if master.borderState ~= "idle" then
            return
        end

        if needEnter then
            needEnter = false
            local runner = master.runner

            if master.speedUp or master.bossRound then
                nextSubstate = "modifier"
            else
                nextSubstate = "stage"
            end

            -- ouch
            if runner.lostGame then
                if runner.lifeShields > 0 then
                    runner.lifeShields = runner.lifeShields - 1
                else
                    runner.lives = runner.lives - 1
                end
    
                -- game over :(
                if master.gameOver then
                    softassert(runner.lives == 0, "game over, but lives not set to zero?")
                    nextSubstate = "gameOver"
                end
            end

            if nextSubstate == "modifier" then
                master.musicQueue:queue(sndData.speedUp)
            elseif nextSubstate == "stage" then
                master.musicQueue:queue(sndData.stageScreen)
            elseif nextSubstate == "gameOver" then
                master.musicQueue:queue(sndData.gameOver)
            end
        end

        time = time + master.stateSpeed
        if time >= 60 then
            return nextSubstate
        end
    end

    function self.draw()
        local cx = math.round(Display.scrW / 2)
        local cy = math.round(Display.scrH / 2)
        local beetleFaceSpr = master.runner.res.beetleFaceSpr

        Lg.setColor(1, 1, 1)
        local sprCel = 1
        if master.runner.lostGame then
            sprCel = 2
        end

        for i=0, 12 do
            local x = cx + i * 30 - (master.time%30) - 30
            local yBase = cy + math.sin((master.time/10 + i/6) * (math.pi/2)) * 6
            beetleFaceSpr:drawCel(sprCel, x, yBase)
            -- beetleFaceSpr:drawCel(sprCel, x, yBase + 34)
        end
    end

    return self
end

function subStates.modifier(master)
    local self = {}
    local time = 0

    local sndData = master.runner.res.intermissionSnddata

    function self.enter()
        master:_setStrobeColorMask(1, 0.2, 1)
        master.musicQueue:queue(sndData.stageScreen)

        local runner = master.runner
        local gameMgr = runner.gameManager
        if master.speedUp then
            gameMgr.speed = gameMgr.speed + 1
        end
        if master.bossRound then
            gameMgr.speed = 0
            gameMgr.difficulty = math.min(gameMgr.difficulty + 1, 2)
            runner.round = 0
        end
    end

    function self.update()
        time = time + master.stateSpeed
        if time >= 60 then
            return "stage"
        end
    end

    function self.draw()
        local cx = math.round(Display.scrW / 2)
        local cy = math.round(Display.scrH / 2)

        local textH = FontRes.chunkyNumerals:getHeight()
        local textX = cx - 40*3/2 + 1
        local textY = cy - textH * 2

        local text
        if master.bossRound then
            text = "LEVEL\nUP!"
        else
            text = "SPEED\nUP!"
        end

        local oldFont = Lg.getFont()
        Lg.setFont(FontRes.bold)

        Lg.setColor(0, 0, 0.7)
        Lg.printf(text, textX + 2, textY + 2, 40, "center", 0, 3, 3)

        if master.time % 6 < 3 then
            Lg.setColor(1, 1, 0)
        else
            Lg.setColor(1, 0, 1)
        end
        Lg.printf(text, textX, textY, 40, "center", 0, 3, 3)

        Lg.setFont(oldFont)
    end

    return self
end

function subStates.stage(master)
    local self = {}
    local time = 0
    local displayStr = ("%02d"):format(master.runner.gamesCompleted+1)

    function self.update()
        time = time + master.stateSpeed
        if time >= 60 and master.borderState == "idle" then
            master.borderState = "contract"
            master.runner.res.asrcBorderContract:play()
        end
    end

    function self.draw()
        local cx = math.round(Display.scrW / 2)
        local cy = math.round(Display.scrH / 2)

        local oldFont = Lg.getFont()
        Lg.setFont(FontRes.chunkyNumerals)

        local textW = FontRes.chunkyNumerals:getWidth("00") - 1
        local textH = FontRes.chunkyNumerals:getHeight()
        local textX = cx - textW * 2
        local textY = cy - textH * 2

        Lg.setColor(0, 0, 0.7)
        Lg.print(displayStr, textX + 2, textY + 2, 0, 4, 4)
        Lg.setColor(1, 1, 1)
        Lg.print(displayStr, textX, textY, 0, 4, 4)

        Lg.setFont(oldFont)
    end

    return self
end

function subStates.gameOver(master)
    local self = {}
    local time = 0

    function self.update()
        time = time + 1
        if time == 60*4 then
            master.borderState = "contract"
            master.runner.res.asrcBorderContract:play()
        end
    end

    function self.draw()
        local cx = math.round(Display.scrW / 2)
        local cy = math.round(Display.scrH / 2)

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
    end

    return self
end

--------------------------------------------------------------------------------

return EnterGameState