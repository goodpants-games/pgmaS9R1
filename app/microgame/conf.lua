local GameConf = {}

GameConf.scrW = App.scrH
GameConf.scrH = App.scrH
-- reference game length, in seconds
GameConf.refGameLength = 4.0

-- these variables are adjusted by the game manager
GameConf.speed = 1
GameConf.difficulty = 1

return GameConf