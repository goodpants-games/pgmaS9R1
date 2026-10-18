local FontRes = require("fontres")
local Input = require("input")
local Userdata = require("userdata")
local Sprite = require("sprite")

local scene = Sceneman.scene()
local self

local MAX_NAME_LEN = 5
local LETTERS = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
    "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "back",
    "ok",
}

---@type fun()
local letterIterator
---@type fun(i:integer):number?
local getLetterDrawOffset
---@type fun(yBase:number)
local drawLetters
---@type fun()
local submitScore

function scene.load(score)
    print("score: " .. tostring(score))

    self = {}
    self.cursorPos = 1
    self.inputOfs = 0
    self.tick = 0
    self.buttonsPressed = {
        gameButton = false,
        auxButton1 = false,
        auxButton2 = false,
        auxButton3 = false
    }
    self.buttonsReleased = {
        gameButton = false,
        auxButton1 = false,
        auxButton2 = false,
        auxButton3 = false
    }
    self.userName = ""
    self.score = score
    self.wantExit = false
    self.buttonsSpr = Sprite.new("/res/sprites/buttons.json")
    self.buttonsSpr.alignment = "topleft"
    
    -- letter push animation data
    self.letterPy = {}
    self.letterVy = {}
    for i=1, #LETTERS do
        self.letterPy[i] = 0
        self.letterVy[i] = 0
    end

    Lg.setBackgroundColor(0, 0, 0)
end

function scene.unload()
    self.buttonsSpr:release()
    self = nil
end

---@diagnostic disable-next-line
function scene.rawUpdate(dt)
    for k in pairs(self.buttonsPressed) do
        if Input.players[1]:pressed(k) then
            self.buttonsPressed[k] = true
        end
    end

    for k in pairs(self.buttonsReleased) do
        if Input.players[1]:released(k) then
            self.buttonsReleased[k] = true
        end
    end
end

---@diagnostic disable-next-line
function scene.update()
    local idev = Input.players[1]

    if self.wantExit and not idev:down("gameButton") then
        submitScore()
        return
    end
    
    -- cursor right
    if self.buttonsPressed.auxButton3 then
        -- self.letterPy[self.cursorPos] = 0
        -- self.letterVy[self.cursorPos] = 0

        self.cursorPos = self.cursorPos + 1
        if self.cursorPos > #LETTERS then
            self.cursorPos = 1
        end
    end

    -- cursor left
    if self.buttonsPressed.auxButton1 then
        -- self.letterPy[self.cursorPos] = 0
        -- self.letterVy[self.cursorPos] = 0
        
        self.cursorPos = self.cursorPos - 1
        if self.cursorPos == 0 then
            self.cursorPos = #LETTERS
        end
    end

    -- back keybind
    if self.buttonsPressed.auxButton2 then
        local idx = assert( table.index_of(LETTERS, "back") )
        self.letterPy[idx] = 4
        self.letterVy[idx] = 0

        local nameLen = self.userName:len()
        if nameLen > 0 then
            self.userName = self.userName:sub(1, nameLen - 1)
        end
    end

    if self.buttonsPressed.gameButton then
        local option = LETTERS[self.cursorPos]
        local nameLen = self.userName:len()

        self.letterPy[self.cursorPos] = 4
        self.letterVy[self.cursorPos] = 0

        if option == "ok" then
            self.wantExit = true
        elseif option == "back" then
            if nameLen > 0 then
                self.userName = self.userName:sub(1, nameLen - 1)
            end
        elseif nameLen < MAX_NAME_LEN then
            self.userName = self.userName .. LETTERS[self.cursorPos]
        end
    end

    -- update input X draw offset
    do
        local desiredOfsX = assert(getLetterDrawOffset(self.cursorPos))
        self.inputOfs = self.inputOfs + (desiredOfsX - self.inputOfs) * 0.2
    end

    -- input letter Y draw offset
    do
        local py = self.letterPy
        local vy = self.letterVy

        for i=1, #LETTERS do
            vy[i] = vy[i] + (0 - py[i]) * 0.3 - vy[i] * 0.2
            py[i] = py[i] + vy[i]
        end
    end

    -- epilogue
    for k in pairs(self.buttonsPressed) do
        self.buttonsPressed[k] = false
    end
    for k in pairs(self.buttonsReleased) do
        self.buttonsReleased[k] = false
    end

    self.tick = self.tick + 1
end

function scene.draw()
    Lg.setFont(FontRes.bold)
    local lineHeight = 12

    local uiBaseY = math.round((Display.scrH - lineHeight*3) / 2)
    Lg.printf("ENTER YOUR NAME", 0, uiBaseY + FontRes.bold:getHeight() - 2, Display.scrW, "center")

    Lg.setFont(FontRes.monogram)
    local nameX = math.round((Display.scrW - FontRes.monogram:getWidth("_____")) / 2)
    Lg.print("_____", nameX, uiBaseY + lineHeight + 2)
    Lg.print(self.userName, nameX, uiBaseY + lineHeight)

    local lettersY = uiBaseY + lineHeight * 2 + 8
    drawLetters(lettersY)

    -- draw controls
    local ctlBaseX = math.round(Display.scrW / 2)
    local ctlBaseY = lettersY + 16
    Lg.setFont(FontRes.quinque)
    Lg.setColor(1, 1, 1)
    local controlsData = {
        {"gameButton", "OK"},
        {"auxButton1", "LEFT"},
        {"auxButton3", "RIGHT"},
        {"auxButton2", "BACK"},
    }
    for i, row in pairs(controlsData) do
        local y = ctlBaseY + (i-1) * 10
        self.buttonsSpr:play("key_" .. row[1])
        self.buttonsSpr:draw(ctlBaseX - 12 - 2, y)
        Lg.print(row[2], ctlBaseX + 2, y + 1)
    end
end

----

function letterIterator()
    local font = FontRes.bold

    local x = 0
    for i, letter in pairs(LETTERS) do
        local w = font:getWidth(letter)
        coroutine.yield(i, x, w)
        x = x + w + 6
    end
end

function getLetterDrawOffset(i)
    for j, x, w in coroutine.wrap(letterIterator) do
        if i == j then
            return x + w/2
        end
    end
end

function drawLetters(yBase)
    local font = FontRes.bold
    Lg.setFont(font)

    local ofsX = self.inputOfs

    Lg.push()
    Lg.translate(math.round(Display.scrW / 2 - ofsX), 0)

    for i, x, w in coroutine.wrap(letterIterator) do
        local letter = LETTERS[i]
        local yofs = self.letterPy[i]

        if i == self.cursorPos then
            local r,g,b = batteries.colour.hsv_to_rgb((self.tick/60)%1, 0.6, 1)
            Lg.setColor(r, g, b)
            Lg.rectangle("fill", x - 3, yBase - 1 + yofs, w + 5, 9)

            Lg.setColor(0, 0, 0)
        else
            Lg.setColor(1, 1, 1)
        end

        Lg.print(letter, x, yBase + yofs)
    end

    Lg.pop()
end

function submitScore()
    local name = self.userName
    if name == "" then
        name = "ANONY"
    end
    local score = self.score

    for i=1, Userdata.scoreboardCount do
        local entry = Userdata.scoreboard[i]
        if score >= entry.score then
            table.insert(Userdata.scoreboard, i, {
                score = score,
                name = name,
                isUser = true
            })
            -- remove last value
            table.remove(Userdata.scoreboard)
            break
        end
    end

    Sceneman.switchScene("title")
end

return scene