local json = require("sm64_rando_tracker/Json") -- Adjust the path based on your setup

-- SM64 Lua script for BizHawk emulator
-- Prints Mario, camera, terrain to screen

-----------------------------
--------- Variables ---------
-----------------------------

local fontFace = "Lucida Console"
local validRomVersion = "v1.0.2"

-- Reset the console when resetting
console.clear()

-------------------------
----- Version Check -----
-------------------------
local validVersion = false

memory.usememorydomain("ROM")
local romVersionBytes = memory.read_bytes_as_array(0x2A, 6)

local romVersion = ""

for i = 1, 6 do
    romVersion = romVersion .. string.char(romVersionBytes[i])
end

if romVersion == validRomVersion then
    validVersion = true
end

-- Attempts data
local attemptsFile = "sm64_rando_tracker/attempts.txt"
local attemptDataCsv = "sm64_rando_tracker/attempts_data.csv"
local pbFile = "sm64_rando_tracker/pb_stars.txt"
local pbStars = 0
local attemptCount = 0
local currentSeedKey = ""
local inMenu = false -- To detect transition from Menu to Level 16
local warpLogReset = false -- New flag to prevent multiple resets
local shouldSaveAttempt = false
local reason = ""

local addressMario = 0x19ca70 -- gMarioStates
local addressHud = 0x19ca60 -- gHudDisplay
local addressCurrLevelNum = 0x18e0e8 -- gCurrLevelNum
local addressRandomizerGameSeed = 0x1ca6ac -- gRandomizerGameSeed
local addressMarioGeometry = 0x19bccc -- sMarioGeometry
local addressDelayedWarpOp = 0x19ca4c -- sDelayedWarpOp
local addressCurrIntendedLevel = 0x19b7fc -- gCurrentIntendedLevel

local addressMarioInput = addressMario + 0x2
local addressMarioFlags = addressMario + 0x4
local addressMarioAction = addressMario + 0xC
local addressMarioPos = addressMario + 0x3C
local addressMarioHurtCounter = addressMario + 0xB2
local addressHudCoins = addressHud + 0x2
local addressHudStars = addressHud + 0x4
local addressHudHealthWedges = addressHud + 0x6
local addressMarioGeometryCurrFloorType = addressMarioGeometry + 0x8

local hp = 8
local coins
local stars
local level = 1
local area
local run_end = false
local run_start = false
local logged_run = false
local damage_was_taken = false
local taint_detected = false
local mario_action

local previous_hp = 8
local previous_level = 1
local previous_seed = 0
local previous_intended_level = 1
local leave_water_hp
local elapsedTime = 0
local frameCounter = 0 -- Initialize the frame counter

local displayData = {
    attemptCount = 0,
    elapsedTime = 0,
    stars = 0,
    levelAbbr = "Unknown",
    levelId = 0,
    seed = 0,
    marioAction = 0,
    pbStars = 0,
    logged_run = false,
    taint_detected = false,
    marioInWater = false,
    marioPos,
    warpLog = {}
}

-- Tracks stars collected per level
local starTracker = {}

starCountLines = 1

local mario_water_damage = {805446341, 805319364, 805446371, 805446344}
local mario_fell_out_of_course = {6440, 6441, 6442}
local mario_on_shell = {545326150, 42010778} -- DGR likes the taint

local levels_with_no_water = {9, 24, 4, 22, 8, 14, 15, 27, 31, 29, 18, 17, 30, 19}

-- Function to check if a level is in the list
function LevelHasWater(level)
    for _, v in ipairs(levels_with_no_water) do
        if v == level then
            return false -- Found the level
        end
    end
    return true -- Level not found
end

-- see console for other memory domains
memory.usememorydomain("RDRAM")

----------------------------------
---------- Mapping Data ----------
----------------------------------

LocationMap = {
    [9] = {"Bob-Omb Battlefield", "BoB"},
    [24] = {"Whomp's Fortress", "WF"},
    [12] = {"Jolly Roger Bay", "JRB"},
    [5] = {"Cool Cool Mountain", "CCM"},
    [4] = {"Big Boo's Haunt", "BBH"},
    [7] = {"Hazy Maze Cave", "HMC"},
    [22] = {"Lethal Lava Land", "LLL"},
    [8] = {"Shifting Sand Land", "SSL"},
    [23] = {"Dire Dire Docks", "DDD"},
    [10] = {"Snowman's Land", "SL"},
    [11] = {"Wet Dry World", "WDW"},
    [36] = {"Tall Tall Mountain", "TTM"},
    [13] = {"Tiny Huge Island", "THI"},
    [14] = {"Tick Tock Clock", "TTC"},
    [15] = {"Rainbow Ride", "RR"},
    [27] = {"Peach's Slide", "PSS"},
    [20] = {"Secret Aquarium", "SA"},
    [31] = {"Wing Mario Over the Rainbow", "WMotR"},
    [29] = {"Tower of the Wing Cap", "Wing"},
    [28] = {"Cavern of the Metal Cap", "Metal"},
    [18] = {"Vanish Cap Under the Moat", "Vanish"},
    [17] = {"Bowser in the Dark World", "BitDW"},
    [30] = {"Bowser Fight 1", "Bowser1"},
    [19] = {"Bowser in the Fire Sea", "BitFS"},
    [3626007] = {"Bowser in the Sky", "BitS"},
    [3626007] = {"Basement", "B1F"},
    [6] = {"Castle", "Castle"},
    [3626007] = {"Second Floor", "2F"},
    [3626007] = {"Third Floor", "3F"},
    [16] = {"Outside Castle", "Outside"},
    [26] = {"Garden", "Garden"}, -- 26 to 6 is no warp, 26 to anything else is warp
    [1] = {"Menu", "Menu"}
}

WarpLocations = {
    ["BoB"] = {166, 167, 168, 211, 212}, -- Bob-Omb Battlefield (BoB)
    ["WF"] = {172, 173, 174, 217, 218}, -- Whomp's Fortress (WF)
    ["JRB"] = {175, 176, 177, 221}, -- Jolly Roger Bay (JRB)
    ["CCM"] = {169, 170, 171, 215}, -- Cool Cool Mountain (CCM)
    ["BBH"] = {999}, -- Big Boo's Haunt (BBH)   -- 26 to 6 is no warp, 26 to anything else is warp
    ["HMC"] = {11111}, -- Hazy Maze Cave (HMC)
    ["LLL"] = {178, 179, 180, 224}, -- Lethal Lava Land (LLL)
    ["SSL"] = {181, 182, 183, 227}, -- Shifting Sand Land (SSL) 
    ["DDD"] = {232, 233, 234}, -- Dire Dire Docks (DDD)
    ["SL"] = {247, 248, 249}, -- Snowman's Land (SL)
    ["WDW"] = {190, 191, 192, 236}, -- Wet Dry World (WDW)
    ["TTM"] = {196, 197, 198, 242}, -- Tall Tall Mountain (TTM)
    ["THI"] = {193, 194, 195, 205, 206, 207}, -- Tiny Huge Island (THI)
    ["TTC"] = {244, 245, 246}, -- Tick Tock Clock (TTC)
    ["RR"] = {253}, -- Rainbow Ride (RR)
    ["PSS"] = {10878976}, -- Princess's Secret Slide (PSS)
    ["Aquarium"] = {10944512}, -- Secret Aquarium (Aquarium)
    ["WMotR"] = {11010048}, -- Wing Mario Over the Rainbow (WMotR)
    ["Wing"] = {21}, -- Tower of the Wing Cap (Wing)
    ["Metal"] = {10944512}, -- Cavern of the Metal Cap (Metal)
    ["Vanish"] = {11010048}, -- Vanish Cap Under the Moat (Vanish)
    ["BitDW"] = {10878976}, -- Bowser in the Dark World (BitDW)
    ["Bowser1"] = {10944512}, -- Bowser Fight 1 (Bowser1)
    ["BitFS"] = {11010048}, -- Bowser in the Fire Sea (BitFS)
    ["BitS"] = {10878976}, -- Bowser in the Sky (BitS)
    ["B1F"] = {10944512}, -- Basement (B1F)
    ["1F"] = {11010048}, -- First Floor (1F)
    ["2F"] = {10878976}, -- Second Floor (2F)
    ["3F"] = {10944512}, -- Third Floor (3F)
    ["Outside"] = {11010048}, -- Outside Castle (Outside)
    ["Menu"] = {10878976} -- Menu (Menu)
}

-- List of warp points without level grouping
warpCoords = {{
    pos = {
        [0] = 1972,
        [1] = 819,
        [2] = 1197
    },
    threshold = 80,
    label = "SA"
}, -- Secret Aquarium
{
    pos = {
        [0] = -5328,
        [1] = 512,
        [2] = -4146
    },
    threshold = 400,
    label = "BitDW"
}, -- Bowser 1
{
    pos = {
        [0] = 1974,
        [1] = 768,
        [2] = -2082
    },
    threshold = 80,
    label = "PSS"
}, -- Princess Slide
{
    pos = {
        [0] = -3440,
        [1] = 2950,
        [2] = 5999
    },
    threshold = 150,
    label = "RR"
}, -- Rainbow Road  WMotR
{
    pos = {
        [0] = 3030,
        [1] = 2816,
        [2] = 5924
    },
    threshold = 150,
    label = "WMotR"
}, -- WMotR
{
    pos = {
        [0] = 3306,
        [1] = -4689,
        [2] = 4795
    },
    threshold = 150,
    label = "Metal"
}, -- Metal
{
    pos = {
        [0] = -3323,
        [1] = -818,
        [2] = -2004
    },
    threshold = 150,
    label = "Vanish"
} -- Vanish
}

-- table of terrain names
local terrain_table = {}
terrain_table[0x00] = "normal"
terrain_table[0x01] = "lethal_lava"
terrain_table[0x05] = "hang"
terrain_table[0x0A] = "deathfloor"
terrain_table[0x0E] = "water_currents"
terrain_table[0x12] = "void"
terrain_table[0x13] = "very_slippery"
terrain_table[0x14] = "slippery"
terrain_table[0x15] = "climbable"
terrain_table[0x28] = "wall"
terrain_table[0x29] = "grass"
terrain_table[0x2A] = "unclimbable"
terrain_table[0x2C] = "windy"
terrain_table[0x2E] = "icy"
terrain_table[0x30] = "flat"
terrain_table[0x36] = "snowy"
terrain_table[0x37] = "snowy2"
terrain_table[0x76] = "fence"
terrain_table[0x7B] = "vanishing_wall"
terrain_table[0xFD] = "pool_warp"

-- Function to check if the CSV file exists and write headers if it doesn't
local function initializeCSV()
    local file = io.open(attemptDataCsv, "r")
    if not file then
        file = io.open(attemptDataCsv, "w")
        file:write("SeedKey,AttemptNumber,TimeStamp,Stars,Level,TimeTaken,StarsCollected\n")
        file:close()
    else
        file:close()
    end
end

-- Extended function to save attempts with more details in CSV format and update attempt count
local function saveAttempt(attemptDataCsv, attemptsFile, seed, attemptNumber, stars, levelAbbr, timeTaken, starTracker)
    initializeCSV() -- Ensure CSV file has headers

    -- Generate Seed Key
    local seedKey = string.format("%s_%s", seed, os.date("%y%m%d%H%M%S"))

    -- Format the star tracker data as a consolidated string
    local starData = ""
    for levelAbbr, starCount in pairs(starTracker) do
        starData = starData .. string.format("%s:%d ", levelAbbr, starCount)
    end
    starData = starData:match("^%s*(.-)%s*$") -- Trim leading/trailing spaces

    -- Append detailed attempt data to attemptDataCsv (CSV)
    local file = io.open(attemptDataCsv, "a") -- Append mode
    if file then
        -- Use the provided timeStamp or generate a new one if nil
        local timeStamp = os.date("%Y-%m-%d %H:%M:%S")

        -- Format and write CSV line
        file:write(string.format("%s,%d,%s,%d,%s,%s,%s\n", seedKey, attemptNumber, timeStamp, stars, levelAbbr,
            timeTaken, starData))
        file:close()
    else
        print("Failed to save attempt details!")
    end

    -- Overwrite attemptsFile with the latest attemptNumber
    local countFile = io.open(attemptsFile, "w") -- Write mode (overwrites content)
    if countFile then
        countFile:write(tostring(attemptNumber))
        countFile:close()
    else
        print("Failed to update attempt count!")
    end
end

-- Function to read the attempt number from the file
local function readAttemptNumber()
    local file = io.open(attemptsFile, "r") -- Open file in read mode
    if file then
        local content = file:read("*l") -- Read the first line
        file:close()

        local attemptNumber = tonumber(content) -- Convert to number
        if attemptNumber then
            return attemptNumber -- Return the number if valid
        else
            print("Error: File does not contain a valid number.")
            return 0 -- Default to 0 if invalid
        end
    else
        print("Error: File not found.")
        return 0 -- Default to 0 if file doesn't exist
    end
end

-- Get the current Attempt Count
attemptCount = readAttemptNumber()
attemptCount = attemptCount + 1

local runStartTime = nil -- Stores the start time of the current run

-- Function to start the timer when the run begins
function startRunTimer(level)
    if level == 16 and runStartTime == nil then
        runStartTime = os.time() -- Record the start time
        run_start = true
        console.write("Run timer started.\n")
    elseif level == 1 then
        runStartTime = nil -- Reset the timer when returning to the menu
    end
end

-- Function to format elapsed time as HH:MM:SS
function formatElapsedTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Check if PB file exists and load it, otherwise initialize to 0

-- Function to read PB from file with debug output
local function loadPB()
    local file = io.open(pbFile, "r")
    if file then
        pbStars = tonumber(file:read("*line")) or 0
        file:close()
    end

    -- Sanitize PB value to ensure it doesn't exceed 120
    if pbStars > 120 then
        pbStars = 120 -- Set to max allowed stars
    elseif pbStars < 0 then
        pbStars = 1 -- Set to reasonable starting value
    end

    -- Debug output
    console.write("Loaded PB Stars: " .. pbStars .. "\n")
end

-- Save PB value to file with sanitation
function savePB(stars)
    -- Ignore any PB updates if the stars value exceeds 120
    if stars > 120 then
        console.write("PB Stars not saved: value is greater than 120\n")
        return
    end

    -- Save the PB only if it's valid and less than 120
    local file = io.open(pbFile, "w")
    if file then
        file:write(tostring(stars))
        file:close()
    end

    -- Debug output
    console.write("Saved PB Stars: " .. stars .. "\n")
end

-- Call loadPB at the beginning of the script to initialize pbStars
loadPB()

-- terrain type to string description
function terrain2str(terrain)
    if (0x1B <= terrain and terrain <= 0x1E) then
        return string.format("switch%02X", terrain)
    elseif (0xA6 <= terrain and terrain <= 0xCF) then
        return string.format("paintingf%02X", terrain)
    elseif (0xD3 <= terrain and terrain <= 0xF8) then
        return string.format("paintingb%02X", terrain)
    elseif terrain_table[terrain] ~= nil then
        return terrain_table[terrain]
    else
        return "unknown"
    end
end

-- print float triple from memory
function read3float(base)
    arr = {}
    for i = 0, 2 do
        arr[i] = memory.readfloat(base + 4 * i, true)
    end
    return arr
end

-- print float triple
function print3float(x, y, name, pos)
    if pos then
        gui.text(x, y, string.format("%s %5.1f, %5.1f, %5.1f", name, pos[0], pos[1], pos[2]))
    else
        gui.text(x, y, name .. ": Invalid Position Data")
    end
end

-- Function to check if terrain corresponds to a warp location
function checkTerrainForWarp(terrain)
    -- Loop through all levels in WarpLocations
    for level, warps in pairs(WarpLocations) do
        -- Check if the terrain matches any of the warp locations
        for _, warp in ipairs(warps) do
            if terrain == warp then
                return level -- Return the level abbreviation
            end
        end
    end
    return nil -- Return nil if no match is found
end

-- colors for HP display
local hp_colors = {"red", "red", "yellow", "yellow", "lightgreen", "lightgreen", "lightblue", "lightblue"}

-- Warp log storage
local warpLogFile = "sm64_rando_tracker/warp_log.json"
local warp_log = {}

-- Load the warp log from the file
local function loadWarpLog()
    local file = io.open(warpLogFile, "r")
    if file then
        local content = file:read("*a")
        warp_log = content ~= "" and json.decode(content) or {}
        file:close()
        console.write("Warp log loaded from file.\n")
    else
        console.write("No existing warp log found. Starting fresh.\n")
    end
end

-- Save the warp log to the file in JSON format
local function saveWarpLog()
    local file = io.open(warpLogFile, "w")
    if file then
        file:write(json.encode(warp_log)) -- Save as JSON
        file:close()
        console.write("Warp log saved in JSON format.\n")
    else
        console.write("Failed to save warp log!\n")
    end
end

-- Track warp detection timing
local nearWarpTimer = {}
local wasNearWarp = {}

-- Check if Mario is near any warp point in warpCoords
function checkProximityToWarpPoints(marioPos, warpCoords)
    for _, warpPoint in ipairs(warpCoords) do
        local dx = marioPos[0] - warpPoint.pos[0]
        local dy = marioPos[1] - warpPoint.pos[1]
        local dz = marioPos[2] - warpPoint.pos[2]
        local distance_squared = dx * dx + dy * dy + dz * dz
        if distance_squared <= warpPoint.threshold * warpPoint.threshold then
            return warpPoint.label -- Return the label if Mario is near a warp point
        end
    end
    return nil -- Not near any warp point
end

-- Updated function to check and log transitions
function checkAndLogWarpTransition(mario_pos, warpCoords, previous_level, current_level)
    local warpLabel = checkProximityToWarpPoints(mario_pos, warpCoords)

    -- Start timer when Mario is near a warp point
    if warpLabel then
        if not wasNearWarp[warpLabel] then
            nearWarpTimer[warpLabel] = os.time()
            wasNearWarp[warpLabel] = true
            -- console.write(string.format("Mario is near %s. Timer started.\n", warpLabel))
        end
    else
        -- Reset if Mario moves away
        for label, timer in pairs(nearWarpTimer) do
            if os.time() - timer > 3 then -- 3-second timeout
                wasNearWarp[label] = false
                nearWarpTimer[label] = nil
                -- console.write(string.format("Timer expired for %s.\n", label))
            end
        end
    end

    -- Log warp if level changes after proximity detection
    if previous_level ~= current_level then
        for label, wasNear in pairs(wasNearWarp) do
            if wasNear then
                logWarpTransition(label, current_level)
                wasNearWarp[label] = false
                nearWarpTimer[label] = nil
            end
        end
    end
end

function logLevel(currentLevel, intendedLevel)
    local currentLevelAbbr = LocationMap[currentLevel] and LocationMap[currentLevel][2]
    local intendedLevelAbbr = LocationMap[intendedLevel] and LocationMap[intendedLevel][2]
    if intendedLevelAbbr ~= nil and currentLevelAbbr ~= nil and not warp_log[intendedLevelAbbr] then
        warp_log[intendedLevelAbbr] = currentLevelAbbr
        saveWarpLog()
    end
end

-- Log warp transitions and save
function logWarpTransition(warpPoint, currentLevel)
    if currentLevel ~= 6 and warpPoint then
        local currentLevelAbbr = LocationMap[currentLevel] and LocationMap[currentLevel][2] or "Unknown"
        if not warp_log[warpPoint] then
            warp_log[warpPoint] = currentLevelAbbr
            -- console.write(string.format("Warp from %s leads to %s\n", warpPoint, currentLevelAbbr))
            saveWarpLog() -- Save whenever a new warp is logged
        end
    end
end

-- Reset warp log and clear the file
function resetWarpLog(currentLevel)
    if currentLevel == 1 and not warpLogReset then
        warp_log = {}
        starTracker = {} -- Reset the star tracker
        saveWarpLog()
        console.write("Warp log has been reset.\n")
        warpLogReset = true -- Prevent further resets while in menu
    elseif currentLevel ~= 1 then
        warpLogReset = false -- Reset the flag when leaving the menu
    end
end

-- Load warp log at the start
loadWarpLog()

local function totalLoggedStars()
    local total = 0
    for _, count in pairs(starTracker) do
        total = total + count
    end
    return total
end

-- Function to check if mario_action matches any value in a list
function isMarioActionInList(action, actionList)
    for _, value in ipairs(actionList) do
        if action == value then
            return true -- Found a match
        end
    end
    return false -- No match found
end

OR, XOR, AND = 1, 3, 4

function bitoper(a, b, oper)
    local r, m, s = 0, 2 ^ 31
    repeat
        s, a, b = a + b + m, a % m, b % m
        r, m = r + m * oper % (s - a - b), m / 2
    until m < 1
    return r
end

-- Function to render GUI elements
function renderGui()
    local gameWidth = client.bufferwidth()
    local gameHeight = client.bufferheight()
    local screenWidth = client.screenwidth()
    local screenHeight = client.screenheight()

    local padWidth = math.floor((gameHeight * (16 / 9)) - gameWidth)

    local fontSize = math.floor(gameHeight / 50)
    local charWidth = math.floor(fontSize / 1.6)

    gui.clearGraphics()

    client.SetGameExtraPadding(0, 0, padWidth, 0)

    if displayData.taint_detected then
        for i = 1, 100 do -- Adjust the number to spam more or fewer instances
            local middle_x = math.floor(gameWidth / 2) - 200
            local middle_y = screenHeight - math.floor(screenHeight / 6)
            gui.drawText(middle_x, middle_y - 200, "TAINT DETECTED", "red", nil, 40, "Arial", "bold")
        end
    end

    gui.drawString(gameWidth + math.floor(padWidth / 2), fontSize, "IronMario Tracker", "lightblue", nil, fontSize,
        fontFace, nil, "center")
    gui.drawString(gameWidth + math.floor(padWidth / 2), fontSize * 2, "v1.0.2u1", "gray", nil, fontSize, fontFace, nil,
        "center")

    if not validVersion then
        gui.drawString(gameWidth + math.floor(padWidth / 2), fontSize * 10, "Incompatible\nROM version!", "red", nil,
            fontSize * 2, fontFace, nil, "center")
        gui.drawString(gameWidth + math.floor(padWidth / 2), fontSize * 15, "Expected: " .. validRomVersion, "red", nil,
            fontSize, fontFace, nil, "center")
        gui.drawString(gameWidth + math.floor(padWidth / 2), fontSize * 16, "Running: " .. romVersion, "red", nil,
            fontSize, fontFace, nil, "center")
        return
    end

    gui.drawString(gameWidth, fontSize + (fontSize * 3), "Attempt #: " .. displayData.attemptCount, nil, nil, fontSize,
        fontFace)

    gui.drawString(gameWidth, fontSize + (fontSize * 4), "Run Time: " .. formatElapsedTime(displayData.elapsedTime),
        nil, nil, fontSize, fontFace)
    gui.drawString(gameWidth, fontSize + (fontSize * 5), "Stars: " .. displayData.stars, nil, nil, fontSize, fontFace)
    gui.drawString(gameWidth, fontSize + (fontSize * 6), "Level: " .. displayData.levelAbbr, nil, nil, fontSize,
        fontFace)
    gui.drawString(gameWidth, fontSize + (fontSize * 7), "Seed: " .. displayData.seed, nil, nil, fontSize, fontFace)

    if displayData.logged_run and displayData.pbStars == displayData.stars then
        gui.drawString(gameWidth, fontSize + (fontSize * 8), "RUN OVER - NEW PB!", "red", nil, fontSize, fontFace)
    elseif displayData.logged_run then
        gui.drawString(gameWidth, fontSize + (fontSize * 8), "RUN OVER", "red", nil, fontSize, fontFace)
    end

    gui.drawString(gameWidth, fontSize + (fontSize * 9), "PB Stars: " .. displayData.pbStars, "yellow", nil, fontSize,
        fontFace)

    gui.drawString(gameWidth, fontSize + (fontSize * 11), "== Warp Map ==", "orange", nil, fontSize, fontFace)

    local drawIndex = 12

    if next(warp_log) then
        for warpFrom, warpTo in pairs(warp_log) do
            gui.drawString(gameWidth, fontSize + (fontSize * drawIndex), string.format("  %s → %s", warpFrom, warpTo),
                nil, nil, fontSize, fontFace)
            drawIndex = drawIndex + 1
        end
    end

    drawIndex = drawIndex + 1

    gui.drawString(gameWidth, fontSize + (fontSize * drawIndex), "== Stars Collected ==", "yellow", nil, fontSize,
        fontFace)

    drawIndex = drawIndex + 1

    if next(starTracker) then
        for levelAbbr, starCount in pairs(starTracker) do
            gui.drawString(gameWidth, fontSize + (fontSize * drawIndex),
                string.format("  %s: %d", levelAbbr, starCount), nil, nil, fontSize, fontFace)
            drawIndex = drawIndex + 1
        end
    end

    local iconSize = math.floor(gameHeight / 12)

    gui.drawImage("sm64_rando_tracker/logo.png", (gameWidth + padWidth) - iconSize, 0, iconSize, iconSize)
end

---------------------------------
---------- Main Action ----------
---------------------------------

while true do
    frameCounter = frameCounter + 1

    -- This is very time sensitive and needs to run each frame.
    damage_time = memory.readbyte(addressMarioHurtCounter) -- this tracks how long mario should take damage (does not apply underwater)
    if damage_time > 0 and run_start and elapsedTime > 0 then
        damage_was_taken = true
    end

    if frameCounter >= 30 then -- Run logic every 30 frames
        frameCounter = 0 -- Reset the counter

        previous_hp = hp
        previous_level = level
        previous_seed = seed
        hp = memory.read_u16_be(addressHudHealthWedges)
        coins = memory.read_u16_be(addressHudCoins)
        stars = memory.read_u16_be(addressHudStars)
        level = memory.read_u16_be(addressCurrLevelNum)
        terrain = memory.read_u16_be(addressMarioGeometryCurrFloorType)
        seed = memory.read_u32_be(addressRandomizerGameSeed)
        mario_action = memory.read_u32_be(addressMarioAction)
        mario_pos = read3float(addressMarioPos)

        local delayedWarpOp = memory.read_u16_be(addressDelayedWarpOp)

        local in_water = bitoper(mario_action, 0xC0, AND) == 0xC0
        local marioInput = memory.read_u16_be(addressMarioInput)
        local marioFlags = memory.read_u32_be(addressMarioInput)

        local in_gas = bitoper(marioInput, 0x100, AND) == 0x100
        local intangible = bitoper(mario_action, 0x1000, AND) == 0x1000
        local metal_cap = bitoper(marioFlags, 4, AND) == 4

        local taking_gas_damage = in_gas and not intangible and not metal_cap

        -- Get the level name
        local levelName = LocationMap[level] and LocationMap[level][1] or "Unknown Level"
        local levelAbbr = LocationMap[level] and LocationMap[level][2] or "Unknown"
        local levelId = level

        -- Detect and log warp transitions
        local intended_level = memory.read_u32_be(addressCurrIntendedLevel)
        if (intended_level ~= previous_intended_level) then
            logLevel(level, intended_level)
        end
        previous_intended_level = intended_level

        -- local warpPoint = checkTerrainForWarp(terrain)
        -- if warpPoint then
        --     logWarpTransition(warpPoint, level)
        -- end

        -- local warpLabel = checkProximityToWarpPoints(mario_pos, warpCoords)
        -- if warpLabel then
        --     checkAndLogWarpTransition(mario_pos, warpCoords, previous_level, level)
        -- end

        -- Start the timer when leaving the menu
        startRunTimer(level)
        -- Reset the warp log if in Menu (level 1)
        resetWarpLog(level)

        -- Calculate elapsed time
        if runStartTime and not logged_run then
            elapsedTime = os.time() - runStartTime
        end

        -- Check if this is a PB run and update the PB
        if stars > pbStars and stars <= 120 then
            pbStars = stars
            savePB(pbStars) -- Save new PB if valid
        end

        -- Update the star tracker
        if level > 1 and level ~= 16 and stars then
            local levelAbbr = LocationMap[level] and LocationMap[level][2] or "Unknown"
            if levelAbbr ~= "Unknown" then
                -- Check if there are unlogged stars
                if totalLoggedStars() < stars then
                    -- Initialize star count for the level if not already set
                    starTracker[levelAbbr] = starTracker[levelAbbr] or 0

                    -- Log the new star
                    starTracker[levelAbbr] = starTracker[levelAbbr] + 1
                    console.write(string.format("Logged 1 star for %s. Total: %d stars.\n", levelAbbr,
                        starTracker[levelAbbr]))
                end
            end
        end

        -- if isMarioActionInList(mario_action, mario_on_shell) then
        --     taint_detected = true
        -- else
        --     taint_detected = false
        --     gui.clearGraphics()
        -- end
        -- Checks to see if mario has taken damage or not by using the damage meter.
        if damage_was_taken and not in_water and not taking_gas_damage and not run_end and run_start and elapsedTime > 5 then
            reason = string.format("Took damage from Enemy or fall")
            run_end = true
            shouldSaveAttempt = true

            -- Snowman Land water damage
        elseif in_water and level == 10 and hp < previous_hp and not run_end and run_start then
            reason = "Took cold water damage in Snowman Land"
            shouldSaveAttempt = true

            -- General water damage
        elseif in_water and isMarioActionInList(mario_action, mario_water_damage) and not run_end and run_start then
            reason = "Suspected water damage"
            run_end = true
            shouldSaveAttempt = true

            -- Hazy Gas Death
        elseif level == 7 and hp < previous_hp and not in_water and not run_end and run_start then
            reason = "Hazy Gas Got You"
            shouldSaveAttempt = true

        elseif not LevelHasWater(level) and not run_end and run_start and hp < previous_hp then
            reason = "Took Damage"
            shouldSaveAttempt = true

            -- Mario falls out of course
            -- elseif isMarioActionInList(mario_action, mario_fell_out_of_course) and not run_end and run_start then
        elseif ((delayedWarpOp == 18) or (delayedWarpOp == 20)) and not run_end and run_start then
            reason = "Mario Fell out of course"
            run_end = true
            shouldSaveAttempt = true
        end

        -- Perform save and print only if needed
        if shouldSaveAttempt and not logged_run then
            print(reason)
            saveAttempt(attemptDataCsv, attemptsFile, seed, attemptCount, stars, levelAbbr,
                formatElapsedTime(elapsedTime), starTracker)
            logged_run = true
            run_start = false
        end

        if run_end and seed ~= previous_seed then
            attemptCount = attemptCount + 1
            run_end = false
            damage_was_taken = false
            logged_run = false
            taint_detected = false
            shouldSaveAttempt = false
            reason = ""
        end

        ---------------------------------
        ----- Getting GUI Variables -----
        ---------------------------------

        -- Update display data for GUI
        displayData.attemptCount = attemptCount
        displayData.elapsedTime = elapsedTime
        displayData.stars = stars
        displayData.seed = seed
        displayData.levelAbbr = levelAbbr
        displayData.levelId = levelId
        displayData.marioAction = mario_action
        displayData.pbStars = pbStars
        displayData.runStatus = "RUN OVER"
        displayData.runStatusPB = "RUN OVER - NEW PB!"
        displayData.warpLog = warp_log
        displayData.logged_run = logged_run
        displayData.taint_detected = taint_detected
        displayData.marioInWater = in_water
        displayData.marioPos = mario_pos
    end

    --------------------------------
    ----- Display Tracker Info -----
    --------------------------------

    if (emu.framecount() % 60 == 0) then
        renderGui()
    end

    emu.frameadvance()
end
