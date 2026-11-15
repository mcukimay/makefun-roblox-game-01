-- TowerBuilder: turns TowerData into a real place. One job: build every part
-- of "Milo's Mole Dig" and hand back a report of what it built, so GameServer
-- and ObstacleRunner can wire behaviour without knowing any positions.
-- Nothing here moves or kills: it only places parts and returns them grouped
-- by role (coins, killers, movers, spinners, crumblers, jump pads, win pad).

local TowerData = require(script.Parent.TowerData)

local TowerBuilder = {}

local rng = Random.new(20261115)

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parent
	return part
end

local function flatCFrame(pos, lookAt)
	return CFrame.lookAt(pos, lookAt, Vector3.yAxis)
end

-- Direction from this stage toward the next one, horizontal only.
local function dirToNext(index)
	if index >= TowerData.STAGE_COUNT - 1 then
		return Vector3.xAxis
	end
	local from = TowerData.stageCenter(index)
	local to = TowerData.stageCenter(index + 1)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if d.Magnitude < 0.01 then
		return Vector3.xAxis
	end
	return d.Unit
end

local function addCoin(report, parent, pos)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.4, 2.4)
	coin.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
	coin.Color = TowerData.COIN_COLOR
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.Parent = parent
	table.insert(report.coins, coin)
	return coin
end

local function coinArc(report, parent, center, count, radius, height)
	for i = 1, count do
		local angle = (i / (count + 1)) * math.pi * 2
		addCoin(report, parent, center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius))
	end
end

local function addTorch(parent, pos)
	local pole = newPart(parent, "TorchPole", Vector3.new(0.6, 4, 0.6), CFrame.new(pos), Color3.fromRGB(90, 60, 35), Enum.Material.Wood)
	local flame = Instance.new("Part")
	flame.Name = "TorchFlame"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(1.4, 1.8, 1.4)
	flame.CFrame = CFrame.new(pos + Vector3.new(0, 2.8, 0))
	flame.Color = Color3.fromRGB(255, 160, 40)
	flame.Material = Enum.Material.Neon
	flame.Anchored = true
	flame.CanCollide = false
	flame.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 60)
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = flame
	return pole
end

local function addBoard(parent, pos, lookAt, title, body)
	local board = newPart(parent, "SignBoard", Vector3.new(10, 6, 0.6), flatCFrame(pos, lookAt), Color3.fromRGB(70, 48, 28), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.3)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 42
	titleLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	titleLabel.Text = title
	titleLabel.Parent = gui
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Position = UDim2.fromScale(0.05, 0.32)
	bodyLabel.Size = UDim2.fromScale(0.9, 0.65)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 24
	bodyLabel.TextColor3 = Color3.fromRGB(245, 235, 210)
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.Text = body
	bodyLabel.Parent = gui
	return board
end

local function addCheckpoint(report, parent, center, index)
	local pad = Instance.new("SpawnLocation")
	pad.Name = "Checkpoint_" .. index
	pad.Size = Vector3.new(6, 1, 6)
	pad.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0))
	pad.Color = TowerData.CHECKPOINT_COLOR
	pad.Material = Enum.Material.Neon
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 0
	pad.AllowTeamChangeOnTouch = false
	pad.Parent = parent
	report.checkpoints[index] = pad
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(TowerData.CHECKPOINT_COLOR)
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.8)
	sparkle.Speed = NumberRange.new(2)
	sparkle.Size = NumberSequence.new(0.5)
	sparkle.Parent = pad
	return pad
end

-- Milo himself, built from parts: brown body, pink snout, yellow hard hat.
local function buildMiloStatue(parent, pos)
	local statue = Instance.new("Folder")
	statue.Name = "MiloStatue"
	statue.Parent = parent
	local function ball(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(size, size, size)
		p.CFrame = CFrame.new(pos + offset)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.Parent = statue
		return p
	end
	ball("MiloBody", 3.2, Vector3.new(0, 1.6, 0), Color3.fromRGB(101, 67, 50))
	ball("MiloHead", 2.4, Vector3.new(0, 4.1, 0), Color3.fromRGB(121, 85, 63))
	ball("MiloSnout", 0.9, Vector3.new(0, 3.9, 1.2), Color3.fromRGB(255, 150, 170))
	ball("MiloEyeLeft", 0.45, Vector3.new(-0.7, 4.4, 1.05), Color3.fromRGB(20, 20, 20))
	ball("MiloEyeRight", 0.45, Vector3.new(0.7, 4.4, 1.05), Color3.fromRGB(20, 20, 20))
	local hat = Instance.new("Part")
	hat.Name = "MiloHardHat"
	hat.Shape = Enum.PartType.Cylinder
	hat.Size = Vector3.new(0.7, 3.4, 3.4)
	hat.CFrame = CFrame.new(pos + Vector3.new(0, 5.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	hat.Color = Color3.fromRGB(255, 205, 60)
	hat.Material = Enum.Material.SmoothPlastic
	hat.Anchored = true
	hat.Parent = statue
	local lamp = Instance.new("Part")
	lamp.Name = "MiloLamp"
	lamp.Shape = Enum.PartType.Ball
	lamp.Size = Vector3.new(0.7, 0.7, 0.7)
	lamp.CFrame = CFrame.new(pos + Vector3.new(0, 5.6, 1.2))
	lamp.Color = Color3.fromRGB(255, 240, 150)
	lamp.Material = Enum.Material.Neon
	lamp.Anchored = true
	lamp.Parent = statue
	return statue
end

local function buildShaft(parent)
	local height = TowerData.TOP_HEIGHT + 14
	local shaft = Instance.new("Part")
	shaft.Name = "MineShaft"
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Size = Vector3.new(height, 10, 10)
	shaft.CFrame = CFrame.new(0, height / 2 - 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	shaft.Color = Color3.fromRGB(52, 42, 34)
	shaft.Material = Enum.Material.Slate
	shaft.Anchored = true
	shaft.Parent = parent
	-- Gold ore veins stuck in the shaft wall, one per few stages.
	for i = 0, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local h = 4 + i * (TowerData.TOP_HEIGHT / 8)
		local ore = newPart(parent, "GoldOre", Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(math.cos(angle) * 5.2, h, math.sin(angle) * 5.2),
			TowerData.GOLD_COLOR, Enum.Material.Neon)
		ore.CanCollide = false
	end
end

local function platform(parent, name, center, size, theme)
	return newPart(parent, name, size, CFrame.new(center), theme.platform, Enum.Material.SmoothPlastic)
end

local kinds = {}

kinds.start = function(report, parent, center, theme, index)
	local ground = platform(parent, "StartGround", center, Vector3.new(26, 2, 26), theme)
	ground.Color = Color3.fromRGB(120, 88, 58)
	addCheckpoint(report, parent, center, 0)
	buildMiloStatue(parent, center + Vector3.new(-8, 1, -8))
	addBoard(parent, center + Vector3.new(0, 4, -11), center,
		"MILO'S MOLE DIG",
		"Milo the mole is trapped at the bottom of the mine. Climb 24 stages to the sunlight! Green pads save your spot. Grab gold coins. Red lava and spinning bars send you back. SPACE jumps. Reach the gold pad at the top!")
	addTorch(parent, center + Vector3.new(10, 1, -10))
	addTorch(parent, center + Vector3.new(-10, 1, 10))
	coinArc(report, parent, center, 3, 6, 2.5)
end

kinds.pads = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	for i = 1, 2 do
		local padPos = center + dir * (4 + i * 3.5) + Vector3.new(0, 0.4 + i * 0.2, (i == 1 and 2 or -2))
		newPart(parent, "HopPad", Vector3.new(3, 1, 3), CFrame.new(padPos), theme.trim, Enum.Material.Wood)
	end
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.beam = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	local beamCenter = center + dir * 8
	newPart(parent, "ThinBeam", Vector3.new(2, 1, 14), flatCFrame(beamCenter, beamCenter + dir), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	addCoin(report, parent, beamCenter + Vector3.new(0, 2, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.mover = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	local from = center + dir * 6 + Vector3.new(0, 0.5, 0)
	local nextCenter = TowerData.stageCenter(index + 1)
	local to = nextCenter - dir * 6 + Vector3.new(0, 0.5, 0)
	local mover = newPart(parent, "MoverPlatform", Vector3.new(6, 1, 6), CFrame.new(from), TowerData.MOVER_COLOR, Enum.Material.SmoothPlastic)
	table.insert(report.movers, { part = mover, from = from, to = to, time = 2.5 })
	addCoin(report, parent, (from + to) / 2 + Vector3.new(0, 2.5, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.checkpoint = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(9, 1.5, 9), theme)
	addCheckpoint(report, parent, center, index)
	addTorch(parent, center + Vector3.new(3.5, 0.75, -3.5))
	coinArc(report, parent, center, 3, 4, 2.5)
end

kinds.lava = function(report, parent, center, theme, index)
	local pool = newPart(parent, "LavaPool", Vector3.new(15, 1, 15), CFrame.new(center), TowerData.LAVA_COLOR, Enum.Material.Neon)
	table.insert(report.killers, pool)
	local dir = dirToNext(index)
	for i = 1, 3 do
		local padPos = center + dir * (-6 + i * 6) + Vector3.new((i == 2 and 2.5 or -2.5), 1, 0)
		newPart(parent, "SafePad", Vector3.new(3.5, 1, 3.5), CFrame.new(padPos), theme.trim, Enum.Material.SmoothPlastic)
	end
	addCoin(report, parent, center + Vector3.new(0, 2.5, 0))
	coinArc(report, parent, center, 2, 5, 2.5)
end

kinds.crumble = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	for i = 1, 4 do
		local block = newPart(parent, "CrumbleBlock", Vector3.new(4, 1, 4),
			CFrame.new(center + dir * (4 + i * 4.2) + Vector3.new(0, 0.4, 0)),
			Color3.fromRGB(200, 160, 90), Enum.Material.SmoothPlastic)
		table.insert(report.crumblers, block)
	end
	addCoin(report, parent, center + dir * 10 + Vector3.new(0, 2.5, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.jumppad = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(8, 1.5, 8), theme)
	local pad = newPart(parent, "JumpPad", Vector3.new(4, 0.8, 4), CFrame.new(center + Vector3.new(0, 1.1, 0)), TowerData.JUMPPAD_COLOR, Enum.Material.Neon)
	table.insert(report.jumpPads, pad)
	addCoin(report, parent, center + Vector3.new(0, 6, 0))
	coinArc(report, parent, center, 2, 4, 2.5)
end

kinds.spinner = function(report, parent, center, theme, index)
	local disc = Instance.new("Part")
	disc.Name = "SpinnerDisc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(1.5, 11, 11)
	disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = theme.platform
	disc.Material = Enum.Material.SmoothPlastic
	disc.Anchored = true
	disc.Parent = parent
	local bar = newPart(parent, "SpinnerBar", Vector3.new(9, 1, 1),
		CFrame.new(center + Vector3.new(4.5, 1.5, 0)), TowerData.SPINNER_COLOR, Enum.Material.Neon)
	table.insert(report.killers, bar)
	table.insert(report.spinners, { bar = bar, center = center + Vector3.new(0, 1.5, 0), radius = 4.5, speed = 1.6, phase = 0 })
	coinArc(report, parent, center, 3, 4, 2.5)
end

kinds.stairs = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	for i = 1, 5 do
		newPart(parent, "Step", Vector3.new(4, 1, 3),
			CFrame.new(center + dir * (3 + i * 2.4) + Vector3.new(0, 0.5 + i * 1, 0)),
			theme.trim, Enum.Material.Wood)
	end
	addCoin(report, parent, center + dir * 8 + Vector3.new(0, 5, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.moverV = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local from = center + Vector3.new(0, 1, 0)
	local to = center + Vector3.new(0, 10, 0)
	local mover = newPart(parent, "MoverPlatform", Vector3.new(6, 1, 6), CFrame.new(from), TowerData.MOVER_COLOR, Enum.Material.SmoothPlastic)
	table.insert(report.movers, { part = mover, from = from, to = to, time = 3 })
	addCoin(report, parent, center + Vector3.new(0, 6, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.lavaBeam = function(report, parent, center, theme, index)
	local pool = newPart(parent, "LavaPool", Vector3.new(14, 1, 14), CFrame.new(center), TowerData.LAVA_COLOR, Enum.Material.Neon)
	table.insert(report.killers, pool)
	local dir = dirToNext(index)
	local beamCenter = center + Vector3.new(0, 1, 0)
	newPart(parent, "ThinBeam", Vector3.new(2, 1, 13), flatCFrame(beamCenter, beamCenter + dir), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	addCoin(report, parent, beamCenter + Vector3.new(0, 2.5, 0))
	coinArc(report, parent, center, 2, 5, 2.5)
end

kinds.crumbleMover = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	for i = 1, 2 do
		local block = newPart(parent, "CrumbleBlock", Vector3.new(4, 1, 4),
			CFrame.new(center + dir * (4 + i * 4.2)), Color3.fromRGB(200, 160, 90), Enum.Material.SmoothPlastic)
		table.insert(report.crumblers, block)
	end
	local from = center + dir * 13 + Vector3.new(0, 0.5, 0)
	local nextCenter = TowerData.stageCenter(index + 1)
	local to = nextCenter - dir * 5 + Vector3.new(0, 0.5, 0)
	local mover = newPart(parent, "MoverPlatform", Vector3.new(5, 1, 5), CFrame.new(from), TowerData.MOVER_COLOR, Enum.Material.SmoothPlastic)
	table.insert(report.movers, { part = mover, from = from, to = to, time = 2.2 })
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.spinner2 = function(report, parent, center, theme, index)
	local disc = Instance.new("Part")
	disc.Name = "SpinnerDisc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(1.5, 12, 12)
	disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = theme.platform
	disc.Material = Enum.Material.SmoothPlastic
	disc.Anchored = true
	disc.Parent = parent
	for i = 1, 2 do
		local bar = newPart(parent, "SpinnerBar", Vector3.new(10, 1, 1),
			CFrame.new(center + Vector3.new(5, 1.5, 0)), TowerData.SPINNER_COLOR, Enum.Material.Neon)
		table.insert(report.killers, bar)
		table.insert(report.spinners, { bar = bar, center = center + Vector3.new(0, 1.5, 0), radius = 5, speed = 1.9, phase = (i - 1) * math.pi })
	end
	coinArc(report, parent, center, 3, 4.5, 2.5)
end

kinds.jumppad2 = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(7, 1.5, 7), theme)
	local dir = dirToNext(index)
	for i = 1, 2 do
		local pad = newPart(parent, "JumpPad", Vector3.new(4, 0.8, 4),
			CFrame.new(center + dir * (i - 1) * 7 + Vector3.new(0, 1.1 + (i - 1) * 5, 0)),
			TowerData.JUMPPAD_COLOR, Enum.Material.Neon)
		table.insert(report.jumpPads, pad)
	end
	local mid = newPart(parent, "MidLedge", Vector3.new(5, 1, 5),
		CFrame.new(center + dir * 7 + Vector3.new(0, 6, 0)), theme.trim, Enum.Material.SmoothPlastic)
	addCoin(report, parent, center + dir * 7 + Vector3.new(0, 8, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.beams = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for i = 1, 3 do
		local beamCenter = center + dir * (4 + i * 5) + side * (i % 2 == 1 and 2.5 or -2.5)
		newPart(parent, "ThinBeam", Vector3.new(2, 1, 7), flatCFrame(beamCenter, beamCenter + dir), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	end
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.moverLong = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	local from = center + dir * 6 + Vector3.new(0, 0.5, 0)
	local nextCenter = TowerData.stageCenter(index + 1)
	local to = nextCenter - dir * 6 + Vector3.new(0, 0.5, 0)
	local mover = newPart(parent, "MoverPlatform", Vector3.new(6, 1, 6), CFrame.new(from), TowerData.MOVER_COLOR, Enum.Material.SmoothPlastic)
	table.insert(report.movers, { part = mover, from = from, to = to, time = 3.5 })
	addCoin(report, parent, (from + to) / 2 + Vector3.new(0, 2.5, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.lavaRun = function(report, parent, center, theme, index)
	local dir = dirToNext(index)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	-- Pool shifted 2 studs toward the next stage and shrunk to 10x10 so it
	-- never overhangs the checkpoint platform: the old 18x18 pool hung over
	-- the checkpoint pad and a standing player's head clipped the lava,
	-- killing him on every respawn.
	local poolCenter = center + dir * 2
	local pool = newPart(parent, "LavaPool", Vector3.new(10, 1, 10), CFrame.new(poolCenter), TowerData.LAVA_COLOR, Enum.Material.Neon)
	table.insert(report.killers, pool)
	-- Step stone on the checkpoint platform: splits the tall first climb.
	newPart(parent, "StepPad", Vector3.new(4, 1, 4),
		CFrame.new(center - dir * 8.5 + Vector3.new(0, -2, 0)), theme.trim, Enum.Material.SmoothPlastic)
	-- Two stepping stones over the pool, both standing jumps. The old four
	-- pads zigzagged in world X, which made one gap ~9 studs — unjumpable
	-- from a standing start on a tiny pad.
	for i = 1, 2 do
		local padPos = center + dir * (-5.5 + (i - 1) * 1.5) + side * (i % 2 == 1 and 1.5 or -1.5) + Vector3.new(0, 1, 0)
		newPart(parent, "SafePad", Vector3.new(4, 1, 4), CFrame.new(padPos), theme.trim, Enum.Material.SmoothPlastic)
	end
	addCoin(report, parent, center + Vector3.new(0, 2.5, 0))
	coinArc(report, parent, center, 2, 6, 2.5)
end

kinds.crumbleSpiral = function(report, parent, center, theme, index)
	platform(parent, "StagePlatform", center, Vector3.new(6, 1.5, 6), theme)
	local dir = dirToNext(index)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for i = 1, 6 do
		local block = newPart(parent, "CrumbleBlock", Vector3.new(3.5, 1, 3.5),
			CFrame.new(center + dir * (4 + i * 3.2) + side * math.sin(i * 1.1) * 2.5 + Vector3.new(0, 0.4 + i * 0.4, 0)),
			Color3.fromRGB(200, 160, 90), Enum.Material.SmoothPlastic)
		table.insert(report.crumblers, block)
	end
	addCoin(report, parent, center + dir * 12 + Vector3.new(0, 3, 0))
	coinArc(report, parent, center, 2, 3.5, 2.5)
end

kinds.win = function(report, parent, center, theme, index)
	local top = platform(parent, "WinPlatform", center, Vector3.new(20, 2, 20), theme)
	top.Color = TowerData.WIN_COLOR
	for _, side in ipairs({
		{ offset = Vector3.new(0, 1.4, 9.5), size = Vector3.new(20, 0.8, 1) },
		{ offset = Vector3.new(0, 1.4, -9.5), size = Vector3.new(20, 0.8, 1) },
		{ offset = Vector3.new(9.5, 1.4, 0), size = Vector3.new(1, 0.8, 20) },
		{ offset = Vector3.new(-9.5, 1.4, 0), size = Vector3.new(1, 0.8, 20) },
	}) do
		newPart(parent, "GoldTrim", side.size, CFrame.new(center + side.offset), TowerData.GOLD_COLOR, Enum.Material.Neon)
	end
	local winPad = newPart(parent, "WinPad", Vector3.new(8, 1, 8), CFrame.new(center + Vector3.new(0, 1.5, 0)), TowerData.GOLD_COLOR, Enum.Material.Neon)
	report.winPad = winPad
	local confetti = Instance.new("ParticleEmitter")
	confetti.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, TowerData.GOLD_COLOR), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 200, 255)) })
	confetti.Rate = 25
	confetti.Lifetime = NumberRange.new(1.5)
	confetti.Speed = NumberRange.new(8)
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.Size = NumberSequence.new(0.7)
	confetti.Parent = winPad
	-- Trophy: golden cup on a pedestal.
	local pedestal = newPart(parent, "TrophyPedestal", Vector3.new(3, 2, 3), CFrame.new(center + Vector3.new(-6, 2, -6)), Color3.fromRGB(220, 220, 220), Enum.Material.SmoothPlastic)
	local cup = Instance.new("Part")
	cup.Name = "TrophyCup"
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(2.5, 2.5, 2.5)
	cup.CFrame = CFrame.new(center + Vector3.new(-6, 4.2, -6)) * CFrame.Angles(0, 0, math.rad(90))
	cup.Color = TowerData.GOLD_COLOR
	cup.Material = Enum.Material.Neon
	cup.Anchored = true
	cup.Parent = parent
	addBoard(parent, center + Vector3.new(6, 4, -8), center, "YOU ESCAPED!", "Milo dug his way out of the mine and into the sunlight. Touch the gold pad to stop your timer, then play again and beat your best time!")
	coinArc(report, parent, center, 5, 7, 3)
end

function TowerBuilder.build(world)
	local report = {
		checkpoints = {}, coins = {}, killers = {}, movers = {},
		spinners = {}, crumblers = {}, jumpPads = {}, winPad = nil,
	}
	buildShaft(world)
	for i = 0, TowerData.STAGE_COUNT - 1 do
		local kind = TowerData.stageKind(i)
		local center = TowerData.stageCenter(i)
		local theme = TowerData.themeFor(i)
		local stageFolder = Instance.new("Folder")
		stageFolder.Name = string.format("Stage%02d_%s", i, kind)
		stageFolder.Parent = world
		kinds[kind](report, stageFolder, center, theme, i)
	end
	return report
end

return TowerBuilder
