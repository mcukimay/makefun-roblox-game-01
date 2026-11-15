-- TowerData: the one place that knows the tower's shape.
-- Every stage has a kind, a height, a position on the climbing spiral and a
-- colour theme. TowerBuilder reads this and nothing else; GameServer reads the
-- checkpoint list and the stage heights from here. No layout numbers live in
-- any other script, so the tower can be re-tuned by editing this file alone.

local TowerData = {}

TowerData.STAGE_COUNT = 24
TowerData.SPIRAL_RADIUS = 12
TowerData.ANGLE_STEP = math.rad(55)

-- Kinds, in climbing order. "checkpoint" stages carry a SpawnLocation pad.
TowerData.STAGES = {
	"start", "pads", "beam", "mover", "checkpoint", "lava", "crumble",
	"jumppad", "checkpoint", "spinner", "stairs", "moverV", "checkpoint",
	"lavaBeam", "crumbleMover", "spinner2", "checkpoint", "jumppad2",
	"beams", "moverLong", "checkpoint", "lavaRun", "crumbleSpiral", "win",
}

-- How high the next stage sits above this one. Jump pads and the vertical
-- mover earn their extra rise: the player cannot jump 10 studs unaided.
TowerData.RISE_AFTER = {
	start = 5, pads = 5, beam = 5, mover = 5, checkpoint = 5, lava = 5,
	crumble = 5, jumppad = 10, spinner = 5, stairs = 5, moverV = 10,
	lavaBeam = 5, crumbleMover = 5, spinner2 = 5, jumppad2 = 10,
	beams = 5, moverLong = 5, lavaRun = 5, crumbleSpiral = 5, win = 0,
}

TowerData.CHECKPOINT_STAGES = { 0, 4, 8, 12, 16, 20 }

-- Four strata of the mine, one per band of six stages: deep earth, amber ore,
-- moss, then open sky at the top.
TowerData.THEMES = {
	{ platform = Color3.fromRGB(107, 74, 47), trim = Color3.fromRGB(139, 94, 60) },
	{ platform = Color3.fromRGB(176, 124, 50), trim = Color3.fromRGB(214, 164, 80) },
	{ platform = Color3.fromRGB(94, 128, 70), trim = Color3.fromRGB(128, 168, 92) },
	{ platform = Color3.fromRGB(96, 130, 170), trim = Color3.fromRGB(150, 185, 220) },
}

TowerData.LAVA_COLOR = Color3.fromRGB(255, 80, 20)
TowerData.COIN_COLOR = Color3.fromRGB(255, 200, 40)
TowerData.CHECKPOINT_COLOR = Color3.fromRGB(60, 220, 90)
TowerData.JUMPPAD_COLOR = Color3.fromRGB(60, 200, 255)
TowerData.MOVER_COLOR = Color3.fromRGB(140, 110, 255)
TowerData.SPINNER_COLOR = Color3.fromRGB(255, 60, 60)
TowerData.WIN_COLOR = Color3.fromRGB(240, 240, 240)
TowerData.GOLD_COLOR = Color3.fromRGB(255, 205, 60)

-- Heights, built once from RISE_AFTER so no script hard-codes a Y value.
local heights = {}
local y = 0
for i = 0, TowerData.STAGE_COUNT - 1 do
	heights[i] = y
	y += TowerData.RISE_AFTER[TowerData.STAGES[i + 1]]
end
TowerData.HEIGHTS = heights
TowerData.TOP_HEIGHT = heights[TowerData.STAGE_COUNT - 1]

function TowerData.stageKind(index)
	return TowerData.STAGES[index + 1]
end

function TowerData.stageHeight(index)
	return heights[index]
end

function TowerData.stageCenter(index)
	local angle = index * TowerData.ANGLE_STEP
	return Vector3.new(
		math.cos(angle) * TowerData.SPIRAL_RADIUS,
		heights[index],
		math.sin(angle) * TowerData.SPIRAL_RADIUS
	)
end

function TowerData.themeFor(index)
	local band = math.clamp(math.floor(index / 6) + 1, 1, #TowerData.THEMES)
	return TowerData.THEMES[band]
end

function TowerData.isCheckpoint(index)
	for _, stage in ipairs(TowerData.CHECKPOINT_STAGES) do
		if stage == index then
			return true
		end
	end
	return false
end

return TowerData
