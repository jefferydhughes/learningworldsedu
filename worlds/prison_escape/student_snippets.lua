--[[
  STUDENT CODE SNIPPETS — Prison Escape

  Each chapter has:
  - A TEMPLATE (what the student sees in the LMS with blanks)
  - The CORRECT ANSWER
  - COMMON MISTAKES and what they cause in-game

  The LMS sends completed code to the game server via:
    Event.SendTo({ Type = "inject_code", chapter = N, code = "..." })
]]

-- ============================================================
-- CHAPTER 1: KILLER LASERS
-- Concepts: functions, collision callbacks, player death
-- ============================================================

-- TEMPLATE (shown in LMS with blanks marked as _____)
--[[
LMS DISPLAY:
┌─────────────────────────────────────────────────────┐
│  CHAPTER 1: Killer Lasers                           │
│                                                     │
│  The laser beam stretches across the corridor, but  │
│  right now it does nothing when you walk through    │
│  it. Your job: make it deadly.                      │
│                                                     │
│  Fill in the blanks to complete the kill function:   │
│                                                     │
│  studentCode.laserOnCollision = function(laser, player) │
│      -- Send the player falling (this kills them)   │
│      player.Position = Number3(0, _____, 0)         │
│                                                     │
│      -- Print who got hit                           │
│      print(player._____ .. " hit a laser!")         │
│                                                     │
│      -- Respawn after 1 second                      │
│      Timer(_____, function()                        │
│          if spawnPosition then                       │
│              player.Position = spawnPosition:Copy()  │
│              player.Velocity = Number3.Zero          │
│          end                                        │
│      end)                                           │
│  end                                                │
│                                                     │
│  HINTS:                                             │
│  • To kill a player, move them far below the map    │
│  • -100 is a good "death" Y position                │
│  • player.Username gives you the player's name      │
│  • Timer takes seconds (1.0 = one second)           │
│                                                     │
│  [  SUBMIT  ]                                       │
└─────────────────────────────────────────────────────┘
]]

-- CORRECT ANSWER (Chapter 1)
local chapter1_correct = [[
studentCode.laserOnCollision = function(laser, player)
    player.Position = Number3(0, -100, 0)
    print(player.Username .. " hit a laser!")
    Timer(1.0, function()
        if spawnPosition then
            player.Position = spawnPosition:Copy()
            player.Velocity = Number3.Zero
        end
    end)
end
]]

-- COMMON MISTAKES (Chapter 1)
local chapter1_mistakes = {
    -- Mistake 1: Positive Y instead of negative (player flies UP instead of dying)
    wrong_y_positive = [[
studentCode.laserOnCollision = function(laser, player)
    player.Position = Number3(0, 100, 0)  -- WRONG: sends player to sky
    print(player.Username .. " hit a laser!")
    Timer(1.0, function()
        if spawnPosition then
            player.Position = spawnPosition:Copy()
        end
    end)
end
]],
    -- Mistake 2: Forgot Timer — player never respawns
    no_timer = [[
studentCode.laserOnCollision = function(laser, player)
    player.Position = Number3(0, -100, 0)
    print(player.Username .. " hit a laser!")
    -- Missing Timer! Player stays dead forever
end
]],
    -- Mistake 3: Timer value 0 — respawns instantly (no death penalty)
    instant_respawn = [[
studentCode.laserOnCollision = function(laser, player)
    player.Position = Number3(0, -100, 0)
    print(player.Username .. " hit a laser!")
    Timer(0, function()  -- Too fast! No consequence felt
        if spawnPosition then
            player.Position = spawnPosition:Copy()
        end
    end)
end
]],
}


-- ============================================================
-- CHAPTER 2: FLASHING LASERS
-- Concepts: while loops (as timers), timing, on/off states
-- ============================================================

-- TEMPLATE (shown in LMS)
--[[
LMS DISPLAY:
┌─────────────────────────────────────────────────────┐
│  CHAPTER 2: Flashing Lasers                         │
│                                                     │
│  Some lasers flash on and off. You need to set      │
│  the timing — how long they stay OFF (safe) and     │
│  how long they stay ON (deadly).                    │
│                                                     │
│  Fill in the timing values:                         │
│                                                     │
│  studentCode.flashTimings = function()              │
│      return {                                       │
│          offTime = _____,  -- seconds laser is OFF  │
│          onTime = _____    -- seconds laser is ON   │
│      }                                              │
│  end                                                │
│                                                     │
│  HINTS:                                             │
│  • offTime is how long the laser is hidden (safe)   │
│  • onTime is how long the laser is visible (deadly) │
│  • Try values between 0.5 and 2.0 seconds           │
│  • Equal values (1.0 and 1.0) = steady rhythm       │
│  • Short off + long on = VERY hard to pass          │
│  • Long off + short on = easier to pass             │
│                                                     │
│  CHALLENGE: Can you make it impossible? What about  │
│  setting offTime to 0? Try it and see what happens! │
│                                                     │
│  [  SUBMIT  ]                                       │
└─────────────────────────────────────────────────────┘
]]

-- CORRECT ANSWER (Chapter 2)
local chapter2_correct = [[
studentCode.flashTimings = function()
    return {
        offTime = 1.0,
        onTime = 1.0
    }
end
]]

-- COMMON MISTAKES (Chapter 2)
local chapter2_mistakes = {
    -- Mistake 1: offTime = 0 (laser never turns off, impossible to pass)
    never_off = [[
studentCode.flashTimings = function()
    return {
        offTime = 0,  -- WRONG: laser never turns off!
        onTime = 1.0
    }
end
]],
    -- Mistake 2: Negative numbers (breaks the timer)
    negative_time = [[
studentCode.flashTimings = function()
    return {
        offTime = -1,  -- WRONG: negative time breaks things
        onTime = 1.0
    }
end
]],
    -- Mistake 3: Extremely fast flashing (seizure-risk, also confusing)
    too_fast = [[
studentCode.flashTimings = function()
    return {
        offTime = 0.05,  -- Way too fast!
        onTime = 0.05
    }
end
]],
}


-- ============================================================
-- CHAPTER 3: CHECKPOINT SYSTEM
-- Concepts: position saving, Vector3/Number3, state tracking
-- ============================================================

-- TEMPLATE (shown in LMS)
--[[
LMS DISPLAY:
┌─────────────────────────────────────────────────────┐
│  CHAPTER 3: Checkpoint System                       │
│                                                     │
│  When you touch a checkpoint, it should save your   │
│  position. Next time you die, you respawn HERE      │
│  instead of all the way back at the start.          │
│                                                     │
│  Fill in the blanks:                                │
│                                                     │
│  studentCode.checkpointOnTouch = function(checkpoint, player, index) │
│      -- Save the checkpoint position as the new     │
│      -- spawn point (3 studs above so you don't     │
│      -- spawn inside the floor)                     │
│      spawnPosition = checkpoint._____ + Number3(0, _____, 0) │
│                                                     │
│      -- Print a message                             │
│      print(player.Username .. " reached Checkpoint " .. _____) │
│  end                                                │
│                                                     │
│  HINTS:                                             │
│  • checkpoint.Position gives the checkpoint's spot  │
│  • Adding Number3(0, 3, 0) lifts the spawn point    │
│    3 studs UP so you don't get stuck in the floor   │
│  • "index" is the checkpoint number (1, 2, or 3)    │
│                                                     │
│  [  SUBMIT  ]                                       │
└─────────────────────────────────────────────────────┘
]]

-- CORRECT ANSWER (Chapter 3)
local chapter3_correct = [[
studentCode.checkpointOnTouch = function(checkpoint, player, index)
    spawnPosition = checkpoint.Position + Number3(0, 3, 0)
    print(player.Username .. " reached Checkpoint " .. index)
end
]]

-- COMMON MISTAKES (Chapter 3)
local chapter3_mistakes = {
    -- Mistake 1: No Y offset — player respawns inside the floor
    no_y_offset = [[
studentCode.checkpointOnTouch = function(checkpoint, player, index)
    spawnPosition = checkpoint.Position  -- WRONG: spawns INSIDE the checkpoint
    print(player.Username .. " reached Checkpoint " .. index)
end
]],
    -- Mistake 2: Negative Y offset — player respawns below floor, falls to death loop
    negative_offset = [[
studentCode.checkpointOnTouch = function(checkpoint, player, index)
    spawnPosition = checkpoint.Position + Number3(0, -3, 0)  -- WRONG: under the floor!
    print(player.Username .. " reached Checkpoint " .. index)
end
]],
    -- Mistake 3: Forgot to update spawnPosition — checkpoint does nothing
    forgot_save = [[
studentCode.checkpointOnTouch = function(checkpoint, player, index)
    -- Forgot to set spawnPosition!
    print(player.Username .. " reached Checkpoint " .. index)
end
]],
}


-- ============================================================
-- CHAPTER 4: VICTORY ZONE
-- Concepts: Text UI, Color, Timer (cleanup), game state
-- ============================================================

-- TEMPLATE (shown in LMS)
--[[
LMS DISPLAY:
┌─────────────────────────────────────────────────────┐
│  CHAPTER 4: Victory Zone                            │
│                                                     │
│  You made it! When a player reaches the Victory     │
│  Room, show a big "YOU ESCAPED!" message floating   │
│  above their head.                                  │
│                                                     │
│  Fill in the blanks:                                │
│                                                     │
│  studentCode.victoryOnTouch = function(player)      │
│      print(player.Username .. " escaped the prison!") │
│                                                     │
│      -- Create a floating text message              │
│      local victoryText = _____()                    │
│      victoryText.Text = "_____"                     │
│      victoryText.Color = Color(255, _____, 0)       │
│      victoryText.BackgroundColor = Color(30, 30, 30)│
│      victoryText.FontSize = _____                   │
│      victoryText.Position = player.Position + Number3(0, 10, 0) │
│      victoryText:SetParent(World)                   │
│                                                     │
│      -- Remove the message after 5 seconds          │
│      Timer(_____, function()                        │
│          victoryText:_____()                         │
│      end)                                           │
│  end                                                │
│                                                     │
│  HINTS:                                             │
│  • Text() creates a new floating text object        │
│  • Color(255, 215, 0) = gold color                  │
│  • FontSize 40 is nice and big                      │
│  • :Destroy() removes an object from the world      │
│                                                     │
│  [  SUBMIT  ]                                       │
└─────────────────────────────────────────────────────┘
]]

-- CORRECT ANSWER (Chapter 4)
local chapter4_correct = [[
studentCode.victoryOnTouch = function(player)
    print(player.Username .. " escaped the prison!")

    local victoryText = Text()
    victoryText.Text = "YOU ESCAPED!"
    victoryText.Color = Color(255, 215, 0)
    victoryText.BackgroundColor = Color(30, 30, 30)
    victoryText.FontSize = 40
    victoryText.Position = player.Position + Number3(0, 10, 0)
    victoryText:SetParent(World)

    Timer(5.0, function()
        victoryText:Destroy()
    end)
end
]]

-- COMMON MISTAKES (Chapter 4)
local chapter4_mistakes = {
    -- Mistake 1: Forgot Destroy — text stays forever
    no_destroy = [[
studentCode.victoryOnTouch = function(player)
    print(player.Username .. " escaped!")
    local victoryText = Text()
    victoryText.Text = "YOU ESCAPED!"
    victoryText.Color = Color(255, 215, 0)
    victoryText.FontSize = 40
    victoryText.Position = player.Position + Number3(0, 10, 0)
    victoryText:SetParent(World)
    -- Forgot Timer + Destroy — text stays FOREVER
end
]],
    -- Mistake 2: Wrong color — invisible text (black on black)
    invisible_text = [[
studentCode.victoryOnTouch = function(player)
    print(player.Username .. " escaped!")
    local victoryText = Text()
    victoryText.Text = "YOU ESCAPED!"
    victoryText.Color = Color(0, 0, 0)  -- Black text on dark background!
    victoryText.BackgroundColor = Color(30, 30, 30)
    victoryText.FontSize = 40
    victoryText.Position = player.Position + Number3(0, 10, 0)
    victoryText:SetParent(World)
    Timer(5.0, function() victoryText:Destroy() end)
end
]],
    -- Mistake 3: FontSize 0 — text exists but can't be seen
    zero_size = [[
studentCode.victoryOnTouch = function(player)
    print(player.Username .. " escaped!")
    local victoryText = Text()
    victoryText.Text = "YOU ESCAPED!"
    victoryText.Color = Color(255, 215, 0)
    victoryText.FontSize = 0  -- Can't see anything!
    victoryText.Position = player.Position + Number3(0, 10, 0)
    victoryText:SetParent(World)
    Timer(5.0, function() victoryText:Destroy() end)
end
]],
}
