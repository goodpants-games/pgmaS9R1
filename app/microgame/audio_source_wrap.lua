---@class microgame.SourceWrap: love.Source
---@field private _src love.Source
---@field private _pitch number
---@field private _pitchScale number
local SourceWrap = {}
for k, v in pairs(debug.getregistry().Source) do
    if k ~= "__index" and k ~= "__gc" and k ~= "__eq" then
        if type(v) == "function" then
            SourceWrap[k] = function(self, ...)
                return v(self._src, ...)
            end
        else
            SourceWrap[k] = v
        end
    end
end

SourceWrap.__index = SourceWrap

function SourceWrap:setPitch(pitch)
    self._pitch = pitch
    self:_updatePitch()
end

function SourceWrap:_setPitchScale(pitchScale)
    self._pitchScale = pitchScale
    self:_updatePitch()
end

function SourceWrap:_getPitchScale()
    return self._pitchScale
end

function SourceWrap:_updatePitch()
    self._src:setPitch(self._pitch * self._pitchScale)
end

---@param file string The path to the audio file
---@param type "stream"|"static" Streaming or static source
---@
local function newSource(file, type)
    local realSrc = love.audio.newSource(file, type)
    return setmetatable({
        _src = realSrc,
        _pitch = 1.0,
        _pitchScale = 1.0
    }, SourceWrap)
end

return newSource