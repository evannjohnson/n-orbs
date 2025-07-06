-- nbody: nbody sim
-- by Evan Johnson
-- implementation follows https://github.com/DeadlockCode/n-body
Simulation = include("nbody-lua-lib/init")

show_tps = true
tps = 0
-- max_tps = 5000
max_tps = 200
fade_counter = 0
ready_draw = true
ready_sim = true
prev_time = os.time()
ticks = 0
frames = 0

function init()
    -- available traits to map outputs to
    mod_dests = {
        crow = {1, 2, 3, 4},
        txo = {1, 2, 3, 4}
    }
    traits = {"x", "y", "r", "vel", "acc"}
    lit_pixels = {}
    -- given a body, return the trait
    trait_handlers = {
        crow = {
            x = function(body, out)
                crow.output[out].volts = body.pos[1] * 7
            end,
            y = function(body, out)
                crow.output[out].volts = body.pos[2] * 7
            end,
            r = function(body, out)
                crow.output[out].volts = body.pos:length() * 6
            end,
            vel = function(body, out)
                -- print(body.vel:length())
                crow.output[out].volts = body.vel:length()
            end,
            acc = function(body, out)
                -- print(body.acc:length())
                crow.output[out].volts = body.acc:length()
            end
        },
        txo = {
            x = function(body, out)
                crow.ii.txo.cv(out, body.pos[1] * 7)
            end,
            y = function(body, out)
                crow.ii.txo.cv(out, body.pos[2] * 7)
            end,
            r = function(body, out)
                crow.ii.txo.cv(out, body.pos:length() * 6)
            end,
            vel = function(body, out)
                -- print(body.vel:length())
                crow.ii.txo.cv(out, body.vel:length())
            end,
            acc = function(body, out)
                -- print(body.acc:length())
                crow.ii.txo.cv(out, body.acc:length())
            end
        }
    }
    -- key is body number, value is another table
    -- subtable has destination ids as keys (ex. dest_crow_1), and function that takes the body table as the first arg and an optional "output" (like a sub-dest) as a 2nd arg, ex. crow functions treat the output arg as which crow output to send to
    -- callback on every tick
    body_callbacks = {}

    params:add{
        id="init_sim",
        name="init sim",
        type="binary",
        behavior="trigger",
        action=function()
            initSim()
        end
    }

    params:add_separator("mod_dests", "modulation destinations")
    for dest,outs in pairs(mod_dests) do
        if type(outs) == 'table' then
            for _,out in ipairs(outs) do
                addDestParam(dest, out)
            end
        else
           addDestParam(dest)
        end
    end

    screen.aa(1)
    screen.line_width(.1)
    draw_ready_metro = metro.init(readyDraw,1/60)
    draw_ready_metro:start()
    screen_ping_metro = metro.init(function()
        if redraw == my_redraw then
            screen.ping()
        end
    end, 899)
    screen_ping_metro:start()

    initSim()
    start_time = os.time()
end

function newTraitHandler(trait, target, out)
    return function(body)
        trait_handlers[target][trait](body, out)
    end
end

function addDestParam(dest, out)
    local base_id = "dest_"..dest
    local base_name = dest
    if out then
        base_id = base_id.."_"..out
        base_name = base_name.." "..out
    end

    params:add{
        id=base_id,
        name="○ "..base_name,
        type="binary",
        behavior="toggle",
        default=0,
        action=function(z)
            local n = params:get(base_id.."_body")

            if (z == 1) then
                local trait = traits[params:get(base_id.."_trait")]
                body_callbacks[n] = body_callbacks[n] or {}
                body_callbacks[n][base_id] = newTraitHandler(trait, dest, out)

                params:lookup_param(base_id).name = "● "..base_name
                params:show(base_id.."_body")
                params:show(base_id.."_trait")
                _menu.rebuild_params()
            else
                if (body_callbacks[n]) then
                    body_callbacks[n][base_id] = nil
                    if (tableSize(body_callbacks[n]) == 0) then
                        body_callbacks[n] = nil
                    end
                end

                params:lookup_param(base_id).name = "○ "..base_name
                params:hide(base_id.."_body")
                params:hide(base_id.."_trait")
                _menu.rebuild_params()
            end
        end
    }

    params:add{
        id=base_id.."_body",
        name="   body",
        type="number",
        default=1,
        min=1,
        action=function(n)
            -- remove previous callbacks
            local prev_n = params:get(base_id.."_body_save")
            if (body_callbacks[prev_n]) then
                body_callbacks[prev_n][base_id] = nil
                if (tableSize(body_callbacks[prev_n]) == 0) then
                    body_callbacks[prev_n] = nil
                end
            end
            params:set(base_id.."_body_save", n)

            if (params:get(base_id) == 1) then
                local trait = traits[params:get(base_id.."_trait")]
                -- shouldn't need to check this
                body_callbacks[n] = body_callbacks[n] or {}
                body_callbacks[n][base_id] = newTraitHandler(trait, dest, out)
            end
        end
    }
    if params:get(base_id) == 0 then
        params:hide(base_id.."_body")
        _menu.rebuild_params()
    end

    -- utility parameter to be able to remove previous callback when changing body
    params:add{
        id=base_id.."_body_save",
        type="number",
        default=params:get(base_id.."_body"),
        min=1,
    }
    params:hide(base_id.."_body_save")
    _menu.rebuild_params()

    params:add{
        id=base_id.."_trait",
        name="   trait",
        type="option",
        options=traits,
        default = 1,
        action=function(x)
            if (params:get(base_id) == 1) then
                local n = params:get(base_id.."_body")
                -- shouldn't need to check this
                body_callbacks[n] = body_callbacks[n] or {}
                body_callbacks[n][base_id] = newTraitHandler(traits[x], dest, out)
            end
        end
    }
    if params:get(base_id) == 0 then
        params:hide(base_id.."_trait")
        _menu.rebuild_params()
    end
end

function redraw()
    screen.stroke()
    fadeEffect.darkenPixels()

    -- drawBodies.eachBody(drawBody.ring)
    -- drawBodies.connectedPoints()

    for i, body in ipairs(sim.bodies) do
        drawBody.ring(body)
        local x = body.pos[1] * 26 + 63
        local y = body.pos[2] * 26 + 31
        local r = 2
        screen.circle(x, y, r)
        screen.close()
        screen.stroke()

        local width = r*4
        local ix = math.floor(x+0.5)
        local iy = math.floor(y+0.5)
        local wx = math.max(0, math.min(127, ix-(r*2)))
        local wy = math.max(0, math.min(63, iy-(r*2)))
        -- print("wx:"..wx..", wy:"..wy..", w:"..width)
        local buf = screen.peek(wx, wy, width, width)

        for i = 1, #buf do
            local rel_x = (i - 1) % (width)
            local rel_y = math.floor((i - 1) / width)
            local c = 128 * (wy + rel_y) + rel_x + wx
            local l = buf:byte(i)
            -- print(l)
            -- if l + 1 > 0 then
                lit_pixels[c] = l
            -- end
        end
    end

    -- if show_tps then
    --     if sim.ticks % 100 == 0 then
    --         tps = sim.ticks/(os.time() - start_time)
    --     end
    --     -- screen.move(10,10)
    --     -- screen.text("tps:"..tps)
    -- end

    screen.stroke()
    screen.update()
end
my_redraw = redraw -- provides a way to check if in system menu

fadeEffect = {
    alphaRectangle = function()
        screen.blend_mode('dest_out')
        screen.level_a(0, .91)
        screen.rect (0, 0, 128, 64)
        screen.close()
        screen.fill()
        screen.blend_mode(0)
    end,
    darkenBuffer = function()
        -- if sim.ticks % 4 == 0 then
        -- if fade_counter == 0 then
            local buf = screen.peek(0,0,128,64)
            -- local debuf = buf:gsub(".", function(c)
            --     local byte = c:byte() - 1
            --     return string.char(byte < 0 and 0 or byte)
            -- end)
            local t = {}
            for i = 1, #buf do
                local byte = buf:byte(i) - 1
                -- local byte = 1
                t[i] = string.char(byte < 0 and 0 or byte)  -- Clamp at 0
            end
            local debuf = table.concat(t)
            screen.poke(0,0,128,64,debuf)
        -- end
        fade_counter = (fade_counter + 1) % 2
    end,
    darkenPixels = function()
        -- if fade_counter == 0 then
        local remove_pixels = {}
            for c,level in pairs(lit_pixels) do
                local level_d = level - 1
                local x = c % 128
                local y = math.floor(c / 128)
                screen.level(level_d)
                screen.pixel(x, y)
                screen.fill()
                if level_d > 0 then
                    lit_pixels[c] = level_d
                else
                    -- lit_pixels[c] = nil
                    table.insert(remove_pixels, c)
                end
            end

            for _,c in ipairs(remove_pixels) do
                lit_pixels[c] = nil
            end
        -- end
        -- fade_counter = (fade_counter + 1) % 2
    end
}

drawBodies = {
    eachBody = function(draw)
        for i, body in ipairs(sim.bodies) do
            draw(body)
        end
    end,
    connectedPoints = function()
        for i=1, #sim.bodies - 1 do
            local bi = sim.bodies[i]
            screen.move(bi.pos[1] * 100 + 63, bi.pos[2] * 100 + 31)
            screen.line(63,31)
            screen.close()
            screen.stroke()
            for j=i+1, #sim.bodies do
                local bj = sim.bodies[j]
                screen.move(bi.pos[1] * 100 + 63, bi.pos[2] * 100 + 31)
                screen.line(bj.pos[1] * 100 + 63, bj.pos[2] * 100 + 31)
                screen.close()
                screen.stroke()
            end
        end
        screen.move(sim.bodies[#sim.bodies].pos[1] * 100 + 63, sim.bodies[#sim.bodies].pos[2] * 100 + 31)
        screen.line(63,31)
        screen.close()
        screen.stroke()
    end
}

drawBody = {
    circle = function(body)
        screen.level(15)
        screen.circle(body.pos[1] * 26 + 63, body.pos[2] * 26 + 31, 2)
        screen.close()
        screen.fill()
        screen.stroke()
    end,
    ring = function(body)
        screen.level(15)
        screen.circle(body.pos[1] * 26 + 63, body.pos[2] * 26 + 31, 2.7)
        screen.close()
        screen.stroke()
    end
}

function initSim()
    if sim_id then
        metro.free(sim_id)
        sim_id = nil
    end

    sim = Simulation:new_rand(3)
    sim.gravExponent = 1.5
    -- sim.dt = 0.01
    sim.dt = 0.015
    sim_metro = metro.init(updateSim,1/120)
    sim_id = sim_metro.id
    sim_metro:start()
end

function updateSim()
    sim:update()
    ticks = ticks + 1

    for n,callbacks in pairs(body_callbacks) do
        for _,callback in pairs(callbacks) do
            callback(sim.bodies[n])
        end
    end
end

function refresh()
    if ready_draw then
        redraw()
        ready_draw = false
    end
end

function readyDraw()
    ready_draw = true
end

function readySim()
    ready_sim = true
end

function tableSize(t)
    local n = 0
    for _,_ in pairs(t) do
        n = n + 1
    end
    return n
end

