---@class microgame.SourceWrap: love.Source
---@field private _src love.Source
---@field private _pitch number
---@field private _pitchScale number
local SourceWrap = {}
SourceWrap.__index = SourceWrap

function SourceWrap:setPitch(pitch)
    self._pitch = math.max(pitch, 0.0)
    self:_updatePitch()
end

function SourceWrap:getPitch()
    return self._pitch
end

function SourceWrap:_setPitchScale(pitchScale)
    self._pitchScale = math.max(pitchScale, 0.0)
    self:_updatePitch()
end

function SourceWrap:_getPitchScale()
    return self._pitchScale
end

function SourceWrap:_updatePitch()
    self._src:setPitch(self._pitch * self._pitchScale)
end

-- copy remaining functions from metatable for love Source
for k, v in pairs(debug.getregistry().Source) do
    if SourceWrap[k] == nil and k ~= "__gc" and k ~= "__eq" then
        if type(v) == "function" then
            SourceWrap[k] = function(self, ...)
                return v(self._src, ...)
            end
        else
            SourceWrap[k] = v
        end
    end
end

---@param source love.Source
local function wrapSource(source)
    return setmetatable({
        _src = source,
        _pitch = source:getPitch(),
        _pitchScale = 1.0
    }, SourceWrap)
end

return wrapSource