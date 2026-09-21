require("conf2")

local fontres = require("fontres")

App.mousex = 0
App.mousey = 0
App.frame = 0

local display_canvas = Lg.newCanvas(App.scrw, App.scrh, { dpiscale = 1.0 })

local display_ox = 0.0
local display_oy = 0.0
local display_scale = 1.0
local game_focused = true

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

    for _, arg in ipairs(args) do
        if arg == "--debug" then
            Debug.enabled = true
            print("enable debug")
        end
    end

    Lg.setFont(fontres.monogram)
	
    Sceneman.switchScene("main")
end

---@diagnostic disable-next-line duplicate-set-field
function love.keypressed(key)
    Sceneman.dispatch("keypressed", key)

    if key == "f1" then
        Debug.enabled = not Debug.enabled
    end

    if not IS_PACKAGED and key == "f12" then
        Lg.captureScreenshot(function(data)
            ---@cast data love.ImageData
            local fdata = data:encode("png")

            local file = assert(io.open("screenshot.png", "wb"), "could not open screenshot.png")
            file:write(fdata:getString())
            file:close()

            fdata:release()
            data:release()
        end)
    end
end

---@diagnostic disable-next-line duplicate-set-field
function love.textinput(...)
    Sceneman.dispatch("textinput", ...)
end

local function update_display_fit()
    display_scale = math.min(Lg.getHeight() / App.scrh, Lg.getWidth() / App.scrw)
    display_scale = math.max(1, display_scale)
    -- display_scale = math.floor(display_scale)
    display_ox = (Lg.getWidth() - App.scrw * display_scale) / 2
    display_oy = (Lg.getHeight() - App.scrh * display_scale) / 2
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

    Debug.draw.enabled = Debug.enabled

    update_display_fit()
    App.mousex = (love.mouse.getX() - display_ox) / display_scale
    App.mousey = (love.mouse.getY() - display_oy) / display_scale

    Jprof.push("update")
    Sceneman.update(dt)
    Jprof.pop("update")

    -- dt snap calculation
    -- https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75
    local dt_to_accum = dt
    local DT_SNAP_EPSILON = 0.002
    local tick_len = App.tick_length

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
        Sceneman.dispatch("tick")
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

---@diagnostic disable-next-line duplicate-set-field
function love.draw()
    local draw_ts = love.timer.getTime()

    Lg.setCanvas(display_canvas)
    local bg_r, bg_g, bg_b, bg_a = Lg.getBackgroundColor()
    Lg.clear(bg_r, bg_g, bg_b, bg_a)

    Jprof.push("draw")
    Sceneman.draw()
    Debug.draw:flush()
    
    -- draw display onto window
    Jprof.push("display")
    Lg.setCanvas()
    Lg.clear(0, 0, 0, 1)
    Lg.setColor(1, 1, 1)
    Lg.origin()
    Lg.draw(display_canvas, display_ox, display_oy, 0, display_scale, display_scale)
    Lg.setShader()

    Jprof.pop("display")
    Jprof.pop("draw")

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