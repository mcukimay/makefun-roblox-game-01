-- ObstacleRunner: everything in the tower that moves. One job: keep the
-- movers gliding, the coins spinning, the spinner bars turning and the
-- crumbling blocks falling away, and nothing else.
-- Movers use TweenService (the engine does the work, no loop). Coins and
-- spinner bars share a single RunService.Heartbeat loop, so the tower costs
-- one update a frame no matter how many of them exist. Crumbling blocks are
-- event-driven: they only do work in the half second after a player steps on
-- one, then restore themselves on a timer.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ObstacleRunner = {}

local spinAngle = 0

function ObstacleRunner.startMovers(movers)
	for _, mover in ipairs(movers) do
		local info = TweenInfo.new(mover.time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		local tween = TweenService:Create(mover.part, info, { Position = mover.to })
		tween:Play()
	end
end

function ObstacleRunner.startSpinLoop(coins, spinners)
	RunService.Heartbeat:Connect(function(dt)
		spinAngle += dt * 2
		for _, coin in ipairs(coins) do
			if coin.Parent then
				coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(0, spinAngle, 0) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
		for _, spinner in ipairs(spinners) do
			local angle = spinAngle * spinner.speed + spinner.phase
			spinner.bar.CFrame = CFrame.new(spinner.center)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(spinner.radius, 0, 0)
		end
	end)
end

function ObstacleRunner.wireCrumblers(crumblers)
	for _, block in ipairs(crumblers) do
		local busy = false
		block.Touched:Connect(function(hit)
			if busy then
				return
			end
			local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			busy = true
			task.delay(0.6, function()
				block.Transparency = 1
				block.CanCollide = false
				task.delay(3, function()
					block.Transparency = 0
					block.CanCollide = true
					busy = false
				end)
			end)
		end)
	end
end

return ObstacleRunner
