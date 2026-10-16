local FontRes = require("fontres")
local Input = require("input")

local scene = Sceneman.scene()
local self

local MAX_NAME_LEN = 5
local LETTERS = {
    "ok",
    "back",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
    "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", 
}

---@type fun()
local letterIterator
---@type fun(i:integer):number?
local getLetterDrawOffset
---@type fun(yBase:number)
local drawLetters

function scene.load(data)
    self = {}
    self.cursorPos = 1
    self.tick = 0
    self.buttonsPressed = {
        gameButton = false,
        auxButton1 = false,
        auxButton2 = false,
        auxButton3 = false
    }
    self.userName = ""

    Lg.setBackgroundColor(0, 0, 0)
end

function scene.unload()
    self = nil
end

function scene.update(dt)
    for k in pairs(self.buttonsPressed) do
        if Input.players[1]:pressed(k) then
            self.buttonsPressed[k] = true
        end
    end
end

---@diagnostic disable-next-line
function scene.tick()
    if self.buttonsPressed.auxButton3 then
        self.cursorPos = self.cursorPos + 1
        if self.cursorPos > #LETTERS then
            self.cursorPos = 1
        end
    end

    if self.buttonsPressed.auxButton1 then
        self.cursorPos = self.cursorPos - 1
        if self.cursorPos == 0 then
            self.cursorPos = #LETTERS
        end
    end

    if self.buttonsPressed.gameButton then
        local option = LETTERS[self.cursorPos]
        local nameLen = self.userName:len()

        if option == "ok" then
            
        elseif option == "back" then
            if nameLen > 0 then
                self.userName = self.userName:sub(1, nameLen - 1)
            end
        elseif nameLen < MAX_NAME_LEN then
            self.userName = self.userName .. LETTERS[self.cursorPos]
        end
    end

    for k in pairs(self.buttonsPressed) do
        self.buttonsPressed[k] = false
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

    drawLetters(uiBaseY + lineHeight * 2 + 8)
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

    local ofsX = assert(getLetterDrawOffset(self.cursorPos))

    Lg.push()
    Lg.translate(math.round(Display.scrW / 2 - ofsX), 0)

    for i, x, w in coroutine.wrap(letterIterator) do
        local letter = LETTERS[i]

        if i == self.cursorPos then
            local r,g,b = batteries.colour.hsv_to_rgb((self.tick/60)%1, 0.6, 1)
            Lg.setColor(r, g, b)
            Lg.rectangle("fill", x - 3, yBase - 1, w + 5, 9)

            Lg.setColor(0, 0, 0)
        else
            Lg.setColor(1, 1, 1)
        end

        Lg.print(letter, x, yBase)
    end

    Lg.pop()
end

return scene