-- Hud: everything the player reads on screen. One job: show the run's state
-- (stage, coins, timer, best time) and the game's feedback (checkpoint and
-- coin toasts, the win screen). It never owns state: the server is the
-- authority, this script only displays what the server sends, plus a timer
-- read from the same server clock the server uses to score the run.
-- The layout keeps the top-left corner clear: Roblox's own menu sits there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local events = ReplicatedStorage:WaitForChild("MiloEvents")
local coinEvent = events:WaitForChild("CoinCollected")
local checkpointEvent = events:WaitForChild("CheckpointReached")
local finishedEvent = events:WaitForChild("RunFinished")
local bestEvent = events:WaitForChild("BestTime")
local replayEvent = events:WaitForChild("Replay")

local gui = Instance.new("ScreenGui")
gui.Name = "MiloHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, name, size, pos, anchor, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = pos
	label.AnchorPoint = anchor
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = parent
	return label
end

-- Title, top centre.
makeLabel(gui, "Title", UDim2.new(0, 420, 0, 40), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0),
	Enum.Font.GothamBlack, 30, Color3.fromRGB(255, 210, 80)).Text = "MILO'S MOLE DIG"

-- Stats panel, top right (clear of the Roblox menu, top left).
local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.Size = UDim2.new(0, 250, 0, 132)
panel.Position = UDim2.new(1, -262, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(30, 22, 16)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stageLabel = makeLabel(panel, "StageLabel", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 6), Vector2.new(0, 0),
	Enum.Font.GothamBlack, 24, Color3.fromRGB(120, 255, 140))
stageLabel.TextXAlignment = Enum.TextXAlignment.Left
stageLabel.Text = "STAGE 0 / 23"
local coinLabel = makeLabel(panel, "CoinLabel", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 36), Vector2.new(0, 0),
	Enum.Font.GothamBlack, 24, Color3.fromRGB(255, 205, 60))
coinLabel.TextXAlignment = Enum.TextXAlignment.Left
coinLabel.Text = "COINS 0"
local timeLabel = makeLabel(panel, "TimeLabel", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 66), Vector2.new(0, 0),
	Enum.Font.GothamBlack, 24, Color3.fromRGB(255, 255, 255))
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Text = "TIME 0:00.00"
local bestLabel = makeLabel(panel, "BestLabel", UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 96), Vector2.new(0, 0),
	Enum.Font.Gotham, 20, Color3.fromRGB(180, 200, 255))
bestLabel.TextXAlignment = Enum.TextXAlignment.Left
bestLabel.Text = "BEST --"

-- Centre toast for one-line feedback.
local toast = makeLabel(gui, "Toast", UDim2.new(0, 600, 0, 44), UDim2.new(0.5, 0, 0, 120), Vector2.new(0.5, 0),
	Enum.Font.GothamBlack, 30, Color3.fromRGB(255, 255, 255))
toast.Text = ""

-- Win screen, hidden until the gold pad is touched.
local winFrame = Instance.new("Frame")
winFrame.Name = "WinScreen"
winFrame.Size = UDim2.fromScale(1, 1)
winFrame.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
winFrame.BackgroundTransparency = 0.35
winFrame.Visible = false
winFrame.Parent = gui
local winTitle = makeLabel(winFrame, "WinTitle", UDim2.new(0, 700, 0, 80), UDim2.new(0.5, 0, 0.28, 0), Vector2.new(0.5, 0),
	Enum.Font.GothamBlack, 56, Color3.fromRGB(255, 210, 80))
winTitle.Text = "YOU ESCAPED!"
local winStats = makeLabel(winFrame, "WinStats", UDim2.new(0, 700, 0, 90), UDim2.new(0.5, 0, 0.42, 0), Vector2.new(0.5, 0),
	Enum.Font.GothamBlack, 30, Color3.fromRGB(255, 255, 255))
winStats.Text = ""
local playAgain = Instance.new("TextButton")
playAgain.Name = "PlayAgain"
playAgain.Size = UDim2.new(0, 260, 0, 64)
playAgain.Position = UDim2.new(0.5, 0, 0.58, 0)
playAgain.AnchorPoint = Vector2.new(0.5, 0)
playAgain.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
playAgain.Font = Enum.Font.GothamBlack
playAgain.TextSize = 28
playAgain.TextColor3 = Color3.fromRGB(255, 255, 255)
playAgain.Text = "PLAY AGAIN"
playAgain.Parent = winFrame
local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 14)
playCorner.Parent = playAgain

local startTime = nil
local running = false
local awaitingReset = false

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, rest)
end

local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	task.delay(2.2, function()
		if toast.Text == text then
			toast.Text = ""
		end
	end)
end

local function startRunTimer()
	startTime = Workspace:GetServerTimeNow()
	running = true
end

local function wireCharacter(character)
	if awaitingReset then
		awaitingReset = false
		startRunTimer()
	elseif not running then
		startRunTimer()
	end
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		showToast("Ouch! Back to your checkpoint...", Color3.fromRGB(255, 120, 120))
	end)
end

-- The character usually already exists by the time this LocalScript runs,
-- so wire it now instead of waiting for a CharacterAdded that already fired.
player.CharacterAdded:Connect(function(character)
	task.spawn(wireCharacter, character)
end)
if player.Character then
	task.spawn(wireCharacter, player.Character)
end

RunService.RenderStepped:Connect(function()
	if running and startTime then
		timeLabel.Text = "TIME " .. formatTime(Workspace:GetServerTimeNow() - startTime)
	end
end)

coinEvent.OnClientEvent:Connect(function(total)
	coinLabel.Text = "COINS " .. total
	showToast("Coin! " .. total .. " collected", Color3.fromRGB(255, 205, 60))
end)

checkpointEvent.OnClientEvent:Connect(function(stage, total)
	stageLabel.Text = "STAGE " .. stage .. " / " .. total
	showToast("Checkpoint! Stage " .. stage, Color3.fromRGB(120, 255, 140))
end)

bestEvent.OnClientEvent:Connect(function(_, text)
	bestLabel.Text = "BEST " .. text
end)

finishedEvent.OnClientEvent:Connect(function(elapsed, coins, isBest, text)
	running = false
	winStats.Text = "TIME " .. text .. "   •   COINS " .. coins .. (isBest and "   •   NEW BEST!" or "")
	winFrame.Visible = true
	if isBest then
		bestLabel.Text = "BEST " .. text
	end
end)

playAgain.MouseButton1Click:Connect(function()
	winFrame.Visible = false
	awaitingReset = true
	replayEvent:FireServer()
end)
