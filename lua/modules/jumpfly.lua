--- This module implements jump and fly for the player.
--- To enable and disable the fly mode, double tap on Space

local jumpfly = {}

conf = require("config")
codes = require("inputcodes")

local defaultConfig = {
	jumpVelocity = 100,
	holdTimeToFly = 0.5,
	exitFlyDoubleTapDelay = 0.5,
	airJumps = -1, -- -1 for infinite
	flyVerticalSpeed = 50,
	onFlyStart = nil,
	onFlyEnd = nil
}
local config = defaultConfig

local listeners = {}

local flying = false
local velocity = nil
local holdTimer = nil
local exitFlyDoubleTapTimer = nil
local jumps = 0

-- local backpack = Object:Load("backpack")

function fly()
	flying = true
	Player.Velocity.Y = 0
	Player.Acceleration = -Config.ConstantAcceleration
	holdTimer = nil
	if config.onFlyStart ~= nil then
		config.onFlyStart()
	end
end

function stopFlying()
	if exitFlyDoubleTapTimer ~= nil then
		exitFlyDoubleTapTimer:Cancel()
		exitFlyDoubleTapTimer = nil
	end
	flying = false
	Player.Acceleration:Set(0, 0, 0)
	Player.Velocity:Set(0, 0, 0)
	velocity = nil
	if config.onFlyEnd ~= nil then
		config.onFlyEnd()
	end
end

jumpfly.setup = function(self, _config)
	if self ~= jumpfly then
		error("jumpfly:setup(config) should be called with `:`")
	end

	ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, _config, {
			acceptTypes = {
				onFlyStart = { "function" },
				onFlyEnd = { "function" },
			},
		})
	end)
	if not ok then
		error("jumpfly:setup(config) - config error: " .. err)
	end

	for _, l in listeners do
		l:Remove()
	end
	listeners = {}

	local l = LocalEvent:Listen(LocalEvent.Name.Action1, function()
		if flying then
			if exitFlyDoubleTapTimer ~= nil then
				stopFlying()
				return
			end
			
			exitFlyDoubleTapTimer = Timer(config.exitFlyDoubleTapDelay, function()
				exitFlyDoubleTapTimer = nil
			end)
			velocity = Number3(0, config.flyVerticalSpeed, 0)
		else
			if config.airJumps < 0 then -- infinite air jumps
				Player.Velocity.Y = config.jumpVelocity
			else
				if Player.IsOnGround then
					jumps = 1
					Player.Velocity.Y = config.jumpVelocity
				else
					if jumps < config.airJumps + 1 then
						jumps += 1
						Player.Velocity.Y = config.jumpVelocity
					end
				end
			end
	
			holdTimer = Timer(config.holdTimeToFly, function()
				fly()
			end)
		end
	end)
	table.insert(listeners, l)

	l = LocalEvent:Listen(LocalEvent.Name.Action1Release, function()
		if holdTimer then
			holdTimer:Cancel()
			holdTimer = nil
		end
		if velocity ~= nil then
			Player.Velocity:Set(0, 0, 0)
			velocity = nil
		end
	end)
	table.insert(listeners, l)

	l = LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
		if velocity ~= nil then
			Player.Velocity:Set(velocity)
		end
	end)
	table.insert(listeners, l)

	l = LocalEvent:Listen(LocalEvent.Name.KeyboardInput, function(_, keyCode, _, down)
		if not flying then
			return
		end
		if down then
			if keyCode == codes.SHIFT or keyCode == codes.RIGHT_SHIFT then
				velocity = Number3(0, -config.flyVerticalSpeed, 0)
			end
		else
			if keyCode == codes.SHIFT or keyCode == codes.RIGHT_SHIFT then
				Player.Velocity:Set(0, 0, 0)
				velocity = nil
			end
		end
	end)
end

-- TMP HACK
if Client.IsMobile then
	Client.Action1 = function() 
		LocalEvent:Send(LocalEvent.Name.Action1)
	end
	Client.Action1Release = function() 
		LocalEvent:Send(LocalEvent.Name.Action1Release)
	end
end

jumpfly.fly = fly
jumpfly.stopFlying = stopFlying

return jumpfly
