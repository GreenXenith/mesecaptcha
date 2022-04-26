-- "Select all images that contain [...]" or "Select the [...]"
-- Presents 9 images for the user to choose from.

-- TODO: Stop depending on default
-- TODO: Make this configurable
local images = {
    {"wool_red.png", "Red Wool"},
    {"wool_yellow.png", "Yellow Wool"},
    {"wool_green.png", "Green Wool"},
    {"wool_blue.png", "Blue Wool"},
    {"default_chest_front.png", "Chest"},
    {"default_furnace_front.png", "Furnace"},
    {"default_dirt.png", "Dirt"},
    {"default_stone.png", "Stone"},
    {"default_cobble.png", "Cobble"},
    {"default_bronze_block.png", "Bronze"},
    {"default_steel_block.png", "Steel"},
    {"default_mese_block.png", "Mese"},
    {"default_diamond_block.png", "Diamond"},
    {"default_brick.png", "Brick"},
    {"default_stone.png^default_mineral_coal.png", "Coal Ore"},
    {"default_stone.png^default_mineral_gold.png", "Gold Ore"},
    {"default_stone.png^default_mineral_iron.png", "Iron Ore"},
    {"default_sand.png", "Sand"},
    {"default_snow.png", "Snow"},
    {"default_wood.png", "Planks"},
    {"default_tree.png", "Tree"},
    {"default_cactus_side.png", "Cactus"},
    {"default_gravel.png", "Gravel"},
    {"default_gold_block.png", "Gold"},
    {"default_leaves.png", "Leaves"},
    {"default_obsidian.png", "Obsidian"},
    {"default_glass.png", "Glass"},
}

-- Generate 9 images with at least 2 sets of 3
local function generate_grid_all()
    local grid = {}
    local choice

    for i = 1, 4 do
        choice = images[math.random(1, #images)]
        for _ = 1, i do
            table.insert(grid, math.random(1, #grid + 1), {
                name = choice[2],
                image = choice[1],
                selected = false,
            })
        end
    end

    grid[10] = nil
    return grid, choice[2]
end

-- "Select all images containing [...]"
mcaptcha.register_captcha("mesecaptcha:identify_all", function(_, data)
    if not data.grid then
        data.grid, data.choice = generate_grid_all()
    end

    local form = ([[
        label[2,1;TEXTCOLOR(Select all images containing %s.)]
        button[1.5,6.5;4,1;submit;Submit]
        image_button[5.5,6.5;1,1;mesecaptcha_refresh.png;refresh;]
        tooltip[refresh;Refresh Captcha]
    ]]):format(data.choice)

    for i = 0, #data.grid - 1 do
        local slot = data.grid[i + 1]
        local img = slot.image .. (slot.selected and "^captcha_selected.png" or "")
        form = form .. ("image_button[%s,%s;1.5,1.5;%s;select_%s;]"):format(1.5 + (i % 3) * 1.75, 1.25 + math.floor(i / 3) * 1.75, img, i + 1)
    end

    return form
end, function(_, data, fields)
    if fields.refresh then
        data.grid, data.choice = generate_grid_all()
    elseif fields.submit then
        for _, slot in pairs(data.grid) do
            -- Only the correct ones. No more, no less.
            if ((slot.name == data.choice) and not slot.selected) or ((slot.name ~= data.choice) and slot.selected) then
                data.grid, data.choice = generate_grid_all()
                data.attempts = data.attempts + 1

                if data.attempts >= 5 then
                    return false
                end

                return
            end
        end

        return true
    else -- Select the item
        for field in pairs(fields) do
            local slot = tonumber(field:match("^select_(%d)$"))
            if slot then
                data.grid[slot].selected = not data.grid[slot].selected
            end
        end
    end
end)

local function generate_grid_one()
    local grid = {}
    local choices = {}

    while #grid < 9 do
        local choice = math.random(1, #images)
        if not choices[choice] then
            choices[choice] = true
            table.insert(grid, {
                name = images[choice][2],
                image = images[choice][1]
            })
        end
    end

    return grid, grid[math.random(1, 9)].name
end

-- "Select the [...]"
mcaptcha.register_captcha("mesecaptcha:identify_one", function(_, data)
    if not data.grid then
        data.grid, data.choice = generate_grid_one()
    end

    local form = ([[
        label[3,1;TEXTCOLOR(Select the %s.)]
        image_button[5.5,6.5;1,1;mesecaptcha_refresh.png;refresh;]
    ]]):format(data.choice)

    for i = 0, #data.grid - 1 do
        form = form .. ("image_button[%s,%s;1.5,1.5;%s;select_%s;]"):format(1.5 + (i % 3) * 1.75, 1.25 + math.floor(i / 3) * 1.75, data.grid[i + 1].image, i + 1)
    end

    return form
end, function(_, data, fields)
    if fields.refresh then
        data.grid, data.choice = generate_grid_one()
    else
        for field in pairs(fields) do
            local slot = tonumber(field:match("^select_(%d)$"))
            if slot then
                if data.grid[slot].name == data.choice then
                    return true
                else
                    data.grid, data.choice = generate_grid_one()
                    data.attempts = data.attempts + 1

                    if data.attempts >= 5 then
                        return false
                    end
                end
            end
        end
    end
end)
