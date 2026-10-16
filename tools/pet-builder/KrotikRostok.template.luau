--[[
	Кротик-Росток — питомец Dig an Egg (Зелёная планета, бонус ⛏️ Копатель).
	ModuleScript. Положи в ReplicatedStorage и назови KrotikRostok.

	Витрина всех редкостей и мутаций (Command Bar в Studio):
		require(game.ReplicatedStorage.KrotikRostok).Showcase(workspace)

	В игре:
		local Krotik = require(game.ReplicatedStorage.KrotikRostok)
		local pet = Krotik.Build("Legendary", "Gold")
		pet:PivotTo(CFrame.new(0, 0, 0))   -- точка опоры = низ лап, питомец смотрит по LookVector
		pet.Parent = workspace

		Krotik.SetRarity(pet, "Mythic")    -- сменить редкость у готовой модели
		Krotik.SetMutation(pet, "Galaxy")  -- сменить мутацию
		local stop = Krotik.StartRainbow(pet)  -- переливы для Rainbow (лучше на клиенте); stop() выключает

	Модель из KrotikRostok.glb (3D Importer): Krotik.Adopt(model, "Epic", "None").
	Части там называются по ролям (Fur, Face, Paw, Leaf, Scarf, Crown...), модуль узнаёт их по имени.
	Размеры в studs, питомец ~4.3 stud в высоту. Все детали без коллизий и Massless,
	приварены к невидимому Root (PrimaryPart).
]]

local RunService = game:GetService("RunService")

local Krotik = {}

--@@GENERATED@@

Krotik.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
Krotik.MutationOrder = { "None", "Gold", "Diamond", "Rainbow", "Galaxy" }

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local NEVER_MUTATE = { eye = true, shine = true, mouth = true }
local NAME_ROLE = {}
for role in pairs(Krotik.Palette) do
	NAME_ROLE[string.lower(role)] = role
end

local function roleOf(part)
	return part:GetAttribute("Role") or NAME_ROLE[string.lower(part.Name)]
end

local function groupOf(part, role)
	local g = part:GetAttribute("Group")
	if g then
		return g
	end
	if role == "scarf" then
		return "scarf"
	elseif role == "crown" or role == "gem" then
		return "crown"
	end
	return "base"
end

local function rainbowAt(colors, k)
	k = (k % 1) * #colors
	local i = math.floor(k)
	local a = colors[(i % #colors) + 1]
	local b = colors[((i + 1) % #colors) + 1]
	return a:Lerp(b, k - i)
end

local function seq(points)
	local kps = {}
	for _, p in ipairs(points) do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 5
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = seq({ { 0, 0 }, { 0.3, 0.35 }, { 1, 0 } })
	e.Transparency = seq({ { 0, 0.2 }, { 1, 1 } })
	for k, v in pairs(props) do
		e[k] = v
	end
	pcall(function()
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end)
	e.Parent = parent
	return e
end

-- a big slowly turning star behind the pet: the aura and the light rays
local function bigStar(center, name, color, size, transparency, rotSpeed)
	return emitter(center, name, {
		Color = ColorSequence.new(color),
		Rate = 0.5,
		Lifetime = NumberRange.new(4, 4),
		Speed = NumberRange.new(0, 0),
		RotSpeed = NumberRange.new(rotSpeed, rotSpeed),
		Size = NumberSequence.new(size),
		Transparency = seq({ { 0, 1 }, { 0.25, transparency }, { 0.75, transparency }, { 1, 1 } }),
		LockedToPart = true,
		ZOffset = -3,
		LightEmission = 0.6,
	})
end

local function clearFX(model)
	for _, d in ipairs(model:GetDescendants()) do
		if string.sub(d.Name, 1, 3) == "FX_" then
			d:Destroy()
		end
	end
end

local function refresh(model)
	local rarityId = model:GetAttribute("Rarity") or "Common"
	local mutationId = model:GetAttribute("Mutation") or "None"
	local r = Krotik.Rarities[rarityId]
	local m = Krotik.Mutations[mutationId]
	assert(r, "KrotikRostok: unknown rarity " .. tostring(rarityId))
	assert(m, "KrotikRostok: unknown mutation " .. tostring(mutationId))

	clearFX(model)
	pcall(function()
		model:ScaleTo(r.scale)
	end)

	local root = model.PrimaryPart
	local base = model:GetPivot().Position.Y
	local height = 4.3 * r.scale

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root and p.Name ~= "Root" then
			local role = roleOf(p)
			if role then
				local group = groupOf(p, role)
				local visible = group == "base" or table.find(r.groups, group) ~= nil
				local mutated = Krotik.RoleClass[role] ~= nil and not NEVER_MUTATE[role]
				local color = Krotik.Palette[role]
				local material = Enum.Material.SmoothPlastic
				local reflectance = 0
				local transparency = 0

				if mutated and m.palette then
					color = m.palette[Krotik.RoleClass[role]]
					reflectance = m.reflectance or 0
					transparency = m.transparency or 0
					if m.material == "glass" then
						material = Enum.Material.Glass
					end
				elseif mutated and m.colors then
					color = rainbowAt(m.colors, (p.Position.Y - base) / height)
				end
				if r.glowLeaves and mutationId == "None" and role == "leaf" then
					material = Enum.Material.Neon
				end
				if r.fx == "shine" and role == "fur" and mutationId == "None" then
					reflectance = 0.08
				end

				p.Color = color
				p.Material = material
				p.Reflectance = reflectance
				p.Transparency = visible and transparency or 1
				p:SetAttribute("BaseY", p.Position.Y - base)
			end
		end
	end

	-- rarity effects ---------------------------------------------------------------
	if not root then
		return
	end
	local center = Instance.new("Attachment")
	center.Name = "FX_Center"
	center.Position = Vector3.new(0, 0.1 * r.scale, 0)
	center.Parent = root
	local color = r.color
	local s = r.scale

	local function light(c, brightness, range)
		local l = Instance.new("PointLight")
		l.Name = "FX_Light"
		l.Color = c
		l.Brightness = brightness
		l.Range = range * s
		l.Parent = root
	end

	if r.glowLeaves and mutationId == "None" then
		light(Krotik.Palette.leaf, 0.8, 6)
	end
	if r.fx == "sparkle" then
		emitter(root, "FX_Sparkles", { Color = ColorSequence.new(color), Rate = 4 })
	elseif r.fx == "aura" then
		bigStar(center, "FX_Aura", color, 5.5 * s, 0.7, 12)
		emitter(root, "FX_Sparkles", { Color = ColorSequence.new(color), Rate = 8 })
		light(color, 1.5, 9)
	elseif r.fx == "rays" then
		bigStar(center, "FX_Rays", color, 7 * s, 0.5, 20)
		bigStar(center, "FX_Glow", Color3.fromRGB(255, 240, 180), 4.5 * s, 0.75, -8)
		emitter(root, "FX_Sparkles", { Color = ColorSequence.new(Color3.fromRGB(255, 200, 40)), Rate = 10 })
		light(color, 2, 10)
	elseif r.fx == "particles" then
		bigStar(center, "FX_Aura", color, 5.5 * s, 0.65, 15)
		emitter(root, "FX_Particles", {
			Color = ColorSequence.new(color),
			Rate = 14,
			Size = seq({ { 0, 0 }, { 0.2, 0.22 }, { 1, 0 } }),
			Acceleration = Vector3.new(0, 1.5, 0),
			Lifetime = NumberRange.new(1.5, 2.5),
		})
		light(color, 1.8, 9)
	elseif r.fx == "cosmic" then
		local rainbow = Krotik.Mutations.Rainbow.colors
		local kps = {}
		for i, c in ipairs(rainbow) do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#rainbow - 1), c))
		end
		bigStar(center, "FX_Rays", Color3.fromRGB(255, 255, 255), 7.5 * s, 0.55, 18).Color = ColorSequence.new(kps)
		emitter(root, "FX_Rainbow", { Color = ColorSequence.new(kps), Rate = 16, Lifetime = NumberRange.new(1.5, 2.5) })
		emitter(root, "FX_Cosmic", {
			Color = ColorSequence.new(Color3.fromRGB(138, 92, 255), Color3.fromRGB(25, 195, 255)),
			Rate = 8,
			Size = seq({ { 0, 0 }, { 0.5, 0.5 }, { 1, 0 } }),
		})
		light(Color3.fromRGB(150, 220, 255), 2, 10)
	end

	-- mutation effects ---------------------------------------------------------------
	if mutationId == "Gold" or mutationId == "Diamond" then
		local c = mutationId == "Gold" and Color3.fromRGB(255, 236, 160) or Color3.fromRGB(220, 248, 255)
		emitter(root, "FX_Glint", { Color = ColorSequence.new(c), Rate = 3, Speed = NumberRange.new(0, 0.2) })
	elseif mutationId == "Galaxy" then
		local h = Instance.new("Highlight")
		h.Name = "FX_Outline"
		h.Adornee = model
		h.FillTransparency = 1
		h.OutlineColor = m.glow
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		emitter(root, "FX_Stars", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), m.glow),
			Rate = 10,
			Speed = NumberRange.new(0, 0.1),
			Size = seq({ { 0, 0 }, { 0.5, 0.18 }, { 1, 0 } }),
			LockedToPart = true,
		})
	end
end

function Krotik.Build(rarity, mutation, options)
	options = options or {}
	local model = Instance.new("Model")
	model.Name = options.Name or "KrotikRostok"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2.8, 4.3, 2.6)
	root.CFrame = CFrame.new(0, 2.15, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.Anchored = options.Anchored ~= false
	root.Parent = model
	model.PrimaryPart = root

	for _, s in ipairs(Krotik.Parts) do
		local name, role, shape, size, pos, rot, group = s[1], s[2], s[3], s[4], s[5], s[6], s[7]
		local p = Instance.new("Part")
		p.Name = name
		local cf = CFrame.new(pos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		if shape == "cylinder" then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Y, size.X, size.Z)
			cf = cf * CFrame.Angles(0, 0, math.rad(90))
		else
			p.Size = size
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.CFrame = cf
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = size.Magnitude > 0.6
		p.Anchored = false
		p:SetAttribute("Role", role)
		p:SetAttribute("Group", group)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
	end

	-- pivot at the feet, so PivotTo(CFrame.new(x, groundY, z)) stands the pet on the ground
	model.WorldPivot = CFrame.new(0, 0, 0)
	model:SetAttribute("Pet", "KrotikRostok")
	model:SetAttribute("Planet", "Green")
	model:SetAttribute("Bonus", "Digger")
	model:SetAttribute("Rarity", rarity or "Common")
	model:SetAttribute("Mutation", mutation or "None")
	model:SetAttribute("Multiplier", Krotik.Mutations[mutation or "None"].mult)
	refresh(model)
	return model
end

-- For a model from KrotikRostok.glb (3D Importer): adds the invisible Root, welds and attributes.
function Krotik.Adopt(model, rarity, mutation)
	if not model.PrimaryPart then
		local cf, size = model:GetBoundingBox()
		local anchored = true
		local first = model:FindFirstChildWhichIsA("BasePart", true)
		if first then
			anchored = first.Anchored
		end
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = size
		root.CFrame = cf
		root.Transparency = 1
		root.CanCollide = false
		root.CanTouch = false
		root.Anchored = anchored
		root.Parent = model
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p ~= root then
				p.Anchored = false
				p.CanCollide = false
				p.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = p
				weld.Parent = p
			end
		end
		model.PrimaryPart = root
		model.WorldPivot = cf * CFrame.new(0, -size.Y / 2, 0)
	end
	model:SetAttribute("Pet", "KrotikRostok")
	model:SetAttribute("Rarity", rarity or model:GetAttribute("Rarity") or "Common")
	model:SetAttribute("Mutation", mutation or model:GetAttribute("Mutation") or "None")
	model:SetAttribute("Multiplier", Krotik.Mutations[model:GetAttribute("Mutation")].mult)
	refresh(model)
	return model
end

function Krotik.SetRarity(model, rarity)
	model:SetAttribute("Rarity", rarity)
	refresh(model)
end

function Krotik.SetMutation(model, mutation)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Multiplier", Krotik.Mutations[mutation].mult)
	refresh(model)
end

-- Rainbow: colours flow up the body. Returns a function that stops it.
function Krotik.StartRainbow(model, speed)
	speed = speed or 0.25
	local colors = Krotik.Mutations.Rainbow.colors
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local role = roleOf(p)
			if role and Krotik.RoleClass[role] and not NEVER_MUTATE[role] then
				table.insert(parts, p)
			end
		end
	end
	local t = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		if model:GetAttribute("Mutation") ~= "Rainbow" or not model.Parent then
			return
		end
		t = t + dt * speed
		for _, p in ipairs(parts) do
			p.Color = rainbowAt(colors, (p:GetAttribute("BaseY") or 0) / 4.3 - t)
		end
	end)
	return function()
		conn:Disconnect()
	end
end

-- all rarities in a row, all mutations in a second row, with labels
function Krotik.Showcase(parent, origin)
	parent = parent or workspace
	origin = origin or CFrame.new(0, 0, 0)
	local folder = Instance.new("Folder")
	folder.Name = "KrotikRostokShowcase"
	local function label(model, text, color)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = model.PrimaryPart
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true
		tl.Text = text
		tl.TextColor3 = color
		tl.TextStrokeTransparency = 0.2
		tl.Parent = gui
		gui.Parent = model.PrimaryPart
	end
	for i, rarity in ipairs(Krotik.RarityOrder) do
		local pet = Krotik.Build(rarity, "None")
		pet:PivotTo(origin * CFrame.new((i - 4) * 6, 0, 0))
		label(pet, rarity, Krotik.Rarities[rarity].color)
		pet.Parent = folder
	end
	for i, mutation in ipairs(Krotik.MutationOrder) do
		if mutation ~= "None" then
			local pet = Krotik.Build("Common", mutation)
			pet:PivotTo(origin * CFrame.new((i - 3.5) * 6, 0, 8))
			label(pet, mutation .. " x" .. Krotik.Mutations[mutation].mult, Color3.fromRGB(255, 255, 255))
			pet.Parent = folder
			if mutation == "Rainbow" then
				Krotik.StartRainbow(pet)
			end
		end
	end
	folder.Parent = parent
	return folder
end

return Krotik
