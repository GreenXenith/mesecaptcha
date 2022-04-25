captcha = {}
captcha.forms = {}
captcha.handlers = {
	on_success = {},
	on_fail = {},
}
captcha.honeypot_enabled = true
captcha.close_on_pass = true
captcha.suspicious_names = true
captcha.nocaptcha = {}

local PATH = minetest.get_modpath(minetest.get_current_modname())

local suspicious = {
	"^%u%l*%d%d%d%d?$", -- Match randomly generated names
	"^[Ss]add?ie",
}
local nocaptcha = captcha.nocaptcha
local players = {}
local F = minetest.formspec_escape

-- Random string
function string.random(length)
	math.randomseed(os.time())

	local charset = {} -- [0-9a-z]
	for c = 48, 57  do table.insert(charset, string.char(c)) end
	for c = 97, 122 do table.insert(charset, string.char(c)) end

	if length > 0 then
		return string.random(length - 1) .. charset[math.random(1, #charset)]
	else
		return ""
	end
end

local function is_suspicious(name)
	for _, pattern in pairs(suspicious) do
		if name:match(pattern) then
			return true
		end
	end
end

-- noCaptcha Timer
local timers = {}
minetest.register_globalstep(function(dtime)
	if not next(timers) then
		return
	end
	for player, timer in pairs(timers) do
		timers[player] = timer + dtime;
		if timer >= 2 then
			timers[player] = nil
		end
	end
end)

function nocaptcha.track(name)
	timers[name] = 0
end

function nocaptcha.passed(name)
	local result = timers[name]
	timers[name] = nil
	return not result
end

-- Handlers
function captcha.register_on_success(func)
	table.insert(captcha.handlers.on_success, func)
end

function captcha.register_on_fail(func)
	table.insert(captcha.handlers.on_fail, func)
end

function captcha.do_handlers(handler, name, type)
	for _, func in pairs(captcha.handlers["on_"..handler]) do
		func(name, type)
	end
end

-- No human should be able to press these
function captcha.honeypot()
	if not captcha.honeypot_enabled then
		return ""
	end
	local form = [[
		button[-100,-100;0,0;honeypot;Ban me]
		button[-100,0;0,0;honeypot;Ban me]
		button[-100,100;0,0;honeypot;Ban me]
		button[0,-100;0,0;honeypot;Ban me]
		button[0,100;0,0;honeypot;Ban me]
		button[100,-100;0,0;honeypot;Ban me]
		button[100,0;0,0;honeypot;Ban me]
		button[100,100;0,0;honeypot;Ban me]
	]]
	return form
end

-- Ban handler
function captcha.ban(name)
	players[name] = nil
	local source = "mineCaptcha"
	local reason = "Client detected as bot. Please contact the administrator if you believe there has been an error."
	if sban and sban.ban_player then
		sban.ban_player(name, source, reason, "")
	elseif xban and xban.ban_player then
		xban.ban_player(name, source, "", reason)
	else
		minetest.kick_player(name, "Banned: "..reason)
		minetest.ban_player(name)
	end
end

-- Captcha register
function captcha.register_captcha(name, def)
	captcha.forms[name] = def
	if not def.on_receive_fields then
		return
	end
	minetest.register_on_player_receive_fields(function(...)
		captcha.forms[name].on_receive_fields(...)
	end)
end

-- Form offset and color (for appending to custom forms)
local function set_offset(form, offset)
	offset = offset or {x = 0, y = 0}
	return form:gsub("%[%d-%.?%d-,%d-%.?%d-;", function(coords)
		coords = coords:sub(2,-2):split(",")
		assert(next(coords) and #coords == 2, "Invalid element positions")
		return ("[%s,%s;"):format(tonumber(coords[1]) + offset.x, tonumber(coords[2]) + offset.y)
	end)
end

-- Get random captcha
function captcha.get_random()
	local choose = {}
	for form in pairs(captcha.forms) do
		if form ~= "no" then
			choose[#choose+1] = form
		end
	end
	return choose[math.random(1,#choose)]
end

-- Show captcha
function captcha.show(name, type, style)
	if not minetest.get_player_by_name(name) or not captcha.forms[type] or not style.base then
		return
	end
	-- Start noCaptcha
	if not players[name] then
		nocaptcha.track(name)
	end

	-- Get previous data or new data
	local data = players[name] or captcha.forms[type].get(name, style)
	if not data then
		return
	end
	players[name] = data
	local watermark = ([[
		label[2.2,5;%s]
		image[4.5,4.75;0.75,0.75;captcha_icon.png]
	]]):format(minetest.colorize(style.color or "white", "Powered by mineCaptcha"))
	local page = captcha.forms[type].form(data)
	minetest.show_formspec(name, "captcha:"..type, style.base..set_offset(page..watermark, style.offset)..captcha.honeypot())
end

-- New random captcha
function captcha.show_new(name)
	local style = players[name].style
	players[name] = nil
	nocaptcha.track(name)
	minetest.after(1, function() captcha.show(name, captcha.get_random(), style) end)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname:match("^captcha:") then
		local name = player:get_player_name()
		-- Show captcha until passed
		if fields.quit then
			-- Once for rapid-quit
			minetest.after(0.01, function()
				if players[name] and players[name].style then
					captcha.show(name, formname:sub(9), players[name].style)
				end
			end)
			-- Twice to handle freak bypasses (it happens)
			minetest.after(0.05, function()
				if players[name] and players[name].style then
					captcha.show(name, formname:sub(9), players[name].style)
				end
			end)
			return
		end
		-- New pattern
		if fields.refresh then
			local style = players[name].style
			players[name] = nil
			captcha.show(name, formname:sub(9), style)
			return
		end
		if fields.honeypot then
			captcha.ban(name)
			return
		end
	end
end)

-- Select images
captcha.register_captcha("images", {
	form = function(input)
		local added = 0
		local form = ([[
			label[1,0.5;%s]
			button[1.5,4;2,1;submit;Submit]
			image_button[4,2;1,1;captcha_refresh.png;refresh;]
			tooltip[refresh;Refresh Captcha]
		]]):format(minetest.colorize(input.style.color or "white", "Select all images with "..input.target.desc))

		for x = 1, 3 do
			for y = 1, 3 do
				added = added + 1
				local overlay = ""
				if input.images[added].selected then
					overlay = "^captcha_selected.png"
				end
				form = form .. "image_button["..x..","..y..";1,1;"..input.images[added].image..overlay..";img"..added..";]"
			end
		end

		return form
	end,
	-- Data for form
	get = function(name, style)
		-- Populate textures
		local nodes = {
			"wool:red",
			"wool:yellow",
			"wool:green",
			"wool:blue",
			{"default_chest_front.png", "Chest"},
			{"default_furnace_front.png", "Furnace"},
			"dirt",
			"stone",
			"cobble",
			"bronzeblock",
			"steelblock",
			"mese",
			"diamondblock",
			"brick",
			"stone_with_coal",
			"stone_with_gold",
			"stone_with_iron",
			"sand",
			"snowblock",
			"wood",
			"tree",
			"cactus",
			"gravel",
			"goldblock",
			"leaves",
			"obsidian",
			"glass",
		}
		local textures = {}
		for _, i in pairs(nodes) do
			if type(i) == "table" then
				textures[#textures+1] = {image=i[1], desc=i[2]}
			else
				local node
				if i:find(":") then
					node = i
				else
					node = "default:"..i
				end
				local def = minetest.registered_items[node]
				if def then
					textures[#textures+1] = {image=def.tiles[1], desc=def.description}
				end
			end
		end

		-- Shuffle func
		local function shuffle(tbl)
			math.randomseed(os.time())
			local len, random = #tbl, math.random
			for i = len, 2, -1 do
				local j = random(1, i)
				tbl[i], tbl[j] = tbl[j], tbl[i]
			end
			return tbl
		end

		-- Choose textures
		local count = math.random(2,3)
		local choose = textures[math.random(1,#textures)]

		-- Create form data
		local images = {}
		local added = 0

		for i = count + 1, 9 do
			local select = textures[math.random(1,#textures)]
			while select == choose do
				select = textures[math.random(1,#textures)]
			end
			images[i] = {image=select.image}
		end

		for i = 1, count do
			images[i] = {image=choose.image}
		end

		images = shuffle(images)

		return {style = style, images = images, target = {image = choose.image, desc = choose.desc, count = count}}
	end,
	on_receive_fields = function(player, formname, fields)
		if formname:match("^captcha:images") then
			local name = player:get_player_name()
			local data = players[name]
			if not data then
				return
			end
			local images = data.images
			local target = data.target
			if fields.submit then
				local selected = 0
				for _, img in pairs(images) do
					if img.selected then
						if img.image == target.image then
							selected = selected + 1
						else
							selected = selected - 1
						end
					end
				end
				if selected == target.count then
					captcha.do_handlers("success", name, "images")
				end
				captcha.do_handlers("fail", name, "images")
				return
			end
			for i in pairs(fields) do
				if i:match("img%d") then
					local n = tonumber(i:match("%d"))
					images[n].selected = not images[n].selected
					captcha.show(name, "images", data.style)
					return
				end
			end
		end
	end
})

-- Type shown text
captcha.register_captcha("text", {
	form = function(input)
		return ([[
			label[1.5,1;%s]
			field[1.3,3;3,1;input;;]
			button[1.5,3.6;2,1;submit;Submit]
			field_close_on_enter[input;false]
			image_button[4,2.8;0.8,0.8;captcha_refresh.png;refresh;]
			tooltip[refresh;Refresh Captcha]
		]]..input.image):format(minetest.colorize(input.style.color or "white", "Enter the following:"))
	end,
	get = function(name, style)
		-- Distortions
        local effects = {
            function()
                return ("^[colorize\\:#%06X\\:%s"):format(math.random() * 0xFFFFFF, math.random(10, 100))
            end,
            function()
                return "^[brighten"
            end,
            function()
                return "^[invert\\:" .. ({"r", "g", "b", "rg", "rb", "bg", "rgb"})[math.random(1, 7)]
            end,
        }

        local CHAR_W = 7
        local len = math.random(4, 6)
        local str = ""
        local img = "[combine:" .. len * CHAR_W .. "x8"

        for i = 0, len - 1 do
            local idx = math.random(1, 36)
            local char = ("0123456789abcdefghijklmnopqrstuvwxyz"):sub(idx, idx)
            local fx = ({"", effects[1]()})[math.random(1, 2)] .. ({"", effects[2]()})[math.random(1, 2)] .. ({"", effects[3]()})[math.random(1, 2)]

            str = str .. char
            img = img .. (":%s,0=([combine\\:8x8\\:%s,0=captcha_alphabet.png%s)"):format(i * CHAR_W, (idx - 1) * -CHAR_W, fx)
        end

        local element = ("image[%s,1.8;%s,0.7;%s]"):format((0.2 * (8 - len)) * 2, len * 0.7, F(img))

		return {style = style, image = element, phrase = str}
	end,
	on_receive_fields = function(player, formname, fields)
		if formname:match("^captcha:text") then
			local name = player:get_player_name()
			local phrase = players[name].phrase
			if fields.input or fields.submit then
				if fields.input:lower() == phrase then
					captcha.do_handlers("success", name, "text")
				end
			end
		end
	end
})

-- I am not a robot
captcha.register_captcha("no", {
	form = function(input)
		return ([[
			checkbox[1.5,2;notrobot;%s]
		]]):format(minetest.colorize(input.style.color or "white", "I am not a robot"))
	end,
	get = function(name, style)
		timers[name] = 0
		return {style = style}
	end,
	on_receive_fields = function(player, formname, fields)
		if formname:match("^captcha:no") then
			local name = player:get_player_name()
			if fields.notrobot and fields.notrobot == "true" and players[name] then
				if nocaptcha.passed(name) then
					captcha.do_handlers("success", name, "no")
				else
					captcha.do_handlers("fail", name, "no")
				end
			end
		end
	end
})

-- Default behaviors
captcha.register_on_success(function(name, type)
	if (type == "no" and captcha.suspicious_names and is_suspicious(name)) or not nocaptcha.passed(name) then
		captcha.show_new(name)
		return
	end
	players[name] = nil
	if captcha.close_on_pass then
		minetest.after(1, function()
			minetest.close_formspec(name, "captcha:"..type)
		end)
	end
end)

captcha.register_on_fail(function(name, type)
	if type == "no" then
		captcha.show_new(name)
	end
end)

-- dofile(PATH .. "/test.lua")
