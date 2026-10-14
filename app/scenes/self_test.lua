-- TODO: fake self-test screen
-- https://www.youtube.com/watch?v=LVDbhC5Sve4
-- in particular, maybe inspired by Williams self-tests? (the game Joust in the
-- video)
-- random jumble of pixels, "Initial Tests Indicate All Systems Go"
-- I made it so that setting bg color alpha to 0 (invisible) will not make it
-- force-clear the screen before drawing, i think. which will probably be
-- useful.

local scene = Sceneman.scene()
local self

function scene.load(data)
    print("load self test")
    self = {}
    Lg.setBackgroundColor(0, 0, 0)
end

function scene.unload()
    self = nil
end

function scene.update(dt)
    Sceneman.switchScene("title")
end

---@diagnostic disable-next-line
function scene.tick()
end

function scene.draw()
end

return scene