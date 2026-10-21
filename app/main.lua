require("conf2")

local USE_CRT = true

Display = require("display")
local fontres = require("fontres")
local Input = require("input")
local Shaders = require("shaders")

App.mousex = 0
App.mousey = 0
App.frame = 0

local SIDE_BLUR_SCALE = 6.0
local DISPLAY_RENDER_SCALE = 3.0

local shellCanvas = Lg.newCanvas(240, 180, { dpiscale = 1.0 })
local sideBlurCanvas = Lg.newCanvas(Display.scrW, Display.scrH / SIDE_BLUR_SCALE, { dpiscale = 1.0 })
local screenShader = Shaders.crt

local display_ox = 0.0
local display_oy = 0.0
local display_scale = 1.0
local game_focused = true

-- make sure draw is not ever called without a previous call to tick
local did_tick = false

local WindowedAnalyzer = batteries.class()
function WindowedAnalyzer:new()
    ---@private
    self._time_passed = 0.0
    ---@private
    self._dt_accum = 0.0
    ---@private
    self._dt_max = 0.0
    ---@private
    self._samples = 0

    self.dt_max = 0.0
    self.dt_avg = 0.0
end

---@param elapsed number
function WindowedAnalyzer:add_sample(elapsed)
    self._dt_accum = self._dt_accum + elapsed
    if elapsed > self._dt_max then
        self._dt_max = elapsed
    end

    self._samples = self._samples + 1.0
end

---@param dt number
function WindowedAnalyzer:update(dt)
    self._time_passed = self._time_passed + dt
    if self._time_passed > 0.5 then
        self._time_passed = self._time_passed % 0.5

        self.dt_max = self._dt_max
        self.dt_avg = self._dt_accum / self._samples

        self._dt_accum = 0.0
        self._dt_max = 0.0
        self._samples = 0
    end
end

local anl_update = WindowedAnalyzer()
local anl_draw = WindowedAnalyzer()
local anl_total = WindowedAnalyzer()
local anl_mem = WindowedAnalyzer()

local perf_heavy_frame = false
-- call this on every frame whenever major loading is performed
function Mark_perf_heavy_frame()
    perf_heavy_frame = true
end

---@diagnostic disable-next-line duplicate-set-field
function love.load(args)
    love.keyboard.setTextInput(false)

    local skipBoot = false
    local goToGameEnd = false
    local initParams = {}
    if Debug.enabled then
        local argi = 1
        while argi <= #args do
            local arg = args[argi]
            if arg == "--microgame" then
                argi = argi + 1
                initParams.initMicrogame = args[argi]
            
            elseif arg == "--difficulty" then
                argi = argi + 1
                initParams.difficulty = tonumber(args[argi])

            elseif arg == "--speed" then
                argi = argi + 1
                initParams.speed = tonumber(args[argi])

            elseif arg == "--skip-boot" then
                skipBoot = true

            elseif arg == "--game-end" then
                goToGameEnd = true
            end

            argi = argi + 1
        end
    end

    Input.init()

    Lg.setFont(fontres.monogram)

    Display.init()
	
    if goToGameEnd then
        Sceneman.switchScene("game_end", 15)
    -- if there is at least one key in initParams...
    elseif skipBoot or next(initParams) then
        Sceneman.switchScene("game_runner", initParams)
    else
        Sceneman.switchScene("self_test", {})
    end
end

---@diagnostic disable-next-line duplicate-set-field
function love.keypressed(key)
    Sceneman.dispatch("keypressed", key)

    if key == "f1" then
        Debug.enabled = not Debug.enabled
    end

    if key == "f3" then
        USE_CRT = not USE_CRT
    end

    -- if not IS_PACKAGED and key == "f12" then
    --     local data = display_canvas:newImageData()
    --     local fdata = data:encode("png")

    --     local file = assert(io.open("screenshot.png", "wb"), "could not open screenshot.png")
    --     file:write(fdata:getString())
    --     file:close()

    --     fdata:release()
    --     data:release()
    -- end
end

---@diagnostic disable-next-line duplicate-set-field
function love.textinput(...)
    Sceneman.dispatch("textinput", ...)
end

local function update_display_fit()
    display_scale = math.min(Lg.getHeight() / App.scrH, Lg.getWidth() / App.scrW)
    display_scale = math.max(1, display_scale)
    -- display_scale = math.floor(display_scale)
    display_ox = (Lg.getWidth() - App.scrW * display_scale) / 2
    display_oy = (Lg.getHeight() - App.scrH * display_scale) / 2
    display_ox = math.floor(display_ox)
    display_oy = math.floor(display_oy)
    -- print(display_ox, display_oy, display_scale)
end

local dt_accum = 0.0

---@diagnostic disable-next-line duplicate-set-field
function love.update(dt)
    Jprof.push("frame")
    local start = love.timer.getTime()

    Jprof.push("manual gc")
    batteries.manual_gc(1e-1)
    Jprof.pop()

    anl_mem:add_sample(collectgarbage("count"))

    Input.update()

    Debug.draw.enabled = Debug.enabled

    update_display_fit()
    App.mousex = (love.mouse.getX() - display_ox) / display_scale
    App.mousey = (love.mouse.getY() - display_oy) / display_scale

    Jprof.push("raw update")
    Sceneman.dispatch("rawUpdate", dt)
    Jprof.pop("raw update")

    -- dt snap calculation
    -- https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75
    local dt_to_accum = dt
    local DT_SNAP_EPSILON = 0.002
    local tick_len = App.tickLength

    if math.abs(dt - tick_len) < DT_SNAP_EPSILON then -- 60 fps?
        dt_to_accum = tick_len
    elseif math.abs(dt - tick_len * 0.5) < DT_SNAP_EPSILON then -- 120 fps?
        dt_to_accum = tick_len * 0.5
    end

    local iter = 1

    if perf_heavy_frame then
        perf_heavy_frame = false
    else
        dt_accum = dt_accum + dt_to_accum
    end

    while dt_accum >= tick_len do
        if iter > 8 then
            print("too many ticks in one frame!")
            dt_accum = dt_accum % tick_len
            break
        end
        
        Jprof.push("tick")
        Sceneman.update(App.tickLength)
        Display.tick()
        did_tick = true
        Jprof.pop("tick")

        dt_accum = dt_accum - tick_len
        iter=iter+1
        App.frame = App.frame + 1
    end

    Jprof.push("post tick")
    Sceneman.dispatch("post_tick")
    Jprof.pop("post tick")

    anl_update:update(dt)
    anl_draw:update(dt)
    anl_total:update(dt)
    anl_mem:update(dt)

    anl_update:add_sample(love.timer.getTime() - start)
    anl_total:add_sample(dt)
end

---@param x number?
---@param y number?
---@param w number?
---@param h number?
local function setScissorScaled(x, y, w, h)
    Lg.setScissor(
        (x or 0) * display_scale + display_ox,
        (y or 0) * display_scale + display_oy,
        (w or App.scrW) * display_scale,
        (h or App.scrH) * display_scale
    )
end

---@diagnostic disable-next-line duplicate-set-field
function love.draw()
    local draw_ts = love.timer.getTime()
    Jprof.push("draw")

    Lg.clear(0, 0, 0)
    Lg.translate(display_ox, display_oy)
    Lg.scale(display_scale, display_scale)
    setScissorScaled(0, 0, App.scrW, App.scrH)

    if did_tick then
        local rscl = DISPLAY_RENDER_SCALE
        local scrX = math.round(Display.scrX / rscl)
        local liSx = 8
        local liOx = 5

        Display.drawDisplay()

        -- draw display to side blur canvas
        Lg.push("all")
        Lg.setCanvas(sideBlurCanvas)
        Lg.origin()
        Lg.setScissor()
        Display.canvas:setFilter("linear", "linear")
        Lg.draw(Display.canvas, 0, 0, 0, 1.0, 1.0 / SIDE_BLUR_SCALE)
        Lg.pop()

        Lg.push("all")
        Lg.setCanvas(shellCanvas)
        Lg.origin()
        Lg.setScissor()
        Lg.clear(0, 0, 0)
        Display.drawShell()

        -- set up light influence draw
        Lg.setColor(0.4, 0.4, 0.4, 1.0)
        Lg.setBlendMode("add")
        sideBlurCanvas:setFilter("linear", "linear")
        -- draw light influence on left bar
        Lg.setScissor(26, 0, 3, Display.scrH)
        Lg.draw(sideBlurCanvas,
            26 - liOx, 0,
            0,
            liSx, SIDE_BLUR_SCALE
        )
        -- draw light influence on right bar
        Lg.setScissor(211, 0, 3, Display.scrH)
        Lg.draw(sideBlurCanvas,
            211 - Display.scrW * liSx + liOx, 0,
            0,
            liSx, SIDE_BLUR_SCALE)
        Lg.pop()
        
        local bg_r, bg_g, bg_b, bg_a = Lg.getBackgroundColor()
        Lg.clear(bg_r, bg_g, bg_b, bg_a)

        -- draw shell
        Lg.setColor(1, 1, 1)
        Lg.draw(shellCanvas, 0, 0, 0, rscl, rscl)
        
        -- draw screen display, crt shader
        Lg.setColor(1, 1, 1)
        if USE_CRT then
            Lg.setShader(screenShader)
            -- screenShader:send("u_row_freq", Display.canvas:getHeight())
            screenShader:send("signal_size", { Display.canvas:getDimensions() })
            Display.canvas:setFilter("linear", "linear")
            Lg.draw(Display.canvas, scrX, 0, 0, rscl, rscl)
            Lg.setShader()
        else
            Display.canvas:setFilter("nearest", "nearest")
            Lg.draw(Display.canvas, scrX, 0, 0, rscl, rscl)
        end

        Debug.draw:flush()
    end
    
    Jprof.pop("draw")

    Lg.origin()
    Lg.setScissor()

    local draw_frametime = love.timer.getTime() - draw_ts
    anl_draw:add_sample(draw_frametime)

    -- debug text
    if Debug.enabled then
        Lg.push("all")
        Lg.setColor(1, 1, 1)
        Lg.setFont(fontres.monogram)
        Lg.print(("mem: %.2f MiB / %.2f MiB"):format(anl_mem.dt_avg / 1000, anl_mem.dt_max / 1000), 1, 1)
        Lg.print(("update: %.1f ms / %.1f ms"):format(anl_update.dt_avg * 1000, anl_update.dt_max * 1000), 1, 11)
        Lg.print(("draw: %.1f ms / %.1f ms"):format(anl_draw.dt_avg * 1000, anl_draw.dt_max * 1000), 1, 21)
        Lg.print(("frame: %.1f ms / %.1f ms"):format(anl_total.dt_avg * 1000, anl_total.dt_max * 1000), 1, 31)
        Lg.pop()
    end

    Jprof.pop("frame")
end

---@diagnostic disable
function love.run()
	if love.load then
        love.load(love.parsedGameArguments, love.rawGameArguments)
    end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

    if love.graphics then
        print(love.graphics.getRendererInfo())
    end

	local dt = 0

	-- Main loop time.
	return function()
        assert(love.event)
        assert(love.window)

		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

        if game_focused then
            -- Call update and draw
            if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

            if love.graphics and love.graphics.isActive() then
                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())

                if love.draw then love.draw() end

                love.graphics.present()
            end
        end

		if not LOVEJS and love.timer then love.timer.sleep(0.001) end
	end
end