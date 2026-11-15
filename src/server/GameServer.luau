-- GameServer: the one place that holds player state. One job: run the game
-- rules — checkpoints, coins, the timer, winning, losing — and keep the
-- client informed through RemoteEvents. All positions come from the
-- TowerBuilder report; all heights and stage kinds come from TowerData.
-- DataStore calls are wrapped in pcall: a studio playtest with API access off
-- must still play fine, it just keeps the best time for the session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local TowerData = require(script.Parent.TowerData)
local Leaderboards = require(script.Parent.Leaderboards)

local GameServer = {}

local bestStore = nil
local ok, store = pcall(function()
	return DataStoreService:GetDataStore("MilosMoleDig_BestTimes")
end)
if ok then
	bestStore = store
end

local events = nil
local players = {}
local currentReport = nil

-- Put the player back on their latest checkpoint: point the engine's own
-- respawn at the checkpoint pad, and move the live character there too
-- (covers the first spawn, which the engine may place before this runs).
local function respawnAtCheckpoint(player, state)
	if not currentReport then
		return
	end
	local pad = currentReport.checkpoints[state.stage]
	if not pad then
		return
	end
	player.RespawnLocation = pad
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		-- Pad top is pad center + 0.5; root (hip) sits ~3 above the feet,
		-- so +4 lands the feet just above the pad instead of sinking the
		-- character into the platform (the old +3 put the feet below the
		-- platform top and the character popped/floated).
		root.CFrame = pad.CFrame + Vector3.new(0, 4, 0)
	end
end

local function getEvents()
	if events then
		return events
	end
	local folder = Instance.new("Folder")
	folder.Name = "MiloEvents"
	folder.Parent = ReplicatedStorage
	local function remote(name)
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	events = {
		coin = remote("CoinCollected"),
		checkpoint = remote("CheckpointReached"),
		finished = remote("RunFinished"),
		best = remote("BestTime"),
		replay = remote("Replay"),
	}
	return events
end

local function loadBest(player)
	if not bestStore then
		return nil
	end
	local success, value = pcall(function()
		return bestStore:GetAsync("best_" .. player.UserId)
	end)
	if success and typeof(value) == "number" then
		return value
	end
	return nil
end

local function saveBest(player, seconds)
	if not bestStore then
		return false
	end
	local success = pcall(function()
		bestStore:SetAsync("best_" .. player.UserId, seconds)
	end)
	return success
end

local function makeLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = 0
	stage.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = stats
	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Value = 0
	deaths.Parent = stats
	return stats
end

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, rest)
end

function GameServer.finishRun(player)
	local state = players[player]
	if not state or state.finished then
		return
	end
	state.finished = true
	-- GetServerTimeNow is the shared wall clock: the client shows its timer
	-- from the same clock, so the finished time matches what the HUD showed.
	local elapsed = Workspace:GetServerTimeNow() - state.startedAt
	local isBest = false
	if not state.best or elapsed < state.best then
		state.best = elapsed
		isBest = saveBest(player, elapsed)
	end
	if isBest then
		Leaderboards.recordTime(player, math.floor(elapsed * 1000 + 0.5))
	end
	getEvents().finished:FireClient(player, elapsed, state.coins, isBest, formatTime(elapsed))
end

function GameServer.onPlayerAdded(player)
	local state = {
		stage = 0,
		coins = 0,
		deaths = 0,
		startedAt = Workspace:GetServerTimeNow(),
		finished = false,
		best = loadBest(player),
	}
	players[player] = state
	makeLeaderstats(player)
	respawnAtCheckpoint(player, state)
	if state.best then
		getEvents().best:FireClient(player, state.best, formatTime(state.best))
	end
	local function wireCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		respawnAtCheckpoint(player, state)
		humanoid.Died:Connect(function()
			state.deaths += 1
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				stats.Deaths.Value = state.deaths
			end
		end)
	end
	-- Same as the client: the character may already exist when this runs.
	player.CharacterAdded:Connect(function(character)
		task.spawn(wireCharacter, character)
	end)
	if player.Character then
		task.spawn(wireCharacter, player.Character)
	end
end

function GameServer.onPlayerRemoving(player)
	players[player] = nil
end

function GameServer.wireCheckpoints(report)
	for index, pad in pairs(report.checkpoints) do
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local state = players[player]
			if not state or state.stage >= index then
				return
			end
			state.stage = index
			player.RespawnLocation = pad
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				stats.Stage.Value = index
			end
			getEvents().checkpoint:FireClient(player, index, TowerData.STAGE_COUNT - 1)
		end)
	end
end

function GameServer.wireCoins(report)
	for _, coin in ipairs(report.coins) do
		local taken = false
		coin.Touched:Connect(function(hit)
			if taken then
				return
			end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local state = players[player]
			if not state or state.finished then
				return
			end
			taken = true
			state.coins += 1
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				stats.Coins.Value = state.coins
			end
			getEvents().coin:FireClient(player, state.coins, coin.Position)
			coin.Parent = nil
			task.delay(45, function()
				coin.Parent = game.Workspace:FindFirstChild("MiloTower")
				taken = false
			end)
		end)
	end
end

function GameServer.wireKillers(report)
	local lastKill = {}
	for _, part in ipairs(report.killers) do
		part.Touched:Connect(function(hit)
			local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			local now = os.clock()
			if lastKill[humanoid] and now - lastKill[humanoid] < 1 then
				return
			end
			lastKill[humanoid] = now
			humanoid.Health = 0
		end)
	end
end

function GameServer.wireJumpPads(report)
	for _, pad in ipairs(report.jumpPads) do
		local cooling = false
		pad.Touched:Connect(function(hit)
			if cooling then
				return
			end
			local root = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			cooling = true
			root.AssemblyLinearVelocity = Vector3.new(0, 70, 0)
			task.delay(0.5, function()
				cooling = false
			end)
		end)
	end
end

function GameServer.wireWinPad(report)
	if not report.winPad then
		return
	end
	report.winPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			GameServer.finishRun(player)
		end
	end)
end

function GameServer.wireReplay()
	getEvents().replay.OnServerEvent:Connect(function(player)
		local state = players[player]
		if not state then
			return
		end
		state.stage = 0
		state.coins = 0
		state.finished = false
		state.startedAt = Workspace:GetServerTimeNow()
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			stats.Stage.Value = 0
			stats.Coins.Value = 0
		end
		player:LoadCharacter()
	end)
end

-- A player who slips off the tower falls past every stage; kill them once
-- they are well below the stage they stand on instead of letting them land
-- on the baseplate and walk back.
function GameServer.startFallWatch()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, state in pairs(players) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 then
					local floor = TowerData.stageHeight(state.stage) - 25
					if root.Position.Y < floor then
						humanoid.Health = 0
					end
				end
			end
		end
	end)
end

function GameServer.start(report)
	currentReport = report
	getEvents()
	GameServer.wireCheckpoints(report)
	GameServer.wireCoins(report)
	GameServer.wireKillers(report)
	GameServer.wireJumpPads(report)
	GameServer.wireWinPad(report)
	GameServer.wireReplay()
	GameServer.startFallWatch()
	Players.PlayerAdded:Connect(GameServer.onPlayerAdded)
	Players.PlayerRemoving:Connect(GameServer.onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		GameServer.onPlayerAdded(player)
	end
end

return GameServer
