local UserData = {}

local function boardEntry(score, name)
    return { name = name, score = score, isUser = false, }
end

UserData.scoreboardCount = 10
UserData.scoreboard = {
    boardEntry (40, "DNGAR"),
    boardEntry (39, "LAYRA"),
    boardEntry (31, "UNYU"),
    boardEntry (28, "NIC"),
    boardEntry (23, "GUINO"),
    boardEntry (22, "PIC"),
    boardEntry (17, "GUAPO"),
    boardEntry (14, "FOFO"),
    boardEntry (09, "PINNY"),
    boardEntry (05, "PROBS"),
}

return UserData