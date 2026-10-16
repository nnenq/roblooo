-- Builds place/GreedySlimes.rbxl from the world builders in src/, without Roblox Studio.
-- Also writes a list of every part to <preview json> so tools/preview can render screenshots.
--
--   lune run tools/build_place.luau [out.rbxl] [preview.json]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local outPlace = process.args[1] or "place/GreedySlimes.rbxl"
local outPreview = process.args[2]

local env = roblox
local Species = require("../src/shared/Config/Species")(roblox.Color3)
local buildSlime = require("../src/shared/World/SlimeBuilder")(env, Species)
local World = require("../src/shared/World/MapBuilder")(env, { Species = Species, buildSlime = buildSlime })

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local map = World.buildMap(workspace)
World.applyLighting(game:GetService("Lighting"))

-- the builders travel with the place, so they can be re-run from Studio (command bar or MCP)
local tools = roblox.Instance.new("Folder")
tools.Name = "WorldTools"
tools.Parent = game:GetService("ServerStorage")
local function module(name, path)
	local m = roblox.Instance.new("ModuleScript")
	m.Name = name
	m.Source = fs.readFile(path)
	m.Parent = tools
end
module("Species", "src/shared/Config/Species.luau")
module("SlimeBuilder", "src/shared/World/SlimeBuilder.luau")
module("MapBuilder", "src/shared/World/MapBuilder.luau")
module("RebuildWorld", "src/server/RebuildWorld.luau")

local tide = roblox.Instance.new("Script")
tide.Name = "TideDemo"
tide.Source = fs.readFile("src/server/TideDemo.server.luau")
tide.Parent = game:GetService("ServerScriptService")

fs.writeFile(outPlace, roblox.serializePlace(game))

-- stats + preview export
local counts = { parts = 0, models = 0 }
local out = {}
for _, d in map:GetDescendants() do
	if d:IsA("Model") then
		counts.models += 1
	elseif d:IsA("BasePart") then
		counts.parts += 1
		if outPreview and d.Transparency < 0.99 then
			local kind = "block"
			if d.ClassName == "WedgePart" then
				kind = "wedge"
			elseif d:FindFirstChildOfClass("SpecialMesh") then
				kind = "ellipsoid"
			elseif d.ClassName == "Part" and d.Shape == roblox.Enum.PartType.Ball then
				kind = "ball"
			elseif d.ClassName == "Part" and d.Shape == roblox.Enum.PartType.Cylinder then
				kind = "cyl"
			end
			local transparency = d.Transparency
			if d.Material == roblox.Enum.Material.ForceField then
				transparency = math.max(transparency, 0.82)
			end
			table.insert(out, {
				k = kind,
				s = { d.Size.X, d.Size.Y, d.Size.Z },
				c = { d.CFrame:GetComponents() },
				col = { d.Color.R, d.Color.G, d.Color.B },
				t = transparency,
				n = d.Material == roblox.Enum.Material.Neon,
			})
		end
	end
end
if outPreview then
	fs.writeFile(outPreview, serde.encode("json", out))
end
print(string.format("Built %s: %d parts, %d models", outPlace, counts.parts, counts.models))
