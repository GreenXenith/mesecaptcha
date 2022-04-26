-- Instant input is suspicious.
-- TODO: Make time configurable
-- TODO: Make failure action configurable

minetest.register_globalstep(function(dtime)
    for _, state in pairs(mcaptcha.states) do
        if state.speed_limit then
            state.speed_limit = (state.speed_limit or 0) + dtime
        end
    end
end)

mcaptcha.register_nocaptcha("mesecaptcha:speed_limit", function(_, state)
    state.speed_limit = 0
end, function(_, state)
    if state.speed_limit and state.speed_limit < 0.5 then
        state.speed_limit = nil
        state.captcha = "mesecaptcha:repeat" -- Select a harder captcha
    end
end)
