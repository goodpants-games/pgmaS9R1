print("Lua version:", _VERSION)

---@diagnostic disable-next-line
bit = require("compat.bitop")

if not unpack then
    unpack = table.unpack
end

if setfenv == nil then
    ---@param f integer|fun(any...):...unknown
    ---@param table table
    ---@return function
    function setfenv(f, table)
        if type(f) == "number" then
            f = debug.getinfo(f, "f").func
        end
        ---@cast f function

        local nm = debug.getupvalue(f, 1)
        if nm ~= "_ENV" then
           error("could not set function env") 
        end

        debug.setupvalue(f, 1, table)
        return f
    end
end

if newproxy == nil then
    local vmaj, vmin = string.match(_VERSION, "Lua (%d+)%.(%d+)")
    vmaj = tonumber(vmaj)
    vmin = tonumber(vmin)

    if not (vmaj > 5 or (vmaj == 5 and vmin >= 2)) then
        error("Lua version is <5.2 but with no support for newproxy?")
    end

    local function noop() end

    ---@param proxy boolean|table|userdata
    ---@nodiscard
    function newproxy(proxy)
        if type(proxy) == "userdata" or type(proxy) == "table" then
            return setmetatable({}, getmetatable(proxy))
        end

        local res = {}
        if proxy then
            -- dummy __gc function, because tables are only marked for
            -- finalization on the call for setmetatable. in other words, if the
            -- __gc field is not set at the time of setmetatable, it will never
            -- be called.
            setmetatable(res, { __gc = noop })
            getmetatable(res).__gc = nil
        end
        return res
    end
end

-- these imitate the love 12.0 names
---@diagnostic disable-next-line
if love._version_major < 12 then
    love.rawGameArguments = arg
    ---@diagnostic disable-next-line
    love.parsedGameArguments = love.arg.parseGameArguments(arg)
end