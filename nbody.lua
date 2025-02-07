-- nbody: nbody sim
-- v0.1 @evannjohnson
-- implementation follows https://github.com/DeadlockCode/n-body
Simulation = include("nbody-lua-lib/init")

-- an array of tables, each table has pos = Vec2 and level = 0-15
-- trails = {}

show_tps = false
tps = 0

function init()
    screen.level(15)
    screen.aa(1)
    screen.line_width(1)
    screen.blend_mode('difference')
    sim = Simulation:new_rand(3)
    sim.gravExponent = 1.5
    simId = startSim(sim, 520)
    start_time = os.time()
end

function key(n, z)
    -- key actions: n = number, z = state
end

function enc(n, d)
    -- encoder actions: n = number, d = delta
end

function redraw()
    -- screen.clear()
    screen.stroke()
    -- if sim.ticks % 100 == 0 then
    --     screen.level(0)
    --     screen.rect (0, 0, 128, 64)
    --     screen.close()
    --     screen.fill()
    --     screen.level(15)
    -- end
    if sim.ticks % 4 == 0 then
        local buf = screen.peek(0,0,128,64)
        -- local debuf = buf:gsub(".", function(c)
        --     local byte = c:byte() - 1
        --     return string.char(byte < 0 and 0 or byte)
        -- end)
        local t = {}
        for i = 1, #buf do
            local byte = buf:byte(i) - 1
            t[i] = string.char(byte < 0 and 0 or byte)  -- Clamp at 0
        end
        local debuf = table.concat(t)
        screen.poke(0,0,128,64,debuf)
        -- screen.poke(0,0,128,64,table.concat(t))
    end

    for i, body in ipairs(sim.bodies) do
        screen.circle(body.pos[1] * 28 + 63, body.pos[2] * 28 + 31, 2)
        screen.close()
        screen.stroke()
    end
    -- for i=1, #sim.bodies - 1 do
    --     local bi = sim.bodies[i]
    --     screen.move(bi.pos[1] * 100 + 63, bi.pos[2] * 100 + 31)
    --     screen.line(63,31)
    --     screen.close()
    --     screen.stroke()
    --     for j=i+1, #sim.bodies do
    --         local bj = sim.bodies[j]
    --         screen.move(bi.pos[1] * 100 + 63, bi.pos[2] * 100 + 31)
    --         screen.line(bj.pos[1] * 100 + 63, bj.pos[2] * 100 + 31)
    --         screen.close()
    --         screen.stroke()
    --     end
    -- end
    -- screen.move(sim.bodies[#sim.bodies].pos[1] * 100 + 63, sim.bodies[#sim.bodies].pos[2] * 100 + 31)
    -- screen.line(63,31)
    -- screen.close()
    -- screen.stroke()


    if show_tps then
        if sim.ticks % 100 == 0 then
            tps = sim.ticks/(os.time() - start_time)
        end
        screen.move(10,10)
        screen.text("tps:"..tps)
    end
    screen.update()
end

function startSim(sim, max_tps)
    id = clock.run(function()
        while true do
            sim:update()
            redraw()
            clock.sleep(1 / max_tps)
        end
    end)
    return id
end

function cleanup()
    -- deinitialization
end

