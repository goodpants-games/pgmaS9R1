local GameConf = {}

GameConf.scrW = Display.scrW
GameConf.scrH = Display.scrH

-- reference game length, in beats
GameConf.refGameLength = 8

GameConf.bpm = 120
GameConf.secsPerBeat = 60.0 / GameConf.bpm

return GameConf