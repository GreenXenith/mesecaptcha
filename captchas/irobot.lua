-- I am not a robot.
mcaptcha.register_captcha("mesecaptcha:notrobot", function()
    return "checkbox[3,4;notrobot;TEXTCOLOR(I am not a robot.)]"
end, function(_, _, fields)
    if fields.notrobot and fields.notrobot == "true" then
        return true
    end
end)
