-- Rebuilds the island in an open place. Run in the Studio command bar (or via the Studio MCP):
--   require(game.ServerStorage.WorldTools.RebuildWorld)()
-- It replaces workspace.Map and resets Lighting to the game's look.

return function()
	local tools = script.Parent
	local env = {
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		UDim2 = UDim2,
	}
	local Species = require(tools.Species)(Color3)
	local buildSlime = require(tools.SlimeBuilder)(env, Species)
	local World = require(tools.MapBuilder)(env, { Species = Species, buildSlime = buildSlime })

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	World.buildMap(workspace)
	World.applyLighting(game:GetService("Lighting"))
	print("Greedy Slimes world rebuilt")
end
