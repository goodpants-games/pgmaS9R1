LOVEJS = love.system.getOS() == "Web"
Lg = love.graphics

if LOVEJS then
    print("html5 canvas format check...")

    local supported_formats = Lg.getCanvasFormats()
    local format_check_list = {
        "rgba8",
        "srgba8",
        "rgba16",
        "rgba16f",
        "rgba32f",

        -- seems to unconditionally be supported, but as it is 16-bit color
        -- the game will look very off. i think.
        "rgba4",
    }

    local use_format
    for _, v in ipairs(format_check_list) do
        if supported_formats[v] then
            use_format = v
            break
        end
    end

    print("using: " .. use_format)

    if use_format == "rgba4" then
        love.window.showMessageBox(
            "Compatibility Warning",
            "The game must be rendered in 16-bit color mode. well, i think it's 16-bit color mode.",
            "warning")
    end

    local orig_newCanvas = love.graphics.newCanvas
    local default_settings = { format = use_format }

    local function fix_settings(s)
        if s == nil then
            s = default_settings
        elseif s.format == "normal" or s.format == nil then
            local old_s = s
            s = {}
            for k,v in pairs(old_s) do
                s[k] = v
            end
            s.format = use_format
        end

        return s
    end

    ---@diagnostic disable-next-line
    function love.graphics.newCanvas(w, h, l, s)
        if w == nil then
            w = love.graphics.getWidth()
        end

        if h == nil then
            h = love.graphics.getHeight()
        end

        if type(l) == "number" then
            return orig_newCanvas(w, h, l, fix_settings(s))
        else
            return orig_newCanvas(w, h, fix_settings(l))
        end
    end
end

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





require("batteries"):export()
Lg.setDefaultFilter("nearest")

local sceneman = require("sceneman")
sceneman.scenePrefix = "scenes."
sceneman.setCallbackMode("manual")

local has_tiled, tiled = pcall(require, "tiled")
if has_tiled then
    local tpath = require("tiled.path")
    function tiled.mapPath(cwd, path)
        -- change extension from .tsx to .lua
        if tpath.getExtension(path) == ".tsx" then
            path = tpath.join(tpath.getDirName(path),
                            tpath.getNameWithoutExtension(path) .. ".lua")
        end

        return tpath.normalize(tpath.join(cwd, path))
    end
end

local sprite = require("sprite")
sprite.fallbackAlignment = "center"

if Debug.enabled then
    local args = love.parsedGameArguments
    for i=1, #args do
        if args[i] == "--jprof" then
            local path = args[i+1]
            print( ("start love \"%s\" listen"):format(path) )
            local s = os.execute(("start love \"%s\" listen"):format(path))
            if s then
                PROF_CAPTURE = Debug.enabled
            else
                print("could not start profiler")
            end

            love.timer.sleep(1)
            love.window.requestAttention()

            break
        end
    end
end

Jprof = require("jprof")
if PROF_CAPTURE then
    Jprof.connect()
end

---Return the sign of a number, counting zero as positive.
---@param v number
---@return integer sign 1 or -1
function math.binsign(v)
    if v >= 0.0 then
        return 1
    else
        return -1
    end
end

function math.normalize_v2(x, y)
    local len = math.sqrt(x*x + y*y)
    if len > 0 then
        x = x / len
        y = y / len
    end
    return x, y
end

MOUSE_X = 0
MOUSE_Y = 0
GAME_FRAME = 0

-- pico-8 palette
-- i don't have a pico-8 but i really like how stuff in it looks
P8_PAL = {
    { batteries.colour.unpack_rgb(0x000000) }, -- black
    { batteries.colour.unpack_rgb(0x1d2b53) }, -- dark_blue
    { batteries.colour.unpack_rgb(0x7e2553) }, -- dark_purple
    { batteries.colour.unpack_rgb(0x008751) }, -- dark_green
    { batteries.colour.unpack_rgb(0xab5236) }, -- brown
    { batteries.colour.unpack_rgb(0x5f574f) }, -- dark_gray
    { batteries.colour.unpack_rgb(0xc2c3c7) }, -- light_gray
    { batteries.colour.unpack_rgb(0xfff1e8) }, -- white
    { batteries.colour.unpack_rgb(0xff004d) }, -- red
    { batteries.colour.unpack_rgb(0xffa300) }, -- orange
    { batteries.colour.unpack_rgb(0xffec27) }, -- yellow
    { batteries.colour.unpack_rgb(0x00e436) }, -- green
    { batteries.colour.unpack_rgb(0x29adff) }, -- blue
    { batteries.colour.unpack_rgb(0x83769c) }, -- indigo
    { batteries.colour.unpack_rgb(0xff77a8) }, -- pink
    { batteries.colour.unpack_rgb(0xffccaa) }, -- peach
}

P8_PAL.black       = P8_PAL[ 1]
P8_PAL.dark_blue   = P8_PAL[ 2]
P8_PAL.dark_purple = P8_PAL[ 3]
P8_PAL.dark_green  = P8_PAL[ 4]
P8_PAL.brown       = P8_PAL[ 5]
P8_PAL.dark_gray   = P8_PAL[ 6]
P8_PAL.light_gray  = P8_PAL[ 7]
P8_PAL.white       = P8_PAL[ 8]
P8_PAL.red         = P8_PAL[ 9]
P8_PAL.orange      = P8_PAL[10]
P8_PAL.yellow      = P8_PAL[11]
P8_PAL.green       = P8_PAL[12]
P8_PAL.blue        = P8_PAL[13]
P8_PAL.indigo      = P8_PAL[14]
P8_PAL.pink        = P8_PAL[15]
P8_PAL.peach       = P8_PAL[16]

require("dbgdraw")

-- What the fuck.
-- Firefox does not allow LOVE vertex shaders to define varyings because it
-- expects varyings to be declared before the main function. or something.
-- That's fucking insane. well thankfully LOVE exposes the functions which
-- generates raw GLSL shaders to the Lua environment. Yay.......
-- it's actually Lua code, which I can copy and paste here, but I don't want to
-- have all that in this project. I'll just override the function and
-- patch the output.
-- Spent two fukcing hours figuring this out. The error message it gives is very
-- non-descriptive and obtuse.
if LOVEJS then
    local orig_shaderCodeToGLSL = love.graphics._shaderCodeToGLSL

    function love.graphics._shaderCodeToGLSL(gles, arg1, arg2)
        local orig_vertexcode, pixelcode = orig_shaderCodeToGLSL(gles, arg1, arg2)
        local vertexcode = orig_vertexcode
        if orig_vertexcode then
            local vlines = {}
            for line in string.gmatch(orig_vertexcode, "[^\r\n]+") do
                vlines[#vlines+1] = line
            end

            local insertion_index = nil
            local is_user_code = false

            for i=1, #vlines do
                local line = vlines[i]

                if string.match(line, "^%s*varying%s.+;%s*$") then
                    if is_user_code then
                        assert(insertion_index)
                        local l = table.remove(vlines, i)
                        table.insert(vlines, insertion_index, l)
                    elseif not insertion_index then
                        insertion_index = i
                    end
                end

                if not is_user_code and (line == "#line 0" or line == "#line 1") then
                    is_user_code = true
                end
            end

            vertexcode = table.concat(vlines, "\n")
        end
        
	    return vertexcode, pixelcode
    end
end