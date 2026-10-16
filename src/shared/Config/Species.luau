-- The 16 slime species, 4 per biome. Shared by the world builder, the slime
-- model builder and (later) gameplay code. Colours match the UI canvas.
--
-- Usage: local Species = require(path)(Color3)   -- in Roblox
--        local Species = require(path)(roblox.Color3) -- in Lune

return function(C3)
	local function rgb(hex: string)
		local r = tonumber(string.sub(hex, 2, 3), 16) or 0
		local g = tonumber(string.sub(hex, 4, 5), 16) or 0
		local b = tonumber(string.sub(hex, 6, 7), 16) or 0
		return C3.fromRGB(r, g, b)
	end

	-- weight = chance in a nest of its zone, percent
	local list = {
		-- 1 · Jelly Meadow
		{ id = "blubby", name = "Blubby", zone = 1, weight = 50, shape = "round", color = rgb("#7BE3B0"), dark = rgb("#2FA36C"), features = { blush = true }, face = "sleepy" },
		{ id = "sprout", name = "Sprout", zone = 1, weight = 30, shape = "round", color = rgb("#B4E86B"), dark = rgb("#6BAF2E"), features = { leaf = true }, face = "happy" },
		{ id = "mochi", name = "Mochi", zone = 1, weight = 15, shape = "flat", color = rgb("#FFC2DA"), dark = rgb("#F07FAE"), features = { blush = true }, face = "happy" },
		{ id = "shroomy", name = "Shroomy", zone = 1, weight = 5, shape = "tall", color = rgb("#FFEFD6"), dark = rgb("#E2B47C"), features = { cap = true }, face = "smug" },
		-- 2 · Crystal Caves
		{ id = "gloop", name = "Gloop", zone = 2, weight = 50, shape = "round", color = rgb("#5CC8FF"), dark = rgb("#1F7FD0"), features = { drips = true }, face = "happy" },
		{ id = "kiki", name = "Crystal Kiki", zone = 2, weight = 30, shape = "round", color = rgb("#A8EEFF"), dark = rgb("#45AEDB"), features = { crystals = true }, face = "happy" },
		{ id = "batjelly", name = "Bat Jelly", zone = 2, weight = 15, shape = "round", color = rgb("#9A8CFF"), dark = rgb("#5A4BD6"), features = { wings = true }, face = "smug" },
		{ id = "glowy", name = "Glowy", zone = 2, weight = 5, shape = "round", color = rgb("#34407E"), dark = rgb("#1A2250"), features = { antenna = true, spots = true }, face = "happy" },
		-- 3 · Cloud Volcano
		{ id = "lenny", name = "Lava Lenny", zone = 3, weight = 50, shape = "round", color = rgb("#FF8A3D"), dark = rgb("#D9401A"), features = { cracks = true }, face = "crazy" },
		{ id = "cloudy", name = "Cloudy", zone = 3, weight = 30, shape = "round", color = rgb("#FFFFFF"), dark = rgb("#C9D8F5"), features = { cloud = true }, face = "sleepy" },
		{ id = "spark", name = "Spark", zone = 3, weight = 15, shape = "tall", color = rgb("#FFE04D"), dark = rgb("#E59A00"), features = { bolt = true }, face = "happy" },
		{ id = "jellord", name = "Obsidian Jellord", zone = 3, weight = 5, shape = "round", color = rgb("#5A5294"), dark = rgb("#1E1640"), features = { horns = true, crown = true }, face = "smug" },
		-- 4 · Glitch Zone (after Rebirth 1)
		{ id = "pixel", name = "Pixel", zone = 4, weight = 50, shape = "square", color = rgb("#3EE6B5"), dark = rgb("#12A37B"), features = {}, face = "glitch" },
		{ id = "errorbyte", name = "Errorbyte", zone = 4, weight = 30, shape = "round", color = rgb("#FF5FA8"), dark = rgb("#C2337A"), features = { glitch = true }, face = "crazy" },
		{ id = "voidy", name = "Voidy", zone = 4, weight = 15, shape = "round", color = rgb("#3A1F78"), dark = rgb("#0E0624"), features = { stars = true }, face = "sleepy" },
		{ id = "wire", name = "404", zone = 4, weight = 5, shape = "round", color = rgb("#3EE6B5"), dark = rgb("#12A37B"), features = { wire = true }, face = "glitch" },
	}

	local byId = {}
	local byZone = { {}, {}, {}, {} }
	for _, s in list do
		byId[s.id] = s
		table.insert(byZone[s.zone], s)
	end

	local tiers = {
		{ id = "Common", color = rgb("#AEB6C4") },
		{ id = "Uncommon", color = rgb("#45D46E") },
		{ id = "Rare", color = rgb("#2F9BFF") },
		{ id = "Epic", color = rgb("#A855F7") },
		{ id = "Legendary", color = rgb("#FFB020") },
		{ id = "Mythic", color = rgb("#FF3D5A") },
		{ id = "Secret", color = rgb("#FFFFFF") },
	}

	return { list = list, byId = byId, byZone = byZone, tiers = tiers, rgb = rgb }
end
