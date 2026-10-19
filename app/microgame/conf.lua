local GameConf = {}

GameConf.scrW = Display.scrW
GameConf.scrH = Display.scrH

-- reference game length, in beats
GameConf.refGameLength = 8

GameConf.bpm = 120
GameConf.secsPerBeat = 60.0 / GameConf.bpm

GameConf.bossRoundInterval = 20
GameConf.maxLives = 4
GameConf.speedUpPoints = {
    -- level 1
    { 8, 16 },
    -- level 2
    { 6, 12 },
    -- level 3
    { 4, 8 }
}
GameConf.shopPoints = {
    -- level 1
    { 4, 8, 14 },
    -- level 2
    { 1, 6, 12 },
    -- level 3
    { 1, 8, 14 }
}

if false then
    print("INSERT DEBUG SPEED UP POINTS")
    for i=1, 3 do
        table.insert(GameConf.speedUpPoints, 1, { 2, 5 })
    end
end

return GameConf