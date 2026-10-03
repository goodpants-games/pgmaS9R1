local GameConf = {}

GameConf.scrW = App.scrH
GameConf.scrH = App.scrH
-- reference game length, in seconds
GameConf.refGameLength = 4.0

-- these variables are adjusted by the game manager
GameConf.speed = 1
GameConf.difficulty = 1

---@class Microgame
---@overload fun(speed: number, level: number):Microgame
---@field tick fun()?
---@field draw fun()?
---@field release fun()?
---@field win boolean
---@field verb string
---@field backgroundColor number[]?

return GameConf