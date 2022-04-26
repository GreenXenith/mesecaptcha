-- Some names may be automated

local suspicious_names = {
    "^%u%l*%d%d%d+$", -- Match randomly generated names
}

mcaptcha.register_nocaptcha("minecaptcha:suspicious", function(player, state)
    local pname = player:get_player_name()
    for _, pattern in pairs(suspicious_names) do
        -- This is a low-priority suspicion, only bother if using the simple captcha
        if pname:match(pattern) and state.captcha == "minecaptcha:notrobot" then
            state.captcha = "minecaptcha:repeat"
        end
    end
end)
