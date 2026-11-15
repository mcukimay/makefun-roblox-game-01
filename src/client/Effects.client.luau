-- Effects: the game's visual feedback, client side only. One job: make every
-- action feel answered — a gold burst where a coin was picked up, a shower of
-- colour where the player wins. These parts exist only on this player's
-- screen: the client creates them locally, so they never replicate and never
-- cost the server anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local events = ReplicatedStorage:WaitForChild("MiloEvents")
local coinEvent = events:WaitForChild("CoinCollected")
local finishedEvent = events:WaitForChild("RunFinished")

local folder = Instance.new("Folder")
folder.Name = "ClientEffects"
folder.Parent = game.Workspace

local function burst(position, colors, count, power)
	for _ = 1, count do
		local mote = Instance.new("Part")
		mote.Shape = Enum.PartType.Ball
		mote.Size = Vector3.new(0.5, 0.5, 0.5)
		mote.CFrame = CFrame.new(position)
		mote.Color = colors[math.random(1, #colors)]
		mote.Material = Enum.Material.Neon
		mote.Anchored = true
		mote.CanCollide = false
		mote.Parent = folder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		local target = position + dir * (power * (0.5 + math.random()))
		local tween = TweenService:Create(mote, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) })
		tween:Play()
		tween.Completed:Connect(function()
			mote:Destroy()
		end)
	end
end

coinEvent.OnClientEvent:Connect(function(_, coinPosition)
	burst(coinPosition, { Color3.fromRGB(255, 205, 60), Color3.fromRGB(255, 240, 150) }, 8, 4)
end)

finishedEvent.OnClientEvent:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local colors = {
		Color3.fromRGB(255, 205, 60),
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(120, 255, 140),
	}
	for i = 1, 4 do
		task.delay((i - 1) * 0.25, function()
			burst(root.Position + Vector3.new(0, 3, 0), colors, 14, 7)
		end)
	end
end)
