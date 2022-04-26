-- "Repeat After Me"
-- Generates a random string of distorted characters for the user to repeat

local math_random = math.random

-- Distortions
local effects = {
    function()
        return ("^[colorize\\:#%06X\\:%s"):format(math_random() * 0xFFFFFF, math_random(10, 100))
    end,
    function()
        return "^[brighten"
    end,
    function()
        return "^[invert\\:" .. ({"r", "g", "b", "rg", "rb", "bg", "rgb"})[math_random(1, 7)]
    end,
}

local base_form = [[
    label[3,2.5;TEXTCOLOR(Enter the following:)]
    field[2,4.5;4,0.5;input;;]
    button[2,5;3,1;submit;Submit]
    field_close_on_enter[input;false]
    image_button[5,5;1,1;mesecaptcha_refresh.png;refresh;]
    tooltip[refresh;Refresh Captcha]
]]

local function generate_text()
    local CHAR_W = 7
    local len = math_random(4, 6)
    local str = ""
    local img = "[combine:" .. len * CHAR_W .. "x8"

    for i = 0, len - 1 do
        local idx = math_random(1, 36)
        local char = ("0123456789abcdefghijklmnopqrstuvwxyz"):sub(idx, idx)
        local fx = ""
        for j = 1, #effects do if math.random() > 0.5 then fx = fx .. effects[j]() end end -- Randomized effects

        str = str .. char
        img = img .. (":%s,0=([combine\\:8x8\\:%s,0=mesecaptcha_alphabet.png%s)"):format(i * CHAR_W, (idx - 1) * -CHAR_W, fx)
    end

    return str, ("image[%s,3;%s,1;%s]"):format(4 - len / 2, len, minetest.formspec_escape(img))
end

-- Type shown text
mcaptcha.register_captcha("mesecaptcha:repeat", function(_, data)
    if not data.phrase then
        data.phrase, data.element = generate_text()
    end

    return base_form .. data.element
end, function(_, data, fields)
    if fields.refresh then
        data.phrase, data.element = generate_text()
    elseif fields.input ~= "" then
        if fields.input:lower() == data.phrase then
            return true
        else
            data.phrase, data.element = generate_text()
            data.attempts = data.attempts + 1

            if data.attempts >= 5 then
                return false -- Fail after 5 attempts
            end
        end
    end
end)
