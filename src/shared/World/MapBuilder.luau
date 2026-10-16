-- Builds the Greedy Slimes island out of plain parts. Runs in Roblox Studio
-- (command bar / MCP) and in Lune (tools/build_place.luau writes the .rbxl).
--
-- local World = require(MapBuilder)(env, { Species = Species, buildSlime = buildSlime })
-- World.buildMap(workspace); World.applyLighting(game.Lighting)
--
-- Layout (studs, centre of the island = 0,0,0, north = -Z):
--   plaza r<45 · base ring r<95 (8 plots, safe) · meadow r<175 · caves r<240 · volcano r<310
--   Glitch Zone floats north-east, reached by a rainbow bridge after Rebirth 1.
--   Each ring sits 1 stud lower than the one inside it, so the rising Tide (sea up to y=6.6)
--   floods the zones but never the base ring (y=7).

return function(R, deps)
	local Instance, Vector3, CFrame, Color3, Enum, UDim2 = R.Instance, R.Vector3, R.CFrame, R.Color3, R.Enum, R.UDim2
	local Species, buildSlime = deps.Species, deps.buildSlime
	local rgb = Species.rgb
	local SMOOTH = Enum.Material.SmoothPlastic
	local NEON = Enum.Material.Neon
	local CYL = Enum.PartType.Cylinder
	local BALL = Enum.PartType.Ball
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis from X to Y

	local C = {
		ink = rgb("#1E1640"), pink = rgb("#FF5FA8"), mint = rgb("#3EE6B5"), coin = rgb("#FFC93C"),
		cream = rgb("#FFF6E5"), sand = rgb("#FFE6A8"), meadow = rgb("#8EF0C6"), caves = rgb("#8FD3F0"),
		volcano = rgb("#CDB4FF"), glitch = rgb("#24124A"), sea = rgb("#4FC3F7"), seabed = rgb("#E8D9A8"),
		rock = rgb("#A7A3B8"), lava = rgb("#FF8A3D"), lavaRim = rgb("#FFE04D"), cone = rgb("#8E6CD9"),
		coneDark = rgb("#7A58C4"), wall = rgb("#FF8AD0"), white = Color3.new(1, 1, 1), purple = rgb("#A855F7"),
		sky = rgb("#6FCBFF"), dusk = rgb("#3B3561"),
	}
	local ACCENTS = { rgb("#FF5FA8"), rgb("#3EE6B5"), rgb("#FFC93C"), rgb("#2F9BFF"), rgb("#A855F7"), rgb("#FF8A3D"), rgb("#45D46E"), rgb("#FF3D5A") }

	-- deterministic random (Park-Miller), same result in Studio and Lune
	local seed = 20261016
	local function rand()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local function range(a, b)
		return a + (b - a) * rand()
	end

	local function new(class, props, parent)
		local inst = Instance.new(class)
		for k, v in props do
			inst[k] = v
		end
		inst.Parent = parent
		return inst
	end

	local function folder(name, parent)
		return new("Folder", { Name = name }, parent)
	end

	local function part(parent, name, size, cf, color, material, opts)
		opts = opts or {}
		local p = Instance.new(opts.wedge and "WedgePart" or "Part")
		if opts.shape then
			p.Shape = opts.shape
		end
		p.Name = name
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or SMOOTH
		if opts.transparency then
			p.Transparency = opts.transparency
		end
		if opts.collide == false then
			p.CanCollide = false
		end
		if opts.ellipsoid then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		end
		if opts.attrs then
			for k, v in opts.attrs do
				p:SetAttribute(k, v)
			end
		end
		p.Parent = parent
		return p
	end

	-- CFrame.lookAt built from vectors: Lune's built-in lookAt mirrors some angles,
	-- and this gives the same result as Roblox everywhere.
	local function lookAt(at, target)
		local look = (target - at).Unit
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		local up = right:Cross(look)
		return CFrame.new(at.X, at.Y, at.Z, right.X, up.X, -look.X, right.Y, up.Y, -look.Y, right.Z, up.Z, -look.Z)
	end

	local function polar(r, deg, y)
		local a = math.rad(deg)
		return Vector3.new(r * math.cos(a), y, r * math.sin(a))
	end

	-- a flat cylinder whose top surface is centred at `top`
	local function disc(parent, name, r, top, thick, color, material, opts)
		opts = opts or {}
		opts.shape = CYL
		return part(parent, name, Vector3.new(thick, r * 2, r * 2), CFrame.new(top.X, top.Y - thick / 2, top.Z) * UP, color, material, opts)
	end

	-- CFrame at pos (y ignored) whose LookVector points away from the island centre
	local function outward(pos, deg)
		local a = math.rad(deg)
		local flat = Vector3.new(pos.X, 0, pos.Z)
		return lookAt(flat, flat + Vector3.new(math.cos(a), 0, math.sin(a)))
	end

	local function facingCentre(pos)
		return lookAt(pos, Vector3.new(0, pos.Y, 0))
	end

	local function light(parent, color, rangeStuds, brightness)
		return new("PointLight", { Color = color, Range = rangeStuds, Brightness = brightness, Shadows = false }, parent)
	end

	local function billboard(adornee, lines, w, h, offsetY, maxDistance)
		local gui = new("BillboardGui", {
			Name = "Sign",
			Size = UDim2.fromScale(w, h),
			StudsOffset = Vector3.new(0, offsetY, 0),
			MaxDistance = maxDistance or 250,
			LightInfluence = 0,
			Adornee = adornee,
		}, adornee)
		local n = #lines
		for i, line in lines do
			new("TextLabel", {
				Size = UDim2.fromScale(1, 1 / n),
				Position = UDim2.fromScale(0, (i - 1) / n),
				BackgroundTransparency = 1,
				Text = line.text,
				Font = line.font or Enum.Font.LuckiestGuy,
				TextScaled = true,
				TextColor3 = line.color or C.white,
				TextStrokeColor3 = C.ink,
				TextStrokeTransparency = 0,
			}, gui)
		end
		return gui
	end

	local function board(parent, name, cf, w, h, color, lines)
		local p = part(parent, name, Vector3.new(w, h, 1), cf, color)
		local gui = new("SurfaceGui", {
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0,
		}, p)
		local n = #lines
		for i, line in lines do
			new("TextLabel", {
				Size = UDim2.fromScale(0.92, 0.9 / n),
				Position = UDim2.fromScale(0.04, 0.05 + (i - 1) * 0.9 / n),
				BackgroundTransparency = 1,
				Text = line.text,
				Font = line.font or Enum.Font.LuckiestGuy,
				TextScaled = true,
				TextColor3 = line.color or C.white,
				TextStrokeColor3 = C.ink,
				TextStrokeTransparency = line.stroke == false and 1 or 0,
			}, gui)
		end
		return p
	end

	local function pickSpecies(zone)
		local pool = Species.byZone[zone]
		local roll = rand() * 100
		local acc = 0
		for _, s in pool do
			acc += s.weight
			if roll <= acc then
				return s
			end
		end
		return pool[1]
	end

	---------------------------------------------------------------------------
	-- pieces
	---------------------------------------------------------------------------

	local function ringWall(parent, r, y0, h, gates, gateWidth)
		local n = math.floor(2 * math.pi * r / 8)
		local seg = 2 * math.pi * r / n
		local half = math.deg((gateWidth / 2 + seg / 2) / r)
		for i = 0, n - 1 do
			local deg = (i + 0.5) * 360 / n
			local open = false
			for _, g in gates do
				if math.abs(((deg - g + 180) % 360) - 180) < half then
					open = true
				end
			end
			if not open then
				part(parent, "Wall", Vector3.new(seg * 1.03, h, 1.5), outward(polar(r, deg, 0), deg) * CFrame.new(0, y0 + h / 2, 0), C.wall, Enum.Material.Glass, { transparency = 0.45 })
			end
		end
	end

	local function gate(parent, r, deg, lowTop, width, attrs, lines)
		local m = new("Model", { Name = "Gate" }, parent)
		local cf = outward(polar(r, deg, 0), deg)
		for side = -1, 1, 2 do
			part(m, "Pillar", Vector3.new(2.4, 13, 2.4), cf * CFrame.new(side * (width / 2 + 1.2), lowTop + 6.5, 0), C.pink)
		end
		local beam = part(m, "Beam", Vector3.new(width + 4.8, 2, 2.4), cf * CFrame.new(0, lowTop + 13, 0), C.coin, NEON)
		part(m, "Barrier", Vector3.new(width, 11, 0.6), cf * CFrame.new(0, lowTop + 5.5, 0), C.pink, NEON, { transparency = 0.7, attrs = attrs })
		part(m, "Ramp", Vector3.new(width, 1, 6), cf * CFrame.new(0, lowTop + 0.5, -3), C.cream, SMOOTH, { wedge = true })
		billboard(beam, lines, 16, 4, 4, 300)
		return m
	end

	local function nest(parent, pos, zone, tier, index, speciesOverride)
		local m = new("Model", { Name = "Nest" .. index }, parent)
		disc(m, "Pad", 3.2, pos + Vector3.new(0, 0.35, 0), 0.4, C.pink, NEON, { transparency = 0.15, attrs = { Nest = true, Zone = zone } })
		for i = 0, 6 do
			local a = i * 360 / 7 + 10
			local d = range(1.5, 2.1)
			part(m, "NestRock", Vector3.new(d, d, d), CFrame.new(pos + polar(3.9, a, d * 0.4)), C.rock, Enum.Material.Slate, { shape = BALL })
		end
		local sp = speciesOverride or pickSpecies(zone)
		buildSlime(sp.id, { cf = facingCentre(pos + Vector3.new(0, 0.55, 0)), size = 3.2, tier = tier, parent = m })
		return m
	end

	local function guardian(parent, pos, zone, index)
		local m = new("Model", { Name = "Slimeater" .. index }, parent)
		local cf = facingCentre(pos)
		local body = part(m, "Body", Vector3.new(8, 6, 8), cf * CFrame.new(0, 3, 0), rgb("#3B1D2E"), SMOOTH, { ellipsoid = true, attrs = { Guardian = true, Zone = zone, Asleep = true } })
		part(m, "Belly", Vector3.new(5, 3.4, 1), cf * CFrame.new(0, 2.3, -3.55), rgb("#5A2E44"), SMOOTH, { ellipsoid = true })
		for side = -1, 1, 2 do
			part(m, "SleepyEye", Vector3.new(1.4, 0.22, 0.3), cf * CFrame.new(side * 1.5, 4.3, -3.25), rgb("#FF3D5A"), NEON)
		end
		part(m, "Mouth", Vector3.new(3.8, 0.7, 0.4), cf * CFrame.new(0, 2.9, -3.75), C.ink)
		for i = -1.5, 1.5, 1 do
			part(m, "Tooth", Vector3.new(0.45, 0.45, 0.3), cf * CFrame.new(i, 2.55, -3.85) * CFrame.Angles(0, 0, math.rad(45)), C.white)
		end
		m.PrimaryPart = body
		billboard(body, { { text = "Zzz", font = Enum.Font.FredokaOne } }, 4, 1.6, 4.6, 90)
		return m
	end

	local function safeRock(parent, pos, index)
		local m = new("Model", { Name = "SafeRock" .. index }, parent)
		part(m, "Rock", Vector3.new(11, 9, 9), CFrame.new(pos.X, pos.Y + 5.5, pos.Z) * UP, C.rock, Enum.Material.Slate, { shape = CYL, attrs = { SafeRock = true } })
		local top = disc(m, "SafeTop", 4.6, pos + Vector3.new(0, 11.15, 0), 0.3, C.mint, NEON)
		local toCentre = math.deg(math.atan2(-pos.Z, -pos.X))
		for k = 0, 3 do
			part(m, "Step", Vector3.new(3, 1, 3), CFrame.new(pos + polar(6, toCentre + k * 50, 2.5 * (k + 1) - 0.5)), C.cream)
		end
		billboard(top, { { text = "SAFE", color = C.mint } }, 5, 1.6, 2.6, 160)
		return m
	end

	local function launchPad(parent, pos, index)
		local p = disc(parent, "LaunchPad" .. index, 3, pos + Vector3.new(0, 0.6, 0), 0.6, C.mint, NEON, { attrs = { LaunchPad = true, LaunchTo = "Base" } })
		part(parent, "LaunchArrow", Vector3.new(2, 1, 3.4), facingCentre(pos + Vector3.new(0, 1.1, 0)), C.white, SMOOTH, { wedge = true, collide = false })
		billboard(p, { { text = "JUMP HOME", color = C.mint } }, 7, 1.6, 3.2, 120)
		return p
	end

	local function tree(parent, pos, s)
		local m = new("Model", { Name = "Tree" }, parent)
		part(m, "Trunk", Vector3.new(4 * s, 1.3 * s, 1.3 * s), CFrame.new(pos.X, pos.Y + 2 * s, pos.Z) * UP, rgb("#9C6B3E"), Enum.Material.Wood, { shape = CYL })
		part(m, "Leaves", Vector3.new(4.6 * s, 4.6 * s, 4.6 * s), CFrame.new(pos + Vector3.new(0, 5 * s, 0)), rgb("#4FC77A"), SMOOTH, { shape = BALL })
		part(m, "Leaves", Vector3.new(3.4 * s, 3.4 * s, 3.4 * s), CFrame.new(pos + Vector3.new(1.6 * s, 4.3 * s, 0.8 * s)), rgb("#6CCF5A"), SMOOTH, { shape = BALL })
		part(m, "Leaves", Vector3.new(3 * s, 3 * s, 3 * s), CFrame.new(pos + Vector3.new(-1.3 * s, 4.6 * s, -1 * s)), rgb("#3DB46A"), SMOOTH, { shape = BALL })
	end

	local function crystalCluster(parent, pos, withLight)
		local m = new("Model", { Name = "Crystals" }, parent)
		local colors = { rgb("#7FD4FF"), rgb("#A855F7"), rgb("#E6FBFF") }
		for i = 1, 3 do
			local h = range(2.5, 6)
			local w = range(1.2, 2.2)
			local p = part(m, "Crystal", Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(range(-1.5, 1.5), h / 2 - 0.3, range(-1.5, 1.5))) * CFrame.Angles(range(-0.35, 0.35), range(0, 3), range(-0.35, 0.35)), colors[i], i == 2 and NEON or Enum.Material.Glass, { transparency = i == 2 and 0 or 0.15 })
			if withLight and i == 2 then
				light(p, colors[1], 16, 1.2)
			end
		end
	end

	local function stalagmite(parent, pos)
		for k = 0, 2 do
			local r = 2.4 - k * 0.75
			disc(parent, "Stalagmite", r, pos + Vector3.new(0, 3 * (k + 1), 0), 3, rgb("#6FA9C9"))
		end
	end

	local function lavaPool(parent, pos, r)
		disc(parent, "LavaRim", r + 1.2, pos + Vector3.new(0, 0.15, 0), 0.3, C.lavaRim)
		local lava = disc(parent, "Lava", r, pos + Vector3.new(0, 0.25, 0), 0.3, C.lava, NEON, { attrs = { Lava = true } })
		light(lava, C.lava, r * 3, 1.5)
	end

	local function geyser(parent, pos)
		disc(parent, "GeyserVent", 2.2, pos + Vector3.new(0, 1.4, 0), 1.4, C.dusk, SMOOTH, { attrs = { Geyser = true, EruptEverySeconds = 12 } })
		disc(parent, "GeyserGlow", 1.2, pos + Vector3.new(0, 1.45, 0), 0.1, C.lava, NEON)
	end

	local function cloud(parent, pos, s)
		local m = new("Model", { Name = "Cloud" }, parent)
		for _, o in { { 0, 0, 0, 1 }, { 1.1, -0.2, 0.3, 0.8 }, { -1.1, -0.25, -0.2, 0.75 } } do
			local d = 8 * s * o[4]
			part(m, "Puff", Vector3.new(d, d, d), CFrame.new(pos + Vector3.new(o[1] * 5 * s, o[2] * 5 * s, o[3] * 5 * s)), C.white, SMOOTH, { shape = BALL, collide = false })
		end
	end

	---------------------------------------------------------------------------
	-- the map
	---------------------------------------------------------------------------

	local function buildMap(parent)
		local map = folder("Map", parent)

		-- ground and the Tide
		local ground = folder("Ground", map)
		disc(ground, "Seabed", 900, Vector3.new(0, -6, 0), 2, C.seabed, Enum.Material.Sand)
		disc(ground, "Sea", 900, Vector3.new(0, 0, 0), 2, C.sea, Enum.Material.Glass, {
			transparency = 0.3,
			collide = false,
			attrs = { TideLowY = 0, TideHighY = 6.6, TideEverySeconds = 150, TideWarningSeconds = 20 },
		})
		disc(ground, "Beach", 322, Vector3.new(0, 2.5, 0), 6, C.sand, Enum.Material.Sand)
		disc(ground, "VolcanoRing", 310, Vector3.new(0, 4, 0), 4, C.volcano, SMOOTH, { attrs = { Zone = 3 } })
		disc(ground, "CavesRing", 240, Vector3.new(0, 5, 0), 4, C.caves, SMOOTH, { attrs = { Zone = 2 } })
		disc(ground, "MeadowRing", 175, Vector3.new(0, 6, 0), 4, C.meadow, SMOOTH, { attrs = { Zone = 1 } })
		disc(ground, "SafeLine", 97, Vector3.new(0, 6.9, 0), 3.8, C.white)
		disc(ground, "BaseRing", 95, Vector3.new(0, 7, 0), 4, C.sand, SMOOTH, { attrs = { SafeZone = true } })
		disc(ground, "Plaza", 45, Vector3.new(0, 7.25, 0), 1, C.cream, SMOOTH, { attrs = { SafeZone = true } })

		-- jelly walls with chokepoint gates
		local walls = folder("Walls", map)
		ringWall(walls, 175, 5, 9, { 45, 135, 225, 315 }, 16)
		ringWall(walls, 240, 4, 9, { 0, 90, 180, 270 }, 16)
		local gates = folder("Gates", map)
		for _, d in { 45, 135, 225, 315 } do
			gate(gates, 175, d, 5, 16, { SpeedGate = true, RequiredSpeed = 12, Zone = 2 }, { { text = "CRYSTAL CAVES", color = C.sky }, { text = "SPEED 12", color = C.coin } })
		end
		for _, d in { 0, 90, 180, 270 } do
			gate(gates, 240, d, 4, 16, { SpeedGate = true, RequiredSpeed = 30, Zone = 3 }, { { text = "CLOUD VOLCANO", color = C.volcano }, { text = "SPEED 30", color = C.coin } })
		end

		-- plaza
		local plaza = folder("Plaza", map)
		disc(plaza, "FountainRim", 10, Vector3.new(0, 8.6, 0), 1.4, C.white)
		disc(plaza, "FountainWater", 8.6, Vector3.new(0, 8.75, 0), 0.3, C.sky, Enum.Material.Glass, { transparency = 0.15 })
		local column = disc(plaza, "JellyColumn", 2.2, Vector3.new(0, 16, 0), 7.3, C.pink, NEON, { transparency = 0.2 })
		light(column, C.pink, 24, 1.5)
		buildSlime("blubby", { cf = CFrame.new(0, 16, 0) * CFrame.Angles(0, math.pi, 0), size = 9, tier = 7, skin = "rainbow", parent = plaza })
		new("SpawnLocation", {
			Name = "Spawn",
			Size = Vector3.new(10, 1, 10),
			CFrame = CFrame.new(0, 7.75, 21),
			Anchored = true,
			Neutral = true,
			Duration = 0,
			Color = C.pink,
			Material = SMOOTH,
			TopSurface = Enum.SurfaceType.Smooth,
		}, plaza)

		-- the Index gallery: all 16 species on the south side of the plaza
		local gallery = folder("IndexGallery", plaza)
		for i, sp in Species.list do
			local deg = 25 + (i - 1) * (130 / 15)
			local pos = polar(37, deg, 7.75)
			disc(gallery, "IndexPedestal", 1.7, pos + Vector3.new(0, 1, 0), 1, C.white)
			disc(gallery, "IndexRim", 1.9, pos + Vector3.new(0, 0.55, 0), 0.5, ACCENTS[sp.zone], NEON)
			buildSlime(sp.id, { cf = facingCentre(pos + Vector3.new(0, 1, 0)), size = 2.6, tier = sp.zone + 1, label = true, parent = gallery })
		end

		-- north side: update board, leaderboard, shop, rebirth altar, codes
		local updatePos = polar(37, 270, 13)
		board(plaza, "UpdateBoard", lookAt(updatePos, Vector3.new(0, 13, 0)), 20, 10, C.ink, {
			{ text = "NEXT UPDATE", color = C.coin },
			{ text = "SATURDAY · 1d 22h", color = C.white },
			{ text = "Glitch Zone slimes!", color = C.mint, font = Enum.Font.FredokaOne },
		})
		local lbPos = polar(36, 225, 13)
		board(plaza, "Leaderboard", lookAt(lbPos, Vector3.new(0, 13, 0)), 11, 12, C.cream, {
			{ text = "GREEDIEST", color = C.pink },
			{ text = "1. sugarbyte · 94s", color = C.ink, font = Enum.Font.FredokaOne, stroke = false },
			{ text = "2. boba_slap · 81s", color = C.ink, font = Enum.Font.FredokaOne, stroke = false },
			{ text = "3. jamjar · 77s", color = C.ink, font = Enum.Font.FredokaOne, stroke = false },
		})
		local shopPos = polar(34, 315, 7.75)
		local shopCf = lookAt(shopPos, Vector3.new(0, 7.75, 0))
		local counter = part(plaza, "ShopCounter", Vector3.new(10, 3.4, 4), shopCf * CFrame.new(0, 1.7, 0), C.pink, SMOOTH, { attrs = { Shop = true } })
		for k = 0, 4 do
			part(plaza, "Awning", Vector3.new(2.2, 0.6, 6), shopCf * CFrame.new(-4.4 + k * 2.2, 8, 1) * CFrame.Angles(math.rad(-15), 0, 0), k % 2 == 0 and C.pink or C.white)
		end
		for side = -1, 1, 2 do
			part(plaza, "AwningPole", Vector3.new(0.6, 8, 0.6), shopCf * CFrame.new(side * 4.6, 4, 2.6), C.white)
		end
		billboard(counter, { { text = "SHOP", color = C.coin } }, 9, 2.4, 9, 200)
		local altarPos = polar(34, 180, 7.75)
		local altar = disc(plaza, "RebirthAltar", 4, altarPos + Vector3.new(0, 0.4, 0), 0.4, C.purple, NEON, { attrs = { RebirthAltar = true } })
		part(plaza, "RebirthCrystal", Vector3.new(2, 4, 2), CFrame.new(altarPos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(45), math.rad(20)), C.purple, NEON)
		light(altar, C.purple, 20, 2)
		billboard(altar, { { text = "REBIRTH", color = C.purple } }, 9, 2.4, 8, 200)
		local codesPos = polar(34, 0, 7.75)
		local mailbox = part(plaza, "CodesBox", Vector3.new(3, 4, 3), lookAt(codesPos + Vector3.new(0, 2, 0), Vector3.new(0, 9.75, 0)), C.mint, SMOOTH, { attrs = { Codes = true } })
		billboard(mailbox, { { text = "CODES", color = C.mint } }, 8, 2.2, 4.5, 200)

		-- plots
		local plots = folder("Plots", map)
		local plotSlimes = { { "mochi", 3 }, { "lenny", 5 }, { "kiki", 4 }, { "sprout", 2 }, { "gloop", 4 }, { "spark", 5 }, { "blubby", 3 }, { "cloudy", 4 } }
		for i = 1, 8 do
			local deg = (i - 1) * 45 + 22.5
			local cf = outward(polar(68, deg, 0), deg)
			local accent = ACCENTS[i]
			local plot = new("Model", { Name = "Plot" .. i }, plots)
			plot:SetAttribute("PlotId", i)
			part(plot, "Floor", Vector3.new(30, 0.4, 24), cf * CFrame.new(0, 7.2, 0), C.cream)
			for side = -1, 1, 2 do
				part(plot, "Trim", Vector3.new(0.8, 1, 24), cf * CFrame.new(side * 15, 7.5, 0), accent)
			end
			part(plot, "Trim", Vector3.new(30.8, 1, 0.8), cf * CFrame.new(0, 7.5, 12), accent)
			local slot = 0
			for row = 0, 1 do
				for col = -2, 2 do
					slot += 1
					local top = cf * CFrame.new(col * 5.4, 7.4, -2 - row * 6)
					part(plot, "PedestalRim", Vector3.new(0.4, 4, 4), top * CFrame.new(0, 0.2, 0) * UP, accent, NEON, { shape = CYL })
					part(plot, "Pedestal", Vector3.new(1.2, 3.6, 3.6), top * CFrame.new(0, 0.6, 0) * UP, C.white, SMOOTH, { shape = CYL, attrs = { Slot = slot } })
					if row == 0 and col <= 0 then
						local pick = plotSlimes[((i + col + 2) % #plotSlimes) + 1]
						buildSlime(pick[1], { cf = top * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.pi, 0), size = 3, tier = pick[2], parent = plot })
					end
				end
			end
			local cash = part(plot, "CashPad", Vector3.new(6, 0.4, 4), cf * CFrame.new(-8, 7.6, 8), C.coin, NEON, { attrs = { CashPad = true } })
			billboard(cash, { { text = "$0", color = C.coin } }, 6, 2, 2.6, 70)
			part(plot, "Treadmill", Vector3.new(4, 0.7, 8), cf * CFrame.new(9, 7.75, 7), C.dusk, SMOOTH, { attrs = { Treadmill = true } })
			local post = part(plot, "SignPost", Vector3.new(1, 6, 1), cf * CFrame.new(0, 10, 11.4), C.ink)
			billboard(post, { { text = "PLOT " .. i, color = accent }, { text = "free", font = Enum.Font.FredokaOne } }, 10, 3.6, 4.6, 160)
		end
		for _, d in { 0, 90, 180, 270 } do
			local post = part(map, "SafeSign", Vector3.new(0.8, 4, 0.8), CFrame.new(polar(92, d + 22.5 + 22.5, 9)), C.white)
			billboard(post, { { text = "SAFE ZONE", color = C.mint } }, 9, 1.8, 3.4, 140)
		end

		-- zones
		local zones = folder("Zones", map)
		local nests = folder("Nests", map)
		local guardians = folder("Guardians", map)
		local rocks = folder("SafeRocks", map)
		local pads = folder("LaunchPads", map)
		local golden = folder("GoldenNestSpots", map)

		-- 1 · Jelly Meadow
		local meadow = folder("JellyMeadow", zones)
		for i, d in { 10, 70, 130, 190, 250, 310 } do
			nest(nests, polar(135, d, 6), 1, 1, "M" .. i)
		end
		for i, d in { 40, 160, 280 } do
			guardian(guardians, polar(142, d, 6), 1, "M" .. i)
		end
		for i, d in { 100, 220, 340 } do
			safeRock(rocks, polar(152, d, 6), "M" .. i)
		end
		for i, d in { 60, 240 } do
			launchPad(pads, polar(165, d, 6), "M" .. i)
		end
		for k = 0, 11 do
			local d = k * 30 + 15
			tree(meadow, polar(k % 2 == 0 and 112 or 160, d + range(-6, 6), 6), range(0.9, 1.3))
		end
		local flowerColors = { rgb("#FF8FB8"), rgb("#FFE04D"), C.white }
		for k = 1, 70 do
			local p = polar(range(100, 170), range(0, 360), 6.45)
			part(meadow, "Flower", Vector3.new(0.9, 0.9, 0.9), CFrame.new(p), flowerColors[(k % 3) + 1], SMOOTH, { shape = BALL, collide = false })
		end

		-- 2 · Crystal Caves
		local caves = folder("CrystalCaves", zones)
		for i, d in { 20, 50, 140, 200, 260, 320 } do
			nest(nests, polar(207, d, 5), 2, 2, "C" .. i)
		end
		for i, d in { 95, 230, 350 } do
			guardian(guardians, polar(212, d, 5), 2, "C" .. i)
		end
		for i, d in { 75, 165, 290 } do
			safeRock(rocks, polar(222, d, 5), "C" .. i)
		end
		for i, d in { 120, 300 } do
			launchPad(pads, polar(232, d, 5), "C" .. i)
		end
		for k = 0, 17 do
			crystalCluster(caves, polar(k % 2 == 0 and 186 or 233, k * 20 + 8, 5), k % 4 == 0)
		end
		for k = 0, 9 do
			stalagmite(caves, polar(range(190, 228), k * 36 + 26, 5))
		end

		-- the Golden Nest: appears at one of these spots every 5 minutes, announced to the whole server
		local goldenSpots = { { 207, 110, 5 }, { 135, 290, 6 }, { 275, 50, 4 }, { 275, 160, 4 }, { 207, 240, 5 } }
		for i, s in goldenSpots do
			local pos = polar(s[1], s[2], s[3])
			local spot = part(golden, "GoldenSpot" .. i, Vector3.new(1, 1, 1), CFrame.new(pos), C.coin, NEON, { transparency = 1, collide = false, attrs = { GoldenNestSpot = true } })
			if i == 1 then
				local m = new("Model", { Name = "GoldenNest" }, golden)
				local gpad = disc(m, "GoldenPad", 4, pos + Vector3.new(0, 0.4, 0), 0.5, C.coin, NEON, { attrs = { GoldenNest = true } })
				light(gpad, C.coin, 30, 3)
				buildSlime("kiki", { cf = facingCentre(pos + Vector3.new(0, 0.65, 0)), size = 3.6, tier = 5, skin = "gold", parent = m })
				billboard(gpad, { { text = "GOLDEN NEST", color = C.coin }, { text = "4:59", font = Enum.Font.FredokaOne } }, 12, 3.6, 8, 600)
				spot:SetAttribute("Active", true)
			end
		end

		-- 3 · Cloud Volcano
		local volcano = folder("CloudVolcano", zones)
		for i, d in { 0, 60, 120, 180, 230, 310 } do
			nest(nests, polar(276, d, 4), 3, 3, "V" .. i)
		end
		for i, d in { 40, 165, 215 } do
			guardian(guardians, polar(276, d, 4), 3, "V" .. i)
		end
		for i, d in { 90, 195, 345 } do
			safeRock(rocks, polar(292, d, 4), "V" .. i)
		end
		for i, d in { 30, 140 } do
			launchPad(pads, polar(300, d, 4), "V" .. i)
		end
		for _, d in { 25, 150, 205, 335 } do
			lavaPool(volcano, polar(276, d, 4), range(5, 7.5))
		end
		for _, d in { 45, 110, 225, 330 } do
			geyser(volcano, polar(258, d, 4))
		end
		for k = 0, 9 do
			cloud(volcano, polar(range(250, 300), k * 36 + 12, range(24, 38)), range(0.8, 1.3))
		end

		-- the volcano with the Crown Nest on top and a jelly parkour path around it
		local coneCentre = polar(275, 270, 4)
		local cone = new("Model", { Name = "Volcano" }, volcano)
		for j = 0, 7 do
			disc(cone, "ConeLayer", 34 - j * 3, coneCentre + Vector3.new(0, 5 * (j + 1), 0), 5, j % 2 == 0 and C.cone or C.coneDark)
		end
		local crater = disc(cone, "Crater", 8, coneCentre + Vector3.new(0, 44.12, 0), 0.25, C.lava, NEON)
		light(crater, C.lava, 40, 2.5)
		local crown = new("Model", { Name = "CrownNest" }, cone)
		local crownPad = disc(crown, "CrownPad", 3.2, coneCentre + Vector3.new(0, 44.55, 0), 0.5, C.coin, NEON, { attrs = { CrownNest = true, OverheatBonus = 2 } })
		buildSlime("jellord", { cf = lookAt(coneCentre + Vector3.new(0, 44.8, 0), Vector3.new(0, 44.8, 0)), size = 3.8, tier = 6, parent = crown })
		billboard(crownPad, { { text = "CROWN NEST", color = C.coin }, { text = "Overheat x2", font = Enum.Font.FredokaOne } }, 12, 3.6, 9, 800)
		local parkour = new("Model", { Name = "JellyParkour" }, cone)
		local jelly = { C.pink, C.mint, C.coin }
		for k = 0, 17 do
			local a = 90 + k * 22
			local rho = 40 - k * 1.4
			local p = coneCentre + polar(rho, a, 2 + k * 2.25)
			part(parkour, "JellyStep", Vector3.new(7, 1, 7), CFrame.new(p) * CFrame.Angles(0, math.rad(-a), 0), jelly[(k % 3) + 1], SMOOTH, { attrs = { Bouncy = true } })
		end

		-- 4 · Glitch Zone: a floating island after Rebirth 1
		local glitch = folder("GlitchZone", zones)
		local gc = polar(430, 315, 40)
		disc(glitch, "GlitchIsland", 60, gc, 8, C.glitch, SMOOTH, { attrs = { Zone = 4 } })
		part(glitch, "GlitchUnderside", Vector3.new(96, 30, 96), CFrame.new(gc + Vector3.new(0, -10, 0)), C.glitch, SMOOTH, { ellipsoid = true })
		for c = -48, 48, 12 do
			local len = 2 * math.sqrt(60 * 60 - c * c) - 2
			part(glitch, "GridLine", Vector3.new(len, 0.2, 0.35), CFrame.new(gc + Vector3.new(0, 0.1, c)), C.mint, NEON, { collide = false })
			part(glitch, "GridLine", Vector3.new(0.35, 0.2, len), CFrame.new(gc + Vector3.new(c, 0.1, 0)), C.mint, NEON, { collide = false })
		end
		for k = 0, 9 do
			local s = range(2, 4.5)
			part(glitch, "FloatingCube", Vector3.new(s, s, s), CFrame.new(gc + polar(range(20, 75), k * 36, range(8, 26))) * CFrame.Angles(range(0, 3), range(0, 3), range(0, 3)), k % 2 == 0 and C.mint or C.pink, NEON, { collide = false })
		end
		for i, d in { 20, 110, 200, 290 } do
			local pos = gc + polar(30, d, 0)
			nest(nests, pos, 4, 4, "G" .. i)
		end
		for i, d in { 65, 245 } do
			guardian(guardians, gc + polar(38, d, 0), 4, "G" .. i)
		end
		local glitchSign = part(glitch, "GlitchSign", Vector3.new(1, 8, 1), CFrame.new(gc + Vector3.new(0, 4, 0)), C.ink)
		billboard(glitchSign, { { text = "GLITCH ZONE", color = C.mint } }, 16, 3, 6, 900)

		-- rainbow bridge from the volcano ring to the Glitch Zone
		local bridge = new("Model", { Name = "RainbowBridge" }, glitch)
		local rainbow = { rgb("#FF3D5A"), rgb("#FF8A3D"), rgb("#FFB020"), rgb("#45D46E"), rgb("#2F9BFF"), rgb("#A855F7") }
		local from, to = polar(304, 315, 4.5), polar(372, 315, 40)
		local steps = 12
		for k = 0, steps - 1 do
			local a = from:Lerp(to, k / steps)
			local b = from:Lerp(to, (k + 1) / steps)
			local mid = (a + b) / 2
			part(bridge, "BridgeSegment", Vector3.new(8, 1, (b - a).Magnitude + 0.3), lookAt(mid, b), rainbow[(k % 6) + 1], NEON)
		end
		gate(glitch, 300, 315, 4, 10, { RebirthGate = true, RequiredRebirth = 1, RequiredSpeed = 42, Zone = 4 }, { { text = "GLITCH ZONE", color = C.mint }, { text = "REBIRTH 1 · SPEED 42", color = C.coin } })

		return map
	end

	local function applyLighting(lighting)
		lighting.Technology = Enum.Technology.Future
		lighting.ClockTime = 14.5
		lighting.Brightness = 3
		lighting.Ambient = Color3.fromRGB(120, 110, 140)
		lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 190)
		lighting.GlobalShadows = true
		lighting.EnvironmentDiffuseScale = 1
		lighting.EnvironmentSpecularScale = 1
		for _, child in lighting:GetChildren() do
			child.Parent = nil
		end
		new("Atmosphere", { Density = 0.28, Offset = 0.25, Color = Color3.fromRGB(255, 214, 240), Decay = Color3.fromRGB(190, 160, 255), Glare = 0.2, Haze = 1.2 }, lighting)
		new("BloomEffect", { Intensity = 0.5, Size = 28, Threshold = 1.4 }, lighting)
		new("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.06, TintColor = Color3.fromRGB(255, 248, 252) }, lighting)
		new("SunRaysEffect", { Intensity = 0.06, Spread = 0.6 }, lighting)
		new("Sky", { Name = "Sky" }, lighting)
	end

	return { buildMap = buildMap, applyLighting = applyLighting }
end
