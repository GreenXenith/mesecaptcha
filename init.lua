mcaptcha = {}

mcaptcha.registered_captchas = {}
mcaptcha.registered_nocaptchas = {}

mcaptcha.registered_handlers = {
    pass = {},
    fail = {},
}

mcaptcha.states = {}

local DEVELOPMENT = false

-- Handlers
function mcaptcha.register_on_pass(func)
    table.insert(mcaptcha.registered_handlers.pass, func)
end

function mcaptcha.register_on_fail(func)
    table.insert(mcaptcha.registered_handlers.fail, func)
end

function mcaptcha.pass(player, success)
    local pname = player:get_player_name()
    local state = mcaptcha.states[pname]

    if success then
        for _, func in pairs(mcaptcha.registered_handlers.pass) do
            local stop = func(player, state.captcha)
            if stop then return end
        end
    else
        for _, func in pairs(mcaptcha.registered_handlers.fail) do
            local stop = func(player, state.captcha)
            if stop then return end
        end
    end
end

function mcaptcha.kick(player)
    minetest.kick_player(player:get_player_name(), "You failed the captcha. Please contact an administrator if you believe there has been an error.")
end

-- Regular captchas (must follow modname:captchaname convention)
function mcaptcha.register_captcha(name, create, update)
    assert(name:match("^[%w_]+:[%w_]+$"), ("Captcha '%s' does not follow modname:captchaname convention."):format(name))
    assert(not mcaptcha.registered_captchas[name], ("Captcha '%s' already exists."):format(name))

    mcaptcha.registered_captchas[name] = {
        create = create,
        update = update,
    }
end

local nofunc = function() end

-- Background nocaptchas (automatic; most follow same convention)
function mcaptcha.register_nocaptcha(name, pre, fields)
    assert(name:match("^[%w_]+:[%w_]+$"), ("noCaptcha '%s' does not follow modname:captchaname convention."):format(name))
    assert(not mcaptcha.registered_nocaptchas[name], ("noCaptcha '%s' already exists."):format(name))

    mcaptcha.registered_nocaptchas[name] = {
        pre = pre or nofunc, -- Before shown
        fields = fields or nofunc, -- On receive fields
    }
end

-- Captcha template (8x9)
local container_template =
    "container[%s,%s]" ..
        "container[0,0]" .. -- 8x8
        "%s" ..
        "container_end[]" ..

        "label[1,8.5;TEXTCOLOR(Powered by meseCaptcha)]" ..
        "image[0.1,8.1;0.8,0.8;mesecaptcha_icon.png]" ..
        "field[1000,1000;0,0;captcha;;]" .. -- Hidden field
    "container_end[]"

-- Show state as formspec
local builtin_show_form = minetest.show_formspec
local function show_state(player, state)
    builtin_show_form(player:get_player_name(), state.base.name, state.base.form:gsub("captcha%[.-%]", container_template:format(
        state.base.x, state.base.y,
        mcaptcha.registered_captchas[state.captcha].create(player, state.data)
    )):gsub("TEXTCOLOR%((.-)%)", function(m) -- Styling
        return minetest.colorize(state.base.form:match("style%[captcha;textcolor=(.-)%]") or "white", m)
    end))
end

function mcaptcha.show_captcha(pname, formname, formspec)
    local player = minetest.get_player_by_name(pname)
    assert(player)

    assert(select(2, formspec:gsub("captcha%[.*%]", "")) <= 1, "More than 1 captcha element is not supported.")

    local x, y, captcha = formspec:match("captcha%[([%d.]+),([%d.]+);(.+)%]")
    assert(mcaptcha.registered_captchas[captcha], ("Captcha '%s' does not exist."):format(captcha))

    mcaptcha.states[pname] = {
        captcha = captcha,
        base = {
            name = formname,
            form = formspec,
            x = x, y = y,
        },
        data = {
            attempts = 0,
        },
    }

    local state = mcaptcha.states[pname]

    for _, process in pairs(mcaptcha.registered_nocaptchas) do
        process.pre(player, state)
    end

    show_state(player, state)
end

-- "Easy captcha"
minetest.show_formspec = function(playername, formname, formspec)
    if formspec:find("captcha%[.-%]") then
        mcaptcha.show_captcha(playername, formname, formspec)
    else
        builtin_show_form(playername, formname, formspec)
    end
end

minetest.register_on_player_receive_fields(function(player, _, fields)
    if fields.captcha then -- Hidden field
        local pname = player:get_player_name()
        local state = mcaptcha.states[pname]
        local captcha = mcaptcha.registered_captchas[state.captcha]
        local old = state.captcha
        assert(captcha, ("Invalid captcha '%s'."):format(state.captcha))

        for _, process in pairs(mcaptcha.registered_nocaptchas) do
            local result = process.fields(player, state, fields)
            if result ~= nil then
                return mcaptcha.pass(player, result)
            end
        end

        -- Only process if the captcha didnt change
        if old == state.captcha then
            local result = captcha.update(player, state.data, fields)
            if result ~= nil then
                return mcaptcha.pass(player, result)
            end
        end

        show_state(player, state)
    end
end)

-- Activate all builtin captchas
local MODPATH = minetest.get_modpath(minetest.get_current_modname())
for _, file in pairs(minetest.get_dir_list(MODPATH .. "/captchas", false)) do
    dofile(MODPATH .. "/captchas/" .. file)
end

for _, file in pairs(minetest.get_dir_list(MODPATH .. "/captchas/nocaptcha", false)) do
    dofile(MODPATH .. "/captchas/nocaptcha/" .. file)
end

-- Default behaviors
mcaptcha.register_on_pass(function(player)
    local pname = player:get_player_name()
    minetest.close_formspec(pname, mcaptcha.states[pname].base.name)
end)

mcaptcha.register_on_fail(mcaptcha.kick)

-- Testing
if DEVELOPMENT then
    minetest.register_chatcommand("test", {
        func = function(name, param)
            mcaptcha.show_captcha(name, "captchatest", ([[
                size[10,10]
                real_coordinates[true]
                style[captcha;textcolor=#abcdef]
                captcha[1,0.5;mesecaptcha:%s]
            ]]):format(param ~= "" and param or "notrobot"))
        end,
    })
end
