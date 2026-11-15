-- init: the server entry point. One job: build the tower, then start the
-- systems that run it, in order. No game logic lives here — TowerBuilder
-- builds, ObstacleRunner animates, GameServer rules.

local TowerBuilder = require(script.Parent.TowerBuilder)
local ObstacleRunner = require(script.Parent.ObstacleRunner)
local GameServer = require(script.Parent.GameServer)
local Leaderboards = require(script.Parent.Leaderboards)

local world = Instance.new("Folder")
world.Name = "MiloTower"
world.Parent = game.Workspace

local report = TowerBuilder.build(world)

ObstacleRunner.startMovers(report.movers)
ObstacleRunner.startSpinLoop(report.coins, report.spinners)
ObstacleRunner.wireCrumblers(report.crumblers)
GameServer.start(report)
Leaderboards.start(world)
