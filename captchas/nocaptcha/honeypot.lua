-- No human should be able to press these (easily)

mcaptcha.register_nocaptcha("minecaptcha:honeypot", function(_, state)
    state.base.form = state.base.form .. [[
        button[-1000,-1000;0,0;honeypot;Ban me]
        button[-1000,0;0,0;honeypot;Ban me]
        button[-1000,1000;0,0;honeypot;Ban me]
        button[0,-1000;0,0;honeypot;Ban me]
        button[0,1000;0,0;honeypot;Ban me]
        button[1000,-1000;0,0;honeypot;Ban me]
        button[1000,0;0,0;honeypot;Ban me]
        button[1000,1000;0,0;honeypot;Ban me]
    ]]
end, function(_, _, fields)
    if fields.honeypot then
        return false
    end
end)
