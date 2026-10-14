-- TODO: title screen
--[[
- show leaderboards
- funny strobing lights, ala Evil Egg
- show "Insert Credit" text. the user presses SPACE to "insert a quarter".
  turns into "Press SPACE to Start!" upon doing so.
- also show controls: SPACE, A, S, and D.

1.  DNGAR
2.  <Unsure>
3.  CHIBR
4.  NIC
5.  GUINO
6.  PIC
7.  GUAPO
8.  FOFO
9.  PINNY
10. PROBS
--]]

local scene = Sceneman.scene()
local self

function scene.load(data)
    print("load title")
    self = {}
    Lg.setBackgroundColor(0, 0, 0)
end

function scene.unload()
    self = nil
end

function scene.update(dt)
    Sceneman.switchScene("game_runner")
end

---@diagnostic disable-next-line
function scene.tick()
end

function scene.draw()
end

return scene