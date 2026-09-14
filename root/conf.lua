require("compat.luaenv")

-- this is to make a lua debugger extension work
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()

    -- for some reason, assertion errors points to a lldebugger internal file
    -- so i'm redefining assert so that doesn't happen 
    function assert(a, b)
        return a or error(b or "assertion failed!", 2)
    end

    function love.errorhandler(msg)
        error(msg, 3)
    end
else
    require("error_explorer")
end

-- these imitate the love 12.0 names
---@diagnostic disable-next-line
if love._version_major < 12 then
    love.rawGameArguments = arg
    ---@diagnostic disable-next-line
    love.parsedGameArguments = love.arg.parseGameArguments(arg)
end

LOVEJS = require("love.system").getOS() == "Web"
-- true if running an archive instead of a filesystem folder
IS_PACKAGED = true
if not LOVEJS then
    -- it seems the only 100% accurate way to check if love is running an
    -- archive or a folder, without the ability to check using ffi'd system
    -- calls, is to attempt to open a file that should exist using the io
    -- module.
    local f = io.open(love.filesystem.getSource() .. "/main.lua", "r")
    IS_PACKAGED = f == nil
    if f then
        f:close()
    end
end

DISPLAY_WIDTH = 240
DISPLAY_HEIGHT = 160
GAME_TICK_LENGTH = 1.0 / 60.0
Debug = {
    enabled = false
}

-- check debug command flag
for _, arg in ipairs(love.parsedGameArguments) do
    if arg == "--debug" then
        Debug.enabled = true
        print("enable debug")
    end
end

function love.conf(t)
    t.version = "11.4"
    t.window.width = DISPLAY_WIDTH * 3
    t.window.height = DISPLAY_HEIGHT * 3
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = true
    
    t.modules.thread = false
    t.modules.video = false
    t.modules.physics = false
end

--------------------------------------------------------------------------------

---@diagnostic disable lowercase-global

---@param err any
---@param level integer?
function softerror(err, level)
    if level == nil then
        level = 1
    end

    err = tostring(err)

    local info = debug.getinfo(level + 1, "Sl")
    local errstr
    print(info.short_src)
    if info and info.short_src and info.currentline then
        errstr = ("%s:%i: %s"):format(info.short_src, info.currentline, err)
    else
        errstr = err
    end

    print("[ERR] " .. errstr .. "\n" .. debug.traceback())

    if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
        require("lldebugger").requestBreak()
    end
end

---@generic T
---@param v T
---@param message? any
---@param ... any
---@return T, any ...
function softassert(v, message, ...)
    if not v then
        if message == nil then
            message = "assertion failed!"
        end

        message = tostring(message)
        softerror(message, 2)
    end

    return v, ...
end

local enable_warnings = true

---@param msg1 string
---@param ... string?
function warn(msg1, ...)
    if string.byte(msg1, 1) == 0x40 and select("#", ...) == 0 then
        if msg1 == "@on" then
            enable_warnings = true
        elseif msg1 == "@off" then
            enable_warnings = false
        end
    elseif enable_warnings then
        local msg = table.concat({msg1, ...})
        print("[WRN] " .. msg)
    end
end