-- Demo of the Tide: every cycle the sea rises over the three zone rings and falls back.
-- The base ring sits at y=7, just above the high tide (6.6), so bases stay dry.
-- Workspace attribute "TideIn" counts down the seconds, for the HUD later.

local TweenService = game:GetService("TweenService")

local sea = workspace:WaitForChild("Map"):WaitForChild("Ground"):WaitForChild("Sea")
local low = sea:GetAttribute("TideLowY") or 0
local high = sea:GetAttribute("TideHighY") or 6.6
local every = sea:GetAttribute("TideEverySeconds") or 150
local warning = sea:GetAttribute("TideWarningSeconds") or 20
local halfThickness = sea.Size.X / 2

local function seaAt(top: number): CFrame
	return CFrame.new(0, top - halfThickness, 0) * CFrame.Angles(0, 0, math.rad(90))
end

local rise = TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

while true do
	for t = every, 1, -1 do
		workspace:SetAttribute("TideIn", t)
		workspace:SetAttribute("TideWarning", t <= warning)
		task.wait(1)
	end
	workspace:SetAttribute("TideWarning", false)
	workspace:SetAttribute("TideIn", 0)
	TweenService:Create(sea, rise, { CFrame = seaAt(high) }):Play()
	task.wait(12)
	TweenService:Create(sea, rise, { CFrame = seaAt(low) }):Play()
	task.wait(6)
end
