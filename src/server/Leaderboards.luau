-- Leaderboards: the lobby's top-times board. One job: keep the fastest
-- finish times in an OrderedDataStore and show the top 10 on a board by the
-- spawn. Times are stored negated (-timeMs) so the fastest run sorts first
-- in the store's descending order. Every DataStore and Players web call is
-- pcall-wrapped: a Studio playtest with API access off shows a placeholder
-- on the board and the game plays on.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboards = {}

local TOP_TIMES_STORE = "MiloTopTimes_v1"
local BOARD_REFRESH_SECONDS = 60
local TOP_COUNT = 10

local topStore = nil
local ok, store = pcall(function()
	return DataStoreService:GetOrderedDataStore(TOP_TIMES_STORE)
end)
if ok then
	topStore = store
end

local nameCache = {}
local boardBody = nil

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, rest)
end

-- Names come from the web service, so resolve once per user and cache the
-- answer — including failures, so a bad lookup is not retried every refresh.
local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local name = nil
	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if success and typeof(result) == "string" and result ~= "" then
		name = result
	else
		name = "Player " .. tostring(userId)
	end
	if #name > 14 then
		name = string.sub(name, 1, 14)
	end
	nameCache[userId] = name
	return name
end

local function refreshBoard()
	if not boardBody then
		return
	end
	if not topStore then
		boardBody.Text = "Leaderboard unavailable\n(DataStores are off)"
		return
	end
	local okPages, pages = pcall(function()
		return topStore:GetSortedAsync(false, TOP_COUNT)
	end)
	if not okPages or not pages then
		boardBody.Text = "Leaderboard unavailable\ntry again later"
		return
	end
	local okEntries, entries = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okEntries or not entries or #entries == 0 then
		boardBody.Text = "No finishes yet.\nBe the first to escape!"
		return
	end
	local lines = {}
	for i, entry in ipairs(entries) do
		-- Keys are "t_<userId>"; values are -timeMs.
		local userId = tonumber(string.sub(entry.key, 3))
		if userId then
			local timeMs = -entry.value
			table.insert(lines, string.format("%2d. %-14s %s", i, getName(userId), formatTime(timeMs / 1000)))
		end
	end
	if #lines == 0 then
		boardBody.Text = "No finishes yet.\nBe the first to escape!"
	else
		boardBody.Text = table.concat(lines, "\n")
	end
end

-- Record a finish. UpdateAsync keeps the stored value only when the new run
-- is faster (a larger, i.e. less negative, value), so a slower replay never
-- overwrites a better time. The board refreshes after a successful write.
function Leaderboards.recordTime(player, timeMs)
	if not topStore then
		return
	end
	local key = "t_" .. player.UserId
	local success = pcall(function()
		topStore:UpdateAsync(key, function(old)
			if old == nil then
				return -timeMs
			end
			return math.max(old, -timeMs)
		end)
	end)
	if success then
		task.spawn(refreshBoard)
	end
end

local function buildLobby(world)
	local lobby = Instance.new("Folder")
	lobby.Name = "MiloLobby"
	lobby.Parent = world

	-- Board stands ON the start platform itself, 9 studs in front of the
	-- spawn pad, bottom flush with the platform top (y = 1) — no separate
	-- deck at the platform's edge, so nothing about it can read as buried
	-- or floating. The player spawns facing -z and the board is dead ahead.
	local board = Instance.new("Part")
	board.Name = "TopTimesBoard"
	board.Size = Vector3.new(12, 8, 0.6)
	board.CFrame = CFrame.lookAt(Vector3.new(12, 5, -9), Vector3.new(12, 5, 0), Vector3.yAxis)
	board.Color = Color3.fromRGB(70, 48, 28)
	board.Material = Enum.Material.Wood
	board.Anchored = true
	board.Parent = lobby

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 36
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "TOP TIMES"
	title.Parent = gui

	local body = Instance.new("TextLabel")
	body.Position = UDim2.new(0.04, 0, 0, 50)
	body.Size = UDim2.new(0.92, 0, 1, -58)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Code
	body.TextSize = 19
	body.TextColor3 = Color3.fromRGB(245, 235, 210)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = "Loading..."
	body.Parent = gui
	boardBody = body
end

function Leaderboards.start(world)
	buildLobby(world)
	task.spawn(refreshBoard)
	Players.PlayerAdded:Connect(function()
		task.spawn(refreshBoard)
	end)
	task.spawn(function()
		while true do
			task.wait(BOARD_REFRESH_SECONDS)
			refreshBoard()
		end
	end)
end

return Leaderboards
