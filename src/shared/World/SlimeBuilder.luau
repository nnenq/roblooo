-- Builds a slime Model out of plain parts (no uploaded meshes or images), so the
-- same code works in Roblox Studio and in Lune when we generate the place file.
--
-- local buildSlime = require(SlimeBuilder)(env, Species)
-- buildSlime("lenny", { cf = CFrame.new(0, 7, 0), size = 4, tier = 6, skin = "normal", label = true, parent = workspace })
--
-- The slime sits on the ground at opts.cf and faces its -Z (LookVector).

return function(R, Species)
	local Instance, Vector3, CFrame, Color3, Enum, UDim2 = R.Instance, R.Vector3, R.CFrame, R.Color3, R.Enum, R.UDim2
	local INK = Color3.fromRGB(30, 22, 64)
	local WHITE = Color3.new(1, 1, 1)
	local SMOOTH = Enum.Material.SmoothPlastic

	local DIMS = {
		round = { 0.84, 0.70 },
		flat = { 0.92, 0.56 },
		tall = { 0.70, 0.74 },
		square = { 0.76, 0.66 },
	}

	local SKINS = {
		gold = { color = Color3.fromRGB(255, 201, 60), material = Enum.Material.Foil, reflectance = 0.2 },
		diamond = { color = Color3.fromRGB(191, 243, 255), material = Enum.Material.Glass, transparency = 0.25, reflectance = 0.3 },
		rainbow = { color = Color3.fromRGB(255, 95, 168), material = SMOOTH, rainbow = true },
		galaxy = { color = Color3.fromRGB(43, 23, 102), material = SMOOTH, stars = true },
		blood = { color = Color3.fromRGB(160, 18, 46), material = SMOOTH, drips = true },
		frozen = { color = Color3.fromRGB(191, 233, 255), material = Enum.Material.Ice, frost = true },
		candy = { color = Color3.fromRGB(255, 138, 61), material = SMOOTH },
	}

	local function part(model, name, size, cf, color, material, shape)
		local p
		if shape == "wedge" then
			p = Instance.new("WedgePart")
		else
			p = Instance.new("Part")
			if shape == "ball" then
				p.Shape = Enum.PartType.Ball
			elseif shape == "cylinder" then
				p.Shape = Enum.PartType.Cylinder
			end
		end
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or SMOOTH
		if shape == "ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.Parent = model
		return p
	end

	local function light(parent, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = parent
		return l
	end

	return function(speciesId, opts)
		opts = opts or {}
		local sp = Species.byId[speciesId] or Species.byId.blubby
		local base = opts.cf or CFrame.new()
		local S = opts.size or 4
		local tier = opts.tier or 1
		local skinId = opts.skin or "normal"
		local skin = SKINS[skinId]
		local faceId = opts.face or sp.face
		local f = sp.features

		local model = Instance.new("Model")
		model.Name = sp.name
		model:SetAttribute("Species", sp.id)
		model:SetAttribute("Tier", tier)
		model:SetAttribute("Skin", skinId)

		local d = DIMS[sp.shape]
		local bw, bh = S * d[1], S * d[2]
		local bd = bw * 0.92
		local lift = S * 0.02
		local cy = bh / 2 + lift

		-- point on the front of the body, dx/dy from the body centre, pushed `out` studs forward
		local function front(dx, dy, out)
			local z
			if sp.shape == "square" then
				z = -bd / 2
			else
				local k = 1 - (dx / (bw / 2)) ^ 2 - (dy / (bh / 2)) ^ 2
				z = -(bd / 2) * math.sqrt(math.max(0.05, k))
			end
			return base * CFrame.new(dx, cy + dy, z - (out or 0))
		end

		-- body
		local bodyColor = skin and skin.color or sp.color
		local bodyMat = skin and skin.material or SMOOTH
		if f.wire then
			bodyMat = Enum.Material.ForceField
		end
		local body = part(model, "Body", Vector3.new(bw, bh, bd), base * CFrame.new(0, cy, 0), bodyColor, bodyMat, sp.shape == "square" and "block" or "ellipsoid")
		if skin and skin.transparency then
			body.Transparency = skin.transparency
		end
		if skin and skin.reflectance then
			body.Reflectance = skin.reflectance
		end
		if skin and skin.rainbow then
			body:SetAttribute("RainbowCycle", true)
		end
		model.PrimaryPart = body

		-- eyes
		local e = bw * 0.2
		local ex, ey = bw * 0.17, bh * 0.08
		local squareEyes = sp.shape == "square"
		for side = -1, 1, 2 do
			local x = ex * side
			if faceId == "sleepy" then
				part(model, "Eye", Vector3.new(e, e * 0.16, e * 0.2), front(x, ey, e * 0.02), INK)
			elseif faceId == "glitch" then
				part(model, "Eye", Vector3.new(e * 0.8, e * 0.8, e * 0.2), front(x, ey, e * 0.04), INK)
				part(model, "EyeGlitch", Vector3.new(e * 0.8, e * 0.8, e * 0.1), front(x + e * 0.18, ey, e * 0.01), Color3.fromRGB(62, 230, 181), Enum.Material.Neon)
			else
				local scale = 1
				local h = 1.15
				if faceId == "crazy" then
					scale = side < 0 and 1.3 or 0.85
				elseif faceId == "smug" then
					h = 0.62
				end
				local w = e * scale
				part(model, "Eye", Vector3.new(w, w * h, w * 0.45), front(x, ey, w * 0.02), WHITE, SMOOTH, squareEyes and "block" or "ellipsoid")
				local px = faceId == "smug" and x + side * w * 0.15 or x
				local pw = w * (faceId == "crazy" and 0.36 or 0.5)
				part(model, "Pupil", Vector3.new(pw, pw * 1.1, pw * 0.5), front(px, ey - w * h * 0.15, w * 0.2), INK, SMOOTH, squareEyes and "block" or "ellipsoid")
			end
		end

		-- mouth
		local my = -bh * 0.12
		if faceId == "happy" then
			part(model, "Mouth", Vector3.new(e * 0.9, e * 0.35, e * 0.2), front(0, my, e * 0.02), INK, SMOOTH, "ellipsoid")
		elseif faceId == "sleepy" then
			part(model, "Mouth", Vector3.new(e * 0.4, e * 0.4, e * 0.2), front(0, my, e * 0.02), INK, SMOOTH, "ellipsoid")
		elseif faceId == "smug" then
			part(model, "Mouth", Vector3.new(e * 0.8, e * 0.14, e * 0.15), front(0, my, e * 0.02) * CFrame.Angles(0, 0, -0.2), INK)
		elseif faceId == "crazy" then
			part(model, "Mouth", Vector3.new(e * 1.0, e * 0.75, e * 0.25), front(0, my, e * 0.02), INK, SMOOTH, "ellipsoid")
		else
			part(model, "Mouth", Vector3.new(e * 1.0, e * 0.16, e * 0.15), front(0, my, e * 0.02), INK)
		end

		if f.blush and not skin then
			for side = -1, 1, 2 do
				part(model, "Blush", Vector3.new(e * 0.7, e * 0.35, e * 0.1), front(side * bw * 0.3, -bh * 0.06, 0), Color3.fromRGB(255, 143, 184), SMOOTH, "ellipsoid")
			end
		end

		-- species features
		if f.leaf then
			part(model, "Stem", Vector3.new(S * 0.04, S * 0.16, S * 0.04), base * CFrame.new(0, bh + S * 0.08, 0), Color3.fromRGB(47, 125, 50))
			for side = -1, 1, 2 do
				part(model, "Leaf", Vector3.new(S * 0.22, S * 0.05, S * 0.11), base * CFrame.new(side * S * 0.1, bh + S * 0.17, 0) * CFrame.Angles(0, 0, side * 0.45), Color3.fromRGB(108, 207, 90), SMOOTH, "ellipsoid")
			end
		end
		if f.cap then
			local capY = bh * 0.9
			part(model, "Cap", Vector3.new(bw * 1.22, bh * 0.55, bd * 1.22), base * CFrame.new(0, capY, 0), Color3.fromRGB(255, 77, 94), SMOOTH, "ellipsoid")
			for _, o in { { -0.2, 0.1 }, { 0.18, -0.12 }, { 0.04, 0.24 } } do
				part(model, "CapDot", Vector3.new(S * 0.1, S * 0.1, S * 0.1), base * CFrame.new(o[1] * bw, capY + bh * 0.22, o[2] * bw), WHITE, SMOOTH, "ball")
			end
		end
		if f.crystals then
			local cs = { { -0.18, 0.16, Color3.fromRGB(127, 212, 255) }, { 0.0, 0.21, Color3.fromRGB(168, 85, 247) }, { 0.17, 0.14, Color3.fromRGB(230, 251, 255) } }
			for i, c in cs do
				local s = S * c[2]
				local p = part(model, "Crystal", Vector3.new(s, s, s), base * CFrame.new(c[1] * S, bh + s * 0.15, 0) * CFrame.Angles(0.6 * i, 0.8, 0.45), c[3], i == 2 and Enum.Material.Neon or Enum.Material.Glass)
				if i == 2 then
					light(p, Color3.fromRGB(127, 212, 255), S * 3, 1.2)
				end
			end
		end
		if f.wings then
			for side = -1, 1, 2 do
				part(model, "Wing", Vector3.new(S * 0.34, S * 0.22, S * 0.06), base * CFrame.new(side * (bw / 2 + S * 0.1), bh * 0.62, S * 0.04) * CFrame.Angles(0, side * 0.3, side * 0.35), Color3.fromRGB(90, 75, 214), SMOOTH, "ellipsoid")
			end
		end
		if f.antenna then
			part(model, "Antenna", Vector3.new(S * 0.035, S * 0.2, S * 0.035), base * CFrame.new(0, bh + S * 0.1, 0), INK)
			local bulb = part(model, "Bulb", Vector3.new(S * 0.14, S * 0.14, S * 0.14), base * CFrame.new(0, bh + S * 0.22, 0), Color3.fromRGB(255, 224, 77), Enum.Material.Neon, "ball")
			light(bulb, Color3.fromRGB(255, 224, 77), S * 3, 1.5)
		end
		if f.spots then
			for _, o in { { -0.3, -0.2 }, { 0.32, -0.1 }, { 0.1, 0.32 }, { -0.12, -0.36 } } do
				part(model, "Spot", Vector3.new(S * 0.07, S * 0.07, S * 0.07), front(o[1] * bw, o[2] * bh, -S * 0.01), Color3.fromRGB(127, 255, 224), Enum.Material.Neon, "ball")
			end
		end
		if f.cracks then
			for _, o in { { -0.22, -0.25, 0.5 }, { 0.25, -0.3, -0.6 }, { 0.3, 0.25, 1.0 } } do
				part(model, "Crack", Vector3.new(S * 0.26, S * 0.03, S * 0.03), front(o[1] * bw, o[2] * bh, 0) * CFrame.Angles(0, 0, o[3]), Color3.fromRGB(255, 224, 77), Enum.Material.Neon)
			end
		end
		if f.cloud then
			for _, o in { { -0.2, 0.95, 0.26 }, { 0, 1.02, 0.32 }, { 0.2, 0.95, 0.24 } } do
				local s = S * o[3]
				part(model, "Puff", Vector3.new(s, s, s), base * CFrame.new(o[1] * S, bh * o[2], 0), WHITE, SMOOTH, "ball")
			end
		end
		if f.bolt then
			part(model, "Bolt", Vector3.new(S * 0.06, S * 0.16, S * 0.03), front(0, bh * 0.3, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
			part(model, "Bolt", Vector3.new(S * 0.06, S * 0.14, S * 0.03), front(S * 0.04, bh * 0.18, 0) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		end
		if f.horns then
			for side = -1, 1, 2 do
				part(model, "Horn", Vector3.new(S * 0.08, S * 0.2, S * 0.12), base * CFrame.new(side * S * 0.22, bh + S * 0.03, 0) * CFrame.Angles(0, 0, -side * 0.35), Color3.fromRGB(232, 224, 255), SMOOTH, "wedge")
			end
		end
		if f.crown then
			local gold = Color3.fromRGB(255, 201, 60)
			part(model, "CrownBand", Vector3.new(S * 0.32, S * 0.06, S * 0.32), base * CFrame.new(0, bh + S * 0.02, 0), gold, Enum.Material.Foil, "ellipsoid")
			for i = 0, 3 do
				local a = i * math.pi / 2
				part(model, "CrownSpike", Vector3.new(S * 0.06, S * 0.12, S * 0.06), base * CFrame.new(math.cos(a) * S * 0.11, bh + S * 0.09, math.sin(a) * S * 0.11), gold, Enum.Material.Foil)
			end
		end
		if f.drips or (skin and skin.drips) then
			local c = skin and skin.drips and Color3.fromRGB(122, 11, 31) or sp.dark
			for side = -1, 1, 2 do
				part(model, "Drip", Vector3.new(S * 0.1, S * 0.16, S * 0.1), base * CFrame.new(side * bw * 0.25, S * 0.06, -bd * 0.28), c, SMOOTH, "ellipsoid")
			end
		end
		if f.glitch then
			local ghostColors = { Color3.fromRGB(62, 230, 181), Color3.fromRGB(47, 155, 255) }
			for i, side in { -1, 1 } do
				local g = part(model, "Ghost", Vector3.new(bw, bh, bd), base * CFrame.new(side * S * 0.06, cy, S * 0.02), ghostColors[i], Enum.Material.Neon, "ellipsoid")
				g.Transparency = 0.65
			end
		end
		if f.stars or (skin and skin.stars) then
			for _, o in { { -0.3, 0.2 }, { 0.28, 0.3 }, { -0.1, -0.3 }, { 0.36, -0.2 }, { 0.05, 0.4 }, { -0.38, -0.05 } } do
				part(model, "Star", Vector3.new(S * 0.045, S * 0.045, S * 0.045), front(o[1] * bw, o[2] * bh, -S * 0.005), WHITE, Enum.Material.Neon, "ball")
			end
		end
		if skin and skin.frost then
			part(model, "Frost", Vector3.new(bw * 0.85, bh * 0.3, bd * 0.85), base * CFrame.new(0, bh * 0.92, 0), WHITE, Enum.Material.Snow, "ellipsoid")
		end

		-- rarity aura: light from Rare, a glowing shell from Epic
		local tierColor = Species.tiers[tier] and Species.tiers[tier].color or WHITE
		if tier >= 3 then
			light(body, tierColor, S * (1.5 + tier * 0.4), 1 + tier * 0.3)
		end
		if tier >= 4 then
			local shell = part(model, "Aura", Vector3.new(bw * 1.2, bh * 1.2, bd * 1.2), base * CFrame.new(0, cy, 0), tierColor, Enum.Material.ForceField, "ellipsoid")
			shell.CastShadow = false
		end

		if opts.label then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Label"
			gui.Size = UDim2.fromScale(S * 2.2, S * 0.9)
			gui.StudsOffset = Vector3.new(0, bh / 2 + S * 0.55, 0)
			gui.MaxDistance = 90
			gui.Adornee = body
			gui.Parent = body
			local name = Instance.new("TextLabel")
			name.Size = UDim2.fromScale(1, 0.45)
			name.BackgroundTransparency = 1
			name.Text = sp.name
			name.Font = Enum.Font.FredokaOne
			name.TextScaled = true
			name.TextColor3 = WHITE
			name.TextStrokeColor3 = INK
			name.TextStrokeTransparency = 0
			name.Parent = gui
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 0.55)
			t.Position = UDim2.fromScale(0, 0.45)
			t.BackgroundTransparency = 1
			t.Text = string.upper(Species.tiers[tier].id)
			t.Font = Enum.Font.LuckiestGuy
			t.TextScaled = true
			t.TextColor3 = tierColor
			t.TextStrokeColor3 = INK
			t.TextStrokeTransparency = 0
			t.Parent = gui
		end

		model.Parent = opts.parent
		return model
	end
end
