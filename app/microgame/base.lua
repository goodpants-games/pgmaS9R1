---@class microgame.Game: batteries.Class
---@overload fun(mgr: microgame.Manager):microgame.Game
---@field tick fun()?
---@field draw fun()?
---@field win boolean
---@field verb string
---@field backgroundColor number[]
local Base = batteries.class { name = "microgame.GameBase" }

---@param mgr microgame.Manager
function Base:new(mgr)
    self.manager = mgr
    self.win = false
    self.backgroundColor = { 0.0, 0.0, 0.0 }

    ---@private
    ---@type love.Object[]
    self._tempResources = {}
end

---@generic T
---@param res T
---@return T
function Base:releaseOnUnload(res)
    ---@diagnostic disable-next-line
    if not res.release then
        error("given resource/object has no release method!")
    end

    table.insert(self._tempResources, res)
    return res
end

function Base:unload()
    print(("release %s resources"):format(#self._tempResources))
    for _, res in pairs(self._tempResources) do
        if res.typeOf and res:typeOf("Source") then
            (res--[[@as love.Source]]):stop()
        end
        res:release()
    end
end

return Base