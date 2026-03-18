--[[
  PRISON ESCAPE — Blip/Cubzh World Script
  CAMP-E Action Week | Ages 8-12 | Intermediate

  Architecture:
  - Server builds the 5-zone prison environment
  - Student code snippets are injected via the LMS into placeholder functions
  - Correct code makes the world playable; incorrect code causes visible failures
  - The world runs in dev mode to support dostring() injection

  Zone Layout (all dimensions in blocks/studs):
    Zone 1: Cell (Start)     — 12W x 20L x 10H
    Zone 2: Corridor 1       — 8W x 40L x 10H
    Zone 3: Guard Room       — 16W x 16L x 10H
    Zone 4: Corridor 2       — 8W x 40L x 10H
    Zone 5: Victory Room     — 20W x 20L x 10H
]]

-- ============================================================
-- CONFIGURATION
-- ============================================================

Config = {}

-- ============================================================
-- CONSTANTS
-- ============================================================

local BLOCK_SIZE = 1
local WALL_HEIGHT = 10
local DOOR_WIDTH = 4
local DOOR_HEIGHT = 8

-- Zone origins (X, Y, Z) — rooms laid out along the Z axis
local ZONES = {
    cell =      { origin = Number3(0, 0, 0),   width = 12, length = 20, height = 10 },
    corridor1 = { origin = Number3(2, 0, 20),  width = 8,  length = 40, height = 10 },
    guard =     { origin = Number3(-2, 0, 60), width = 16, length = 16, height = 10 },
    corridor2 = { origin = Number3(2, 0, 76),  width = 8,  length = 40, height = 10 },
    victory =   { origin = Number3(-2, 0, 116), width = 20, length = 20, height = 10 },
}

-- Color palette
local COLORS = {
    stone      = Color(136, 136, 136),    -- Medium Stone Grey
    fossil     = Color(160, 155, 145),    -- Fossil grey
    darkStone  = Color(100, 100, 100),    -- Dark stone
    red        = Color(255, 0, 0),         -- Bright Red (lasers)
    green      = Color(0, 255, 0),         -- Bright Green (checkpoints)
    darkGreen  = Color(0, 128, 0),         -- Dark Green (activated checkpoint)
    yellow     = Color(255, 255, 0),       -- Bright Yellow (victory)
    gold       = Color(255, 215, 0),       -- Gold (victory text)
    neonRed    = Color(255, 50, 50),       -- Neon red glow
    barGrey    = Color(80, 80, 80),        -- Prison bars
    floor      = Color(90, 90, 90),        -- Floor color
    ceiling    = Color(110, 110, 110),     -- Ceiling color
}

-- ============================================================
-- WORLD STATE
-- ============================================================

local worldObjects = {}       -- all spawned objects
local lasers = {}             -- laser objects for flashing
local checkpoints = {}        -- checkpoint objects
local victoryZone = nil       -- victory trigger zone
local spawnPosition = nil     -- current spawn position
local playerStates = {}       -- per-player state tracking

-- ============================================================
-- STUDENT CODE SLOTS
-- These functions are placeholders that students fill in.
-- If left empty or incorrect, the world behaves differently.
-- ============================================================

-- CHAPTER 1: Killer Laser callback
-- Students write the collision logic for static lasers.
-- Expected: detect player, set health to 0, create explosion effect
studentCode = {}

studentCode.laserOnCollision = nil  -- function(laser, player) ... end

-- CHAPTER 2: Flashing Laser timing
-- Students write the flash loop parameters.
-- Expected: return { offTime = <number>, onTime = <number> }
studentCode.flashTimings = nil  -- function() return { offTime, onTime } end

-- CHAPTER 3: Checkpoint save
-- Students write the respawn logic.
-- Expected: update spawnPosition when player touches checkpoint
studentCode.checkpointOnTouch = nil  -- function(checkpoint, player) ... end

-- CHAPTER 4: Victory detection
-- Students write the victory condition.
-- Expected: show message and print player name
studentCode.victoryOnTouch = nil  -- function(player) ... end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

--- Build a solid rectangular room (floor, walls, ceiling) from voxel blocks
local function buildRoom(zone, wallColor, floorColor, ceilingColor)
    local o = zone.origin
    local w = zone.width
    local l = zone.length
    local h = zone.height

    -- Floor
    local floor = MutableShape()
    for x = 0, w - 1 do
        for z = 0, l - 1 do
            floor:AddBlock(x, 0, z, floorColor or COLORS.floor)
        end
    end
    floor.Position = o + Number3(0, -1, 0)
    floor:SetParent(World)
    floor.Physics = false
    table.insert(worldObjects, floor)

    -- Ceiling
    local ceil = MutableShape()
    for x = 0, w - 1 do
        for z = 0, l - 1 do
            ceil:AddBlock(x, 0, z, ceilingColor or COLORS.ceiling)
        end
    end
    ceil.Position = o + Number3(0, h, 0)
    ceil:SetParent(World)
    ceil.Physics = false
    table.insert(worldObjects, ceil)

    -- Left wall (full length, full height)
    local leftWall = MutableShape()
    for z = 0, l - 1 do
        for y = 0, h - 1 do
            leftWall:AddBlock(0, y, z, wallColor or COLORS.stone)
        end
    end
    leftWall.Position = o + Number3(-1, 0, 0)
    leftWall:SetParent(World)
    leftWall.Physics = false
    table.insert(worldObjects, leftWall)

    -- Right wall
    local rightWall = MutableShape()
    for z = 0, l - 1 do
        for y = 0, h - 1 do
            rightWall:AddBlock(0, y, z, wallColor or COLORS.stone)
        end
    end
    rightWall.Position = o + Number3(w, 0, 0)
    rightWall:SetParent(World)
    rightWall.Physics = false
    table.insert(worldObjects, rightWall)

    -- Back wall (with doorway gap centered)
    local backWall = MutableShape()
    local doorStart = math.floor((w - DOOR_WIDTH) / 2)
    local doorEnd = doorStart + DOOR_WIDTH
    for x = 0, w - 1 do
        for y = 0, h - 1 do
            -- Leave doorway gap at the far end (z = l)
            local isDoor = (x >= doorStart and x < doorEnd and y < DOOR_HEIGHT)
            if not isDoor then
                backWall:AddBlock(x, y, 0, wallColor or COLORS.stone)
            end
        end
    end
    backWall.Position = o + Number3(0, 0, l)
    backWall:SetParent(World)
    backWall.Physics = false
    table.insert(worldObjects, backWall)

    -- Front wall (with doorway gap — skip for Cell start zone)
    if zone ~= ZONES.cell then
        local frontWall = MutableShape()
        for x = 0, w - 1 do
            for y = 0, h - 1 do
                local isDoor = (x >= doorStart and x < doorEnd and y < DOOR_HEIGHT)
                if not isDoor then
                    frontWall:AddBlock(x, y, 0, wallColor or COLORS.stone)
                end
            end
        end
        frontWall.Position = o + Number3(0, 0, -1)
        frontWall:SetParent(World)
        frontWall.Physics = false
        table.insert(worldObjects, frontWall)
    end

    return { floor = floor, ceiling = ceil }
end

--- Create a laser beam across a corridor
local function createLaser(zone, zOffset, isFlashing, flashOff, flashOn)
    local o = zone.origin
    local w = zone.width

    local laser = MutableShape()
    for x = 0, w - 1 do
        laser:AddBlock(x, 0, 0, COLORS.red)
    end
    laser.Position = o + Number3(0, 1, zOffset)
    laser:SetParent(World)
    laser.Physics = false
    laser.IsUnlit = true  -- Neon effect (self-illuminated)

    -- Collision detection
    laser.OnCollisionBegin = function(other)
        -- Check if "other" is a player
        local player = nil
        for _, p in ipairs(Players) do
            if p == other or (other:GetParent() and other:GetParent() == p) then
                player = p
                break
            end
        end

        if player and laser.IsHidden == false then
            -- STUDENT CODE SLOT: Chapter 1
            if studentCode.laserOnCollision then
                studentCode.laserOnCollision(laser, player)
            else
                -- Default behavior (no student code): nothing happens
                -- The laser is visible but harmless — student must write the kill code
                print("[PRISON ESCAPE] Laser touched but no kill code loaded!")
            end
        end
    end

    -- Flashing behavior
    if isFlashing then
        local offTime = flashOff or 1.0
        local onTime = flashOn or 1.0
        local isVisible = true

        -- If student provided custom timings, use those
        if studentCode.flashTimings then
            local timings = studentCode.flashTimings()
            if timings and timings.offTime and timings.onTime then
                offTime = timings.offTime
                onTime = timings.onTime
            end
        end

        -- Flash loop using Timer
        local function flashCycle()
            if isVisible then
                -- Turn OFF (safe)
                laser.IsHidden = true
                laser.Physics = false
                isVisible = false
                Timer(offTime, function()
                    flashCycle()
                end)
            else
                -- Turn ON (deadly)
                laser.IsHidden = false
                laser.Physics = false  -- still no physics, collision via callback
                isVisible = true
                Timer(onTime, function()
                    flashCycle()
                end)
            end
        end

        -- Start the flash cycle
        Timer(0.1, function() flashCycle() end)

        table.insert(lasers, {
            object = laser,
            isFlashing = true,
            offTime = offTime,
            onTime = onTime,
        })
    else
        table.insert(lasers, {
            object = laser,
            isFlashing = false,
        })
    end

    table.insert(worldObjects, laser)
    return laser
end

--- Create a checkpoint pad
local function createCheckpoint(zone, zOffset, checkpointIndex)
    local o = zone.origin
    local w = zone.width

    local cp = MutableShape()
    -- 4x4 pad centered in corridor
    local padStart = math.floor((w - 4) / 2)
    for x = 0, 3 do
        for z = 0, 3 do
            cp:AddBlock(x, 0, z, COLORS.green)
        end
    end
    cp.Position = o + Number3(padStart, 0, zOffset)
    cp:SetParent(World)
    cp.Physics = false
    cp.IsUnlit = true  -- Neon glow effect

    cp.OnCollisionBegin = function(other)
        local player = nil
        for _, p in ipairs(Players) do
            if p == other or (other:GetParent() and other:GetParent() == p) then
                player = p
                break
            end
        end

        if player then
            local pName = player.Username or tostring(player.ID)
            if not playerStates[pName] then
                playerStates[pName] = {}
            end

            local cpKey = "checkpoint_" .. checkpointIndex
            if not playerStates[pName][cpKey] then
                playerStates[pName][cpKey] = true

                -- STUDENT CODE SLOT: Chapter 3
                if studentCode.checkpointOnTouch then
                    studentCode.checkpointOnTouch(cp, player, checkpointIndex)
                else
                    -- Default: no checkpoint save — student must write this
                    print("[PRISON ESCAPE] Checkpoint " .. checkpointIndex .. " touched but no save code loaded!")
                end
            end
        end
    end

    checkpoints[checkpointIndex] = cp
    table.insert(worldObjects, cp)
    return cp
end

--- Create the victory zone
local function createVictoryZone(zone)
    local o = zone.origin
    local w = zone.width
    local l = zone.length

    local vz = MutableShape()
    for x = 0, w - 1 do
        for z = 0, l - 1 do
            vz:AddBlock(x, 0, z, COLORS.yellow)
        end
    end
    vz.Position = o + Number3(0, 0, 0)
    vz:SetParent(World)
    vz.Physics = false
    vz.IsUnlit = true

    local triggered = {}  -- prevent repeat triggers per player

    vz.OnCollisionBegin = function(other)
        local player = nil
        for _, p in ipairs(Players) do
            if p == other or (other:GetParent() and other:GetParent() == p) then
                player = p
                break
            end
        end

        if player then
            local pName = player.Username or tostring(player.ID)
            if not triggered[pName] then
                triggered[pName] = true

                -- STUDENT CODE SLOT: Chapter 4
                if studentCode.victoryOnTouch then
                    studentCode.victoryOnTouch(player)
                else
                    -- Default: no victory message — student must write this
                    print("[PRISON ESCAPE] Victory zone reached but no victory code loaded!")
                end
            end
        end
    end

    victoryZone = vz
    table.insert(worldObjects, vz)
    return vz
end

--- Create prison bars (decorative cylinders approximated as thin blocks)
local function createPrisonBars(zone)
    local o = zone.origin
    local w = zone.width
    local h = zone.height

    local bars = MutableShape()
    -- 4 vertical bars across the front opening
    local spacing = math.floor(w / 5)
    for i = 1, 4 do
        local x = i * spacing
        for y = 0, h - 1 do
            bars:AddBlock(x, y, 0, COLORS.barGrey)
        end
    end
    bars.Position = o + Number3(0, 0, -1)
    bars:SetParent(World)
    bars.Physics = false
    table.insert(worldObjects, bars)
    return bars
end

-- ============================================================
-- WORLD BUILDER — called on server start
-- ============================================================

local function buildPrisonWorld()
    print("[PRISON ESCAPE] Building prison world...")

    -- Set spawn position (inside cell)
    spawnPosition = ZONES.cell.origin + Number3(6, 2, 10)

    -- Ambient lighting — dark prison atmosphere
    Fog.On = true
    Fog.Color = Color(20, 20, 30)
    Fog.Near = 40
    Fog.Far = 120

    -- Zone 1: Cell (Start)
    buildRoom(ZONES.cell, COLORS.fossil, COLORS.darkStone, COLORS.darkStone)
    createPrisonBars(ZONES.cell)
    print("[PRISON ESCAPE] Zone 1: Cell built")

    -- Zone 2: Corridor 1
    buildRoom(ZONES.corridor1, COLORS.fossil, COLORS.darkStone, COLORS.darkStone)

    -- Static lasers in Corridor 1
    createLaser(ZONES.corridor1, 8, false)
    createLaser(ZONES.corridor1, 16, false)

    -- Flashing lasers in Corridor 1
    createLaser(ZONES.corridor1, 24, true, 1.0, 1.0)
    createLaser(ZONES.corridor1, 32, true, 0.5, 1.5)

    -- Checkpoint 1: end of Corridor 1
    createCheckpoint(ZONES.corridor1, 36, 1)
    print("[PRISON ESCAPE] Zone 2: Corridor 1 built with lasers + checkpoint")

    -- Zone 3: Guard Room
    buildRoom(ZONES.guard, COLORS.stone, COLORS.darkStone, COLORS.darkStone)

    -- Checkpoint 2: center of Guard Room
    createCheckpoint(ZONES.guard, 8, 2)
    print("[PRISON ESCAPE] Zone 3: Guard Room built + checkpoint")

    -- Zone 4: Corridor 2 (tighter laser spacing)
    buildRoom(ZONES.corridor2, COLORS.fossil, COLORS.darkStone, COLORS.darkStone)

    -- More lasers, tighter spacing, varied flash timings
    createLaser(ZONES.corridor2, 5, true, 0.8, 0.8)
    createLaser(ZONES.corridor2, 12, false)
    createLaser(ZONES.corridor2, 19, true, 0.6, 1.2)
    createLaser(ZONES.corridor2, 26, true, 1.5, 0.5)
    createLaser(ZONES.corridor2, 33, true, 0.4, 1.0)

    -- Checkpoint 3: before exit of Corridor 2
    createCheckpoint(ZONES.corridor2, 37, 3)
    print("[PRISON ESCAPE] Zone 4: Corridor 2 built with lasers + checkpoint")

    -- Zone 5: Victory Room
    buildRoom(ZONES.victory, COLORS.yellow, COLORS.yellow, COLORS.yellow)
    createVictoryZone(ZONES.victory)
    print("[PRISON ESCAPE] Zone 5: Victory Room built")

    print("[PRISON ESCAPE] World build complete! " .. #worldObjects .. " objects placed.")
end

-- ============================================================
-- PLAYER MANAGEMENT
-- ============================================================

local function respawnPlayer(player)
    if spawnPosition then
        player.Position = spawnPosition:Copy()
        player.Velocity = Number3.Zero
        player.Motion = Number3.Zero
    end
end

-- ============================================================
-- CODE INJECTION API
-- These functions are called by the LMS via the Hub API
-- to inject student code into the running world.
-- ============================================================

--- Inject student code for a specific chapter
--- Called via Event system from the LMS integration layer
function injectStudentCode(chapter, codeString)
    print("[PRISON ESCAPE] Injecting code for Chapter " .. chapter .. "...")

    local success, err = pcall(function()
        -- Execute the student's code in the current Lua environment
        -- The student code should define the appropriate studentCode.* function
        local fn, loadErr = loadstring(codeString)
        if fn then
            fn()
            print("[PRISON ESCAPE] Chapter " .. chapter .. " code loaded successfully")
        else
            print("[PRISON ESCAPE] ERROR: Code failed to parse: " .. tostring(loadErr))
            -- Trigger "explosion" feedback — the code is broken
            triggerCodeError(chapter, "Parse error: " .. tostring(loadErr))
        end
    end)

    if not success then
        print("[PRISON ESCAPE] ERROR: Code execution failed: " .. tostring(err))
        triggerCodeError(chapter, "Runtime error: " .. tostring(err))
    end
end

--- Visual feedback when student code has an error
function triggerCodeError(chapter, errorMsg)
    -- Flash all lasers red rapidly as error feedback
    for _, laserData in ipairs(lasers) do
        local l = laserData.object
        if l then
            -- Quick red flash effect
            l.IsHidden = false
        end
    end
    print("[PRISON ESCAPE] CODE ERROR (Chapter " .. chapter .. "): " .. errorMsg)
end

--- Validate that student code produces expected behavior
function validateStudentCode(chapter)
    local results = { valid = false, message = "" }

    if chapter == 1 then
        if studentCode.laserOnCollision then
            results.valid = true
            results.message = "Laser kill code loaded"
        else
            results.message = "Missing: studentCode.laserOnCollision function"
        end
    elseif chapter == 2 then
        if studentCode.flashTimings then
            local timings = studentCode.flashTimings()
            if timings and timings.offTime and timings.onTime then
                if timings.offTime > 0 and timings.onTime > 0 then
                    results.valid = true
                    results.message = "Flash timings valid: off=" .. timings.offTime .. "s, on=" .. timings.onTime .. "s"
                else
                    results.message = "Timings must be > 0 (got off=" .. tostring(timings.offTime) .. ", on=" .. tostring(timings.onTime) .. ")"
                end
            else
                results.message = "Flash function must return { offTime = <number>, onTime = <number> }"
            end
        else
            results.message = "Missing: studentCode.flashTimings function"
        end
    elseif chapter == 3 then
        if studentCode.checkpointOnTouch then
            results.valid = true
            results.message = "Checkpoint code loaded"
        else
            results.message = "Missing: studentCode.checkpointOnTouch function"
        end
    elseif chapter == 4 then
        if studentCode.victoryOnTouch then
            results.valid = true
            results.message = "Victory code loaded"
        else
            results.message = "Missing: studentCode.victoryOnTouch function"
        end
    end

    print("[PRISON ESCAPE] Validation (Chapter " .. chapter .. "): " .. results.message)
    return results
end

-- ============================================================
-- SERVER-SIDE INITIALIZATION
-- ============================================================

if is_server then

    LocalEvent:Listen(LocalEvent.OnStart, function()
        print("[PRISON ESCAPE] Server starting...")
        buildPrisonWorld()
    end)

    LocalEvent:Listen(LocalEvent.OnPlayerJoin, function(player)
        print("[PRISON ESCAPE] Player joined: " .. (player.Username or "unknown"))
        respawnPlayer(player)
    end)

    -- Listen for code injection events from LMS
    LocalEvent:Listen(LocalEvent.DidReceiveEvent, function(event)
        if event.Type == "inject_code" then
            local chapter = event.chapter
            local code = event.code
            if chapter and code then
                injectStudentCode(chapter, code)
            end
        elseif event.Type == "validate_code" then
            local chapter = event.chapter
            if chapter then
                validateStudentCode(chapter)
            end
        elseif event.Type == "reset_player" then
            -- Reset a player back to spawn
            for _, p in ipairs(Players) do
                if p.Username == event.playerName or tostring(p.ID) == tostring(event.playerID) then
                    respawnPlayer(p)
                    break
                end
            end
        end
    end)

    -- Server tick: check for players falling out of bounds
    LocalEvent:Listen(LocalEvent.Tick, function(dt)
        for _, player in ipairs(Players) do
            if player.Position.Y < -20 then
                respawnPlayer(player)
            end
        end
    end)
end

-- ============================================================
-- CLIENT-SIDE (UI, Camera, Controls)
-- ============================================================

if is_client then

    LocalEvent:Listen(LocalEvent.OnStart, function()
        -- Set camera to third-person RPG style
        Camera:SetModeThirdPerson()

        -- Dim ambient for prison atmosphere
        Ambient.Color = Color(40, 40, 50)
        Ambient.Intensity = 0.4
    end)
end

-- ============================================================
-- EXAMPLE STUDENT CODE (for testing / instructor reference)
-- These are the "correct answers" students should arrive at.
-- ============================================================

--[[ CHAPTER 1 ANSWER: Killer Laser
studentCode.laserOnCollision = function(laser, player)
    -- Kill the player
    player.Position = Number3(0, -100, 0)  -- "death" by falling

    -- Visual explosion feedback
    print(player.Username .. " hit a laser!")

    -- Respawn after brief delay
    Timer(1.0, function()
        if spawnPosition then
            player.Position = spawnPosition:Copy()
            player.Velocity = Number3.Zero
        end
    end)
end
]]

--[[ CHAPTER 2 ANSWER: Flash Timings
studentCode.flashTimings = function()
    return {
        offTime = 1.0,   -- laser hidden for 1 second
        onTime = 1.0     -- laser visible for 1 second
    }
end
]]

--[[ CHAPTER 3 ANSWER: Checkpoint Save
studentCode.checkpointOnTouch = function(checkpoint, player, index)
    -- Save this checkpoint as the new spawn position
    spawnPosition = checkpoint.Position + Number3(0, 3, 0)

    -- Visual feedback: turn checkpoint dark green
    -- (In Cubzh, we'd rebuild with dark green blocks or hide/show)
    print(player.Username .. " reached Checkpoint " .. index .. "!")
end
]]

--[[ CHAPTER 4 ANSWER: Victory Zone
studentCode.victoryOnTouch = function(player)
    print(player.Username .. " escaped the prison!")

    -- Show victory text above the player
    local victoryText = Text()
    victoryText.Text = "YOU ESCAPED!"
    victoryText.Color = Color(255, 215, 0)  -- Gold
    victoryText.BackgroundColor = Color(30, 30, 30)
    victoryText.FontSize = 40
    victoryText.Position = player.Position + Number3(0, 10, 0)
    victoryText:SetParent(World)

    -- Remove after 5 seconds
    Timer(5.0, function()
        victoryText:Destroy()
    end)
end
]]
