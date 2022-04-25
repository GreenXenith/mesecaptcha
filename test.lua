captchas = {
	"images",
	"text",
	"no",
}

minetest.register_chatcommand("test", {
	func = function(name, param)
		captcha.show(name, param ~= "" and param or captchas[math.random(1, #captchas)], {
			base = "size[9,8.8;true]position[0.5, 0.45]",
			offset = {x = 2, y = 2},
			color = "#ffffff",
		})
	end,
})
