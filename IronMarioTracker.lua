-- IronMario Tracker Script
-- This script tracks various aspects of a run (attempt count, stars, warp mapping, etc.) by reading emulator memory,
-- logging data to files, and rendering an on-screen overlay.
-- It uses lunajson for JSON encoding and pl.tablex for deep table functions.
local json = require("lib.lunajson") -- JSON encoding/decoding library
local tablex = require("lib.pl.tablex") -- Extended table functions (e.g., deepcopy, deepcompare)

local ROM_HASH = "7EE741D097C660E74330FAB27FC83727592A57EA"

-- Main configuration table that holds version info, file paths, memory addresses, and user data.
local CONFIG = {
    TRACKER_VERSION = '1.2',
    FONT_FACE = 'Lucida Console',
    SHOW_SONG_TITLE = false, -- Flag to toggle song title display on the UI.
    SHOW_CAP_TIMER = false, -- Flag to toggle cap timer display on the UI.
    FILES = {
        ATTEMPT_COUNT = 'usr/attempts.txt', -- File to record total attempt count.
        ATTEMPT_DATA = 'usr/attempts_data.csv', -- CSV file for detailed run attempt data.
        PB_COUNT = 'usr/pb_stars.txt', -- File for storing the personal best (PB) star count.
        SONG_INFO = 'usr/song_info.txt', -- File for storing song info. (Location, Title)
        WARP_LOG = 'usr/warp_log.json' -- File to log warp map data as JSON.
    },
    MEM = {
        MARIO_BASE = 0x801e1940, -- Base memory address for Mario-related data.
        HUD_BASE = 0x801e1930, -- Base memory address for HUD elements.
        CURRENT_LEVEL_ID = 0x801d0508, -- Address for the current level ID.
        CURRENT_SEED = 0x8020f5b8, -- Address for the current run's seed.
        DELAYED_WARP_OP = 0x801e191c, -- Address for delayed warp operation code.
        INTENDED_LEVEL_ID = 0x801e06cc, -- Address for the intended level after a warp.
        CURRENT_SONG_ID = 0x801d522e -- Address for the current song ID.
    },
    USER = {
        ATTEMPTS = 0, -- Total number of attempts (will be updated from file).
        PB_STARS = 0 -- Personal best star count (will be updated from file).
    },
    BACKGROUND_IMAGE = "(None)" -- Default background image for the UI.
}

-- Additional memory addresses for Mario-specific data derived from MARIO_BASE.
CONFIG.MEM.MARIO = {
    INPUT = CONFIG.MEM.MARIO_BASE + 0x2, -- Address for Mario's input flags or status.
    ACTION = CONFIG.MEM.MARIO_BASE + 0xC, -- Address for Mario's current action/state.
    POS = CONFIG.MEM.MARIO_BASE + 0x3C, -- Address for Mario's 3D position (stored as floats).
    HURT_COUNTER = CONFIG.MEM.MARIO_BASE + 0xB2, -- Address for a counter indicating recent damage.
    CAP_TIMER = CONFIG.MEM.MARIO_BASE + 0xBE -- Address for counting time remaining on cap.
}

-- Memory addresses for HUD-related data.
CONFIG.MEM.HUD = {
    STARS = CONFIG.MEM.HUD_BASE + 0x4, -- Address for the number of stars displayed.
    HEALTH = CONFIG.MEM.HUD_BASE + 0x6 -- Address for Mario's health.
}

-- Level data configuration including level names and abbreviations.
-- Note: There are duplicate keys (e.g., several entries for key 3626007); only the last assignment will persist.
CONFIG.LEVEL_DATA = {
    HAS_NO_WATER = {9, 24, 4, 22, 8, 14, 15, 27, 31, 29, 18, 17, 30, 19}, -- Currently unused.
    LOCATION_MAP = {
        [0] = {"", ""},
        [1] = {"Menu", "Menu"},
        [10] = {"Snowman's Land", "SL"},
        [11] = {"Wet Dry World", "WDW"},
        [12] = {"Jolly Roger Bay", "JRB"},
        [13] = {"Tiny Huge Island", "THI"},
        [14] = {"Tick Tock Clock", "TTC"},
        [15] = {"Rainbow Ride", "RR"},
        [16] = {"Outside Castle", "Outside"},
        [17] = {"Bowser in the Dark World", "BitDW"},
        [18] = {"Vanish Cap Under the Moat", "Vanish"},
        [19] = {"Bowser in the Fire Sea", "BitFS"},
        [20] = {"Secret Aquarium", "SA"},
        [22] = {"Lethal Lava Land", "LLL"},
        [23] = {"Dire Dire Docks", "DDD"},
        [24] = {"Whomp's Fortress", "WF"},
        [26] = {"Garden", "Garden"},
        [27] = {"Peach's Slide", "PSS"},
        [28] = {"Cavern of the Metal Cap", "Metal"},
        [29] = {"Tower of the Wing Cap", "Wing"},
        [30] = {"Bowser Fight 1", "Bowser1"},
        [31] = {"Wing Mario Over the Rainbow", "WMotR"},
        [36] = {"Tall Tall Mountain", "TTM"},
        -- Duplicate keys: Only the last assignment for key 3626007 will be used.
        -- [3626007] = {"Basement", "B1F"},
        -- [3626007] = {"Second Floor", "2F"},
        -- [3626007] = {"Third Floor", "3F"},
        [3626007] = {"Bowser in the Sky", "BitS"},
        [4] = {"Big Boo's Haunt", "BBH"},
        [5] = {"Cool Cool Mountain", "CCM"},
        [6] = {"Castle", "Castle"},
        [7] = {"Hazy Maze Cave", "HMC"},
        [8] = {"Shifting Sand Land", "SSL"},
        [9] = {"Bob-Omb Battlefield", "BoB"}
    }
}

CONFIG.MUSIC_DATA = {
    SONG_MAP = {
        -- [0] = "--- - ---",
        -- [1] = "Super Mario 64 - Collect a Star",
        -- [2] = "Super Mario 64 - course star select",
        -- [3] = "Super Mario 64 - Bowser's Message",
        -- [4] = "Super Mario 64 - Credits",
        -- [5] = "Super Mario 64 - Puzzle Solved",
        -- [6] = "Super Mario 64 - Toad Message",
        -- [7] = "Super Mario 64 - Victory Theme",
        -- [8] = "Super Mario 64 - Ending",
        -- [9] = "Super Mario 64 - Key Collection",
        -- [10] = "Super Mario 64 - Star Spawn",
        -- [11] = "Super Mario 64 - High Score",
        -- updated 1.2.0
        [12] = "Super Mario 64 - Endless Staircase",
        [13] = "Super Mario 64 - Merry-Go-Round",
        [14] = "Super Mario 64 - Title Theme",
        [15] = "Super Mario 64 - Bob-omb Battlefield",
        [16] = "Super Mario 64 - Inside the Castle Walls",
        [17] = "Super Mario 64 - Dire, Dire Docks",
        [18] = "Super Mario 64 - Lethal Lava Land",
        [19] = "Super Mario 64 - Koopa's Theme",
        [20] = "Super Mario 64 - Snow Mountain",
        [21] = "Super Mario 64 - Slider",
        [22] = "Super Mario 64 - Haunted House",
        [23] = "Super Mario 64 - Piranha Plant's Lullaby",
        [24] = "Super Mario 64 - Cave Dungeon",
        [25] = "Super Mario 64 - Powerful Mario",
        [26] = "Super Mario 64 - Metallic Mario",
        [27] = "Super Mario 64 - Koopa's Road",
        [28] = "??? - Race Fanfare",
        [29] = "Super Mario 64 - Stage Boss",
        [30] = "Super Mario 64 - Ultimate Koopa",
        [31] = "Super Mario 64 - File Select",
        [32] = "Super Mario 64 - Powerful Mario",
        [33] = "Super Mario 64 - Title Theme",
        [34] = "??? - Drown",
        [35] = "IronMario - Dumb Ways to Die",
        [36] = "Bomberman Hero - Redial",
        [37] = "Nintendo Wii Console - Wii Shop Channel",
        -- not updated past 1.2.0:
        [38] = "Chrono Trigger - Delightful Spekkio",
        [39] = "Castlevania: Order of Ecclesia - A Prologue",
        [40] = "Diddy Kong Racing - Darkmoon Caverns",
        [41] = "Diddy Kong Racing - Frosty Village",
        [42] = "Diddy Kong Racing - Spacedust Alley, Star City",
        [43] = "Donkey Kong Country - Aquatic Ambience",
        [44] = "Donkey Kong Country 2 - Forest Interlude",
        [45] = "Donkey Kong Country 2 - Stickerbrush Symphony",
        [46] = "Diddy Kong Racing - Greenwood Village",
        [47] = "Donkey Kong Country 2 - In a Snow-Bound Land",
        [48] = "Earthbound - Home Sweet Home",
        [49] = "Earthbound - Onett",
        [50] = "TLoZ: Ocarina of Time - Gerudo Valley",
        [51] = "Pokemon Shuffle - Stage (Hard)",
        [52] = "Banjo-Kazooie - Gruntilda's Lair",
        [53] = "Kirby: Nightmare in Dream Land - Butter Building",
        [54] = "Kirby 64: The Crystal Shards - Shiver Star",
        [55] = "Kirby's Adventure - Yogurt Yard",
        [56] = "Kirby Super Star - Mine Cart Riding",
        [57] = "TLoZ: Majora's Mask - Clock Town Day 1",
        [58] = "M&L: Partners in Time - Thwomp Caverns",
        [59] = "Mario Kart 8 - Rainbow Road",
        [60] = "Mario Kart 64 - Koopa Beach",
        [61] = "Mario Kart Wii - Maple Treeway",
        [62] = "Mega Man 3 - Spark Man Stage",
        [63] = "Mega Man Battle Network 5 - Hero Theme",
        [64] = "Mario Kart 64 - Moo Moo Farm, Yoshi Valley",
        [65] = "New Super Mario Bros. - Athletic Theme",
        [66] = "New Super Mario Bros. - Desert Theme",
        [67] = "New Super Mario Bros. U - Overworld",
        [68] = "New Super Mario Bros. Wii - Forest",
        [69] = "TLoZ: Ocarina of Time - Lost Woods",
        [70] = "Pilotwings - Light Plane",
        [71] = "Pokemon Diamond & Pearl - Eterna Forest",
        [72] = "Pokemon HeartGold & SoulSilver - Lavender Town",
        [73] = "Mario Party - Mario's Rainbow Castle",
        [74] = "Bomberman 64 - Red Mountain",
        [75] = "Deltarune - Rude Buster",
        [76] = "Super Mario 3D World - Overworld",
        [77] = "Super Mario Sunshine - Sky and Sea",
        [78] = "Snowboard Kids - Big Snowman",
        [79] = "Sonic Adventure - Emerald Coast",
        [80] = "Sonic the Hedgehog - Green Hill Zone",
        [81] = "Super Castlevania 4 - The Submerged City",
        [82] = "Super Mario Land - Birabuto Kingdom",
        [83] = "Super Mario RPG - Beware the Forest's Mushrooms",
        [84] = "Super Mario Sunshine - Delfino Plaza",
        [85] = "Super Mario Sunshine - Gelato Beach",
        [86] = "Yoshi's Island - Crystal Caves",
        [87] = "TLoZ: Ocarina of Time - Water Temple",
        [88] = "Wave Race 64 - Sunny Beach",
        [89] = "Whomp's Floating Habitat (Original by MariosHub)",
        [90] = "TLoZ: Ocarina of Time - Kokiri Forest",
        [91] = "TLoZ: Ocarina of Time - Zora's Domain",
        [92] = "TLoZ: Ocarina of Time - Kakariko Village",
        [93] = "A Morning Jog (Original by TheGael95)",
        [94] = "TLoZ: The Wind Waker - Outset Island",
        [95] = "Super Paper Mario - Flipside",
        [96] = "Super Mario Galaxy - Ghostly Galaxy",
        [97] = "Super Mario RPG - Nimbus Land",
        [98] = "Super Mario Galaxy - Battlerock Galaxy",
        [99] = "Sonic Adventure - Windy Hill",
        [100] = "Super Paper Mario - The Overthere Stair",
        [101] = "Super Mario Sunshine - Secret Course",
        [102] = "Super Mario Sunshine - Bianco Hills",
        [103] = "Super Paper Mario - Lineland Road",
        [104] = "Paper Mario: The Thousand-Year Door - X-Naut Fortress",
        [105] = "M&L: Bowser's Inside Story - Bumpsy Plains",
        [106] = "Super Mario World - Athletic Theme",
        [107] = "TLoZ: Skyward Sword - Skyloft",
        [108] = "Super Mario World - Castle",
        [109] = "Super Mario Galaxy - Comet Observatory",
        [110] = "Banjo-Kazooie - Freezeezy Peak",
        [111] = "Mario Kart DS - Waluigi Pinball",
        [112] = "Kirby 64: The Crystal Shards - Factory Inspection",
        [113] = "Donkey Kong 64 - Creepy Castle",
        [114] = "Paper Mario 64 - Forever Forest",
        [115] = "Super Mario Bros. - Bowser's Theme (Remix)",
        [116] = "TLoZ: Twilight Princess - Gerudo Desert",
        [117] = "Yoshi's Island - Overworld",
        [118] = "Donkey Kong Country 2 - Hot Head Bop",
        [119] = "Donkey Kong 64 - Angry Aztec",
        [120] = "M&L: Partners in Time - Yoshi's Village",
        [121] = "Touhou 10: Mountain of Faith - Youkai Mountain",
        [122] = "M&L: Bowser's Inside Story - Deep Castle",
        [123] = "Paper Mario: The Thousand-Year Door - Petal Meadows",
        [124] = "Mario Party - Yoshi's Tropical Island",
        [125] = "Super Mario 3D World - Piranha Creek",
        [126] = "Bomberman 64 - Blue Resort",
        [127] = "Paper Mario 64 - Dry Dry Desert",
        [128] = "Rayman - Band Land",
        [129] = "Donkey Kong 64 - Hideout Helm",
        [130] = "Donkey Kong 64 - Frantic Factory",
        [131] = "Super Paper Mario - Sammer's Kingdom",
        [132] = "Super Mario Galaxy - Purple Comet",
        [133] = "TLoZ: Majora's Mask - Stone Tower Temple",
        [134] = "Banjo-Kazooie - Bubblegloop Swamp",
        [135] = "Banjo-Kazooie - Gobi's Valley",
        [136] = "Bomberman 64 - Black Fortress",
        [137] = "Donkey Kong 64 - Fungi Forest",
        [138] = "Paper Mario: The Thousand-Year Door - Riddle Tower",
        [139] = "Paper Mario: The Thousand-Year Door - Rogueport Sewers",
        [140] = "Super Mario Galaxy 2 - Honeybloom Galaxy",
        [141] = "Pokemon Mystery Dungeon - Sky Tower",
        [142] = "Super Mario Bros. 3 - Overworld",
        [143] = "Super Mario RPG - Mario's Pad",
        [144] = "Super Mario RPG - Sunken Ship",
        [145] = "Super Mario Galaxy - Buoy Base Galaxy",
        [146] = "Donkey Kong 64 - Crystal Caves",
        [147] = "Super Paper Mario - Floro Caverns",
        [148] = "Yoshi's Story - Title Theme",
        [149] = "TLoZ: Twilight Princess - Lake Hylia",
        [150] = "Mario Kart 64 - Frappe Snowland",
        [151] = "Donkey Kong 64 - Gloomy Galleon",
        [152] = "Mario Kart 64 - Bowser's Castle",
        [153] = "Mario Kart 64 - Rainbow Road",
        -- new music, 1.1.0
        [154] = "Banjo Kazooie - Mumbo's Mountain",
        [155] = "Donkey Kong Country 2 - Rigging/Jib Jig",
        [156] = "Donkey Kong Country 2 - Welcome to Crocodile Isle",
        [157] = "TLoZ: The Wind Waker - Dragon Roost Island",
        [158] = "Pokemon Black and White - Accumula Town",
        [159] = "Pokemon HeartGold and SoulSilver - Vermilion City",
        [160] = "Undertale - Snowdin Town",
        [161] = "Undertale - Bonetrousle",
        [162] = "Undertale - Death by Glamour",
        [163] = "Undertale - Home",
        [164] = "Undertale - Ruins",
        [165] = "Undertale - Spider Dance",
        [166] = "Undertale - Waterfall",
        -- new music for 1.2.0
        [167] = "Bomberman 64 - Green Garden",
        [168] = "Animal Crossing - Go K.K. Rider!",
        [169] = "Banjo-Kazooie - Click Clock Wood",
        [170] = "Killer Instinct - Title Theme",
        [171] = "TLoZ: Majora's Mask - Astral Observatory",
        [172] = "TLoZ: Majora's Mask - Pirates' Fortress",
        [173] = "Mega Man & Bass - Cold Man",
        [174] = "Metroid Prime - Magmoor Caverns",
        [175] = "Metroid Prime - Phendrana Drifts",
        [176] = "M&L: Superstar Saga - Hoohoo Village",
        [177] = "Mega Man 2 - Flash Man Stage",
        [178] = "Mega Man 2 - Wily Stage 1",
        [179] = "Mega Man 3 - Needle Man Stage",
        [180] = "Mega Man 3 - Shadow Man Stage",
        [181] = "Mega Man 3 - Title Theme",
        [182] = "Mega Man X - Chill Penguin Stage",
        [183] = "Mega Man X - Flame Mammoth Stage",
        [184] = "Mega Man X - Opening Stage",
        [185] = "Mega Man X - Spark Mandrill Stage",
        [186] = "Mega Man X - Storm Eagle Stage",
        [187] = "Mega Man X2 - Bubble Crab Stage",
        [188] = "Mother 3 - Going Alone",
        [189] = "Paper Mario: Color Splash - Fight!",
        [190] = "Pictionary - Title Screen",
        [191] = "Pilotwings 64 - Birdman",
        [192] = "Pizza Tower - Tropical Crust",
        [193] = "Pizza Tower - Extraterrestrial Wahwahs",
        [194] = "Pokemon Diamond & Pearl - Route 216",
        [195] = "Pokemon FireRed & LeafGreen - Gym Battle",
        [196] = "Pokemon FireRed & LeafGreen - Trainer Battle",
        [197] = "Chameleon Twist 2 - Sky Land",
        [198] = "Pokemon Mystery Dungeon - Chasm Cave",
        [199] = "Pokemon Mystery Dungeon - Dark Wasteland",
        [200] = "Pokemon Mystery Dungeon - Great Canyon",
        [201] = "Pokemon Mystery Dungeon - Hidden Highland",
        [202] = "Pokemon Mystery Dungeon - Mt. Blaze",
        [203] = "Pokemon Mystery Dungeon - Mt. Thunder",
        [204] = "Pokemon Mystery Dungeon - Northern Desert",
        [205] = "Pokemon Mystery Dungeon - Random Dungeon Theme 3",
        [206] = "Pokemon Mystery Dungeon - Temporal Tower",
        [207] = "Sonic Adventure 2 Battle - City Escape",
        [208] = "Silver Surfer - Stage 1",
        [209] = "Super Mario 3D World - Sunshine Seaside",
        [210] = "Sonic the Hedgehog - Star Light Zone",
        [211] = "Sonic the Hedgehog 3 - Final Boss",
        [212] = "Sonic Mania - Tabloid Jargon",
        [213] = "Star Fox - Fortuna",
        [214] = "Star Fox - Corneria",
        [215] = "Sonic the Hedgehog 3 - Desert Palace Zone",
        [216] = "Street Fighter II - Guile's Theme",
        [217] = "Tetris Attack - Forest Stage",
        [218] = "TLoZ: Majora's Mask - Deku Palace",
        [219] = "TLoZ: Majora's Mask - Milk Bar",
        [220] = "TLoZ: Skyward Sword - Knight Academy",
        [221] = "Wario Land: Shake It! - Stonecarving City",
        [222] = "Mii Channel",
        [223] = "Wii Party - Roll to the Goal",
        [224] = "Yoshi's Island - Big Boss",
        [225] = "Yoshi's Island - Athletic",
        [226] = "Yooka-Laylee - Tropic Trials",
        [227] = "DuckTales - The Moon",
        [228] = "F-Zero - Big Blue",
        [229] = "F-Zero - Mute City",
        [230] = "Katamari Damacy - Katamari on the Rocks",
        [231] = "Kirby and the Forgotten Land - Fast-Flowing Waterworks",
        [232] = "Knuckles' Chaotix - Door Into Summer",
        [233] = "M&L: Dream Team - Try, Try Again",
        [234] = "M&L: Superstar Saga - Oho Ocean",
        [235] = "Mario Kart 7 - Piranha Plant Slide",
        [236] = "Mario Kart 8 - Sunshine Airport",
        [237] = "Mario Kart 8 - Sweet Sweet Canyon",
        [238] = "Mario Kart Wii - Coconut Mall",
        [239] = "Mega Man X - Boomer Kuwanger Stage",
        [240] = "Metroid Fusion - Main Deck",
        [241] = "Paper Mario: Color Splash - Cherry Lake",
        [242] = "Pizza Tower - Good Eatin'",
        [243] = "Super Mario Bros. Wonder - Overworld",
        [244] = "Sonic the Hedgehog 3 - Ice Cap Zone",
        [245] = "Star Fox 64 - Area 6",
        [246] = "Star Fox 64 - Sector Y"
    }
}

local VALID_ROM_VERSION = nil
print(gameinfo.getromhash())
if gameinfo.getromhash() == ROM_HASH then
    VALID_ROM_VERSION = true
else
    VALID_ROM_VERSION = false
end

-- Define possible run states.
local run_state = {
    INACTIVE = 0, -- Run has not started.
    ACTIVE = 1, -- Run is in progress.
    PENDING = 2, -- Run has ended; data pending write.
    COMPLETE = 3 -- Run data has been fully processed.
}

-- Main state table that stores runtime data for input, Mario, run metrics, and game info.
local state = {
    input = {
        music_toggle_pressed = false -- Flag to track toggling of song title display.
    },
    mario = {}, -- Will hold Mario's position, velocity, health, etc.
    run = {
        status = run_state.INACTIVE, -- Current run state.
        stars = 0, -- Total stars collected during the run.
        warp_map = {}, -- Map of intended warp destinations to actual warp outcomes.
        star_map = {}, -- Mapping of levels to star counts collected.
    },
    game = {
        level_id = 1 -- Current level ID; default value.
    }
}

local BACKGROUND_IMAGES = {"(None)", "Cave", "City", "Desert", "Fire", "Forest", "Fuji", "Mountains", "Ocean", "Pattern", "Sky",
                           "Storm", "CaptWaffle"}

-- Table to store the previous state (for change detection in UI rendering).
local last_state = {}

local config_form = nil -- Placeholder for the configuration form.

-- Initialize the attempt data file if it doesn't exist by writing a CSV header.
local function init_attempt_data_file()
    local file = io.open(CONFIG.FILES.ATTEMPT_DATA, "r")
    if file then
        file:close() -- File exists, so do nothing.
        return
    end

    file = io.open(CONFIG.FILES.ATTEMPT_DATA, "w")
    if file then
        file:write("AttemptNumber,SeedKey,TimeStamp,Stars,EndLevel,EndCause,StarsCollected\n")
        file:close()
    end
end

init_attempt_data_file() -- Call the initialization function.

-- Read the attempt count from file; if file is missing or empty, default to 0.
local function read_attempts_file()
    local file = io.open(CONFIG.FILES.ATTEMPT_COUNT, "r")
    if file then
        CONFIG.USER.ATTEMPTS = tonumber(file:read("*all"))
        file:close()
    else
        CONFIG.USER.ATTEMPTS = 0
    end
end

-- Read the personal best stars count from file.
local function read_pb_stars_file()
    local file = io.open(CONFIG.FILES.PB_COUNT, "r")
    if file then
        CONFIG.USER.PB_STARS = tonumber(file:read("*all"))
        file:close()
    else
        CONFIG.USER.PB_STARS = 0
    end
end

-- Write the current attempt count to its file.
local function write_attempts_file()
    local file = io.open(CONFIG.FILES.ATTEMPT_COUNT, "w")
    if file then
        file:write(CONFIG.USER.ATTEMPTS)
        file:close()
    end
end

-- Write the personal best stars count to file.
local function write_pb_stars_file()
    local file = io.open(CONFIG.FILES.PB_COUNT, "w")
    if file then
        file:write(CONFIG.USER.PB_STARS)
        file:close()
    end
end

-- Retrieve the full song name based on the song ID.
local function get_song_name(song_id)
    local song_info = CONFIG.MUSIC_DATA.SONG_MAP[song_id]
    if song_info then
        return song_info
    end
    return "Unknown"
end

-- Utility function to read three consecutive floats from a given memory address.
local function read3float(base)
    local arr = {}
    for i = 1, 3 do
        arr[i] = memory.readfloat(base + 4 * (i - 1), true)
    end
    return arr
end

-- Get the full level name based on the level ID using LOCATION_MAP.
local function get_level_name(level_id)
    if CONFIG.LEVEL_DATA.LOCATION_MAP[level_id] then
        return CONFIG.LEVEL_DATA.LOCATION_MAP[level_id][1]
    else
        return "Unknown"
    end
end

-- Get the abbreviated level name based on the level ID.
local function get_level_abbr(level_id)
    if CONFIG.LEVEL_DATA.LOCATION_MAP[level_id] then
        return CONFIG.LEVEL_DATA.LOCATION_MAP[level_id][2]
    else
        return "Unknown"
    end
end

-- Update the game state by reading from memory and updating our state tables.
local function update_game_state()
    last_state = tablex.deepcopy(state) -- Store the previous state for later comparison.

    state.last_updated_time = os.time() -- Update the timestamp.
    state.game.delayed_warp_op = memory.read_u16_be(CONFIG.MEM.DELAYED_WARP_OP)
    state.game.intended_level_id = memory.read_u32_be(CONFIG.MEM.INTENDED_LEVEL_ID)
    state.game.level_id = memory.read_u16_be(CONFIG.MEM.CURRENT_LEVEL_ID)
    state.game.song = memory.read_u16_be(CONFIG.MEM.CURRENT_SONG_ID)
    state.mario.action = memory.read_u32_be(CONFIG.MEM.MARIO.ACTION)
    state.mario.flags = memory.read_u32_be(CONFIG.MEM.MARIO.INPUT) -- Read flags from the same address.
    state.mario.cap_timer = memory.read_u16_be(CONFIG.MEM.MARIO.CAP_TIMER)
    state.mario.hp = memory.read_u16_be(CONFIG.MEM.HUD.HEALTH)
    state.mario.input = memory.read_u16_be(CONFIG.MEM.MARIO.INPUT) -- Duplicate read; ensure the correct width.
    state.run.seed = memory.read_u32_be(CONFIG.MEM.CURRENT_SEED)
    state.run.stars = memory.read_u16_be(CONFIG.MEM.HUD.STARS)

    -- Read Mario's 3D position from memory.
    local pos_data = read3float(CONFIG.MEM.MARIO.POS)
    state.mario.pos = {
        x = pos_data[1],
        y = pos_data[2],
        z = pos_data[3]
    }

    -- Calculate Mario's velocity based on change in position from the previous state.
    if last_state.mario.pos then
        state.mario.velocity = {
            x = state.mario.pos.x - last_state.mario.pos.x,
            y = state.mario.pos.y - last_state.mario.pos.y,
            z = state.mario.pos.z - last_state.mario.pos.z
        }
    else
        state.mario.velocity = {
            x = 0,
            y = 0,
            z = 0
        }
    end

    -- Determine Mario's status (e.g., in water, taking gas damage, intangible).
    state.mario.is_in_water = ((state.mario.action & 0xC0) == 0xC0)
    state.mario.is_in_gas = ((state.mario.input & 0x100) == 0x100)
    state.mario.is_intangible = ((state.mario.action & 0x1000) == 0x1000)
    state.mario.has_metal_cap = ((state.mario.flags & 0x4) == 0x4)
    state.mario.is_taking_gas_damage = (state.mario.is_in_gas and not state.mario.is_intangible and
                                           not state.mario.has_metal_cap)

    -- Read the hurt counter to detect if Mario has taken damage.
    state.mario.hurt_counter = memory.readbyte(CONFIG.MEM.MARIO.HURT_COUNTER)

    -- Retrieve abbreviated level names for current and intended levels.
    local level_abbr = get_level_abbr(state.game.level_id)
    local intended_level_abbr = get_level_abbr(state.game.intended_level_id)

    -- Update the warp map if not already set, provided that the intended level is valid
    -- and the current level is not one of the excluded ones (levels 6 and 16).
    if not state.run.warp_map[intended_level_abbr] and state.game.intended_level_id ~= 0 and state.game.level_id ~= 6 and
        state.game.level_id ~= 16 then
        state.run.warp_map[intended_level_abbr] = level_abbr
    end

    -- If stars have increased since the last state update, record the star collection per level.
    if state.run.stars > last_state.run.stars then
        if not state.run.star_map[level_abbr] then
            state.run.star_map[level_abbr] = 0
        end
        state.run.star_map[level_abbr] = state.run.star_map[level_abbr] + 1
    end

    -- If the level indicates a new run (level_id 16) and the run is not already active, initialize a new run.
    if state.game.level_id == 16 and state.run.status == run_state.INACTIVE then
        state.run.status = run_state.ACTIVE
        state.run.end_reason = nil
        state.run.pb = false
        state.run.warp_map = {} -- Clear previous warp data.
        state.run.star_map = {} -- Clear previous star data.
        CONFIG.USER.ATTEMPTS = CONFIG.USER.ATTEMPTS + 1 -- Increment the attempt count.
    end

    if state.game.level_id == 1 and state.run.status == run_state.COMPLETE then
        state.run.status = run_state.INACTIVE
    end
end

-- Check for run-ending conditions (e.g., Mario dying, falling, environmental hazards).
local function check_run_over_conditions()
    if state.mario.hp == 0 then
        if last_state.mario.velocity.y <= -55 then
            state.run.end_reason = 'Fall Damage'
        elseif state.mario.hurt_counter > 0 then
            state.run.end_reason = 'Enemy Damage'
        elseif state.mario.is_taking_gas_damage then
            state.run.end_reason = 'Suffocated by Hazy Gas'
        elseif state.mario.is_in_water then
            if state.game.level_id == 10 then
                state.run.end_reason = 'Frozen in Cold Water'
            elseif last_state.mario.hp == 1 then
                state.run.end_reason = 'Drowned'
            else
                state.run.end_reason = "HOW?" -- Fallback for an unhandled case.
            end
        else
            state.run.end_reason = 'Environment Hazard'
        end
    elseif state.game.delayed_warp_op == 18 or state.game.delayed_warp_op == 20 then
        state.run.end_reason = 'Fell Out of Level'
    end

    -- If an end reason is determined, mark the run as pending and record the end time.
    if state.run.end_reason then
        state.run.status = run_state.PENDING

        -- Check if the current star count is a new personal best.
        if CONFIG.USER.PB_STARS < state.run.stars then
            CONFIG.USER.PB_STARS = state.run.stars
            state.run.pb = true
        end
    end
end

-- Format a duration (in seconds) as a string in HH:MM:SS format.
local function format_time(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local seconds = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- Write detailed run data as a CSV line to the attempts data file.
local function write_run_data_csv()
    local seed_key = string.format("%s_%s", state.run.seed, os.date("%Y%m%d%H%M%S"))
    local attempt_number = CONFIG.USER.ATTEMPTS
    local stars = state.run.stars or 0
    local level_name = get_level_name(state.game.level_id)

    -- Create a summary string for stars collected per level.
    local stars_collected = ""
    for abbr, count in pairs(state.run.star_map) do
        stars_collected = stars_collected .. string.format("%s:%d ", abbr, count)
    end
    if stars_collected ~= "" then
        stars_collected = stars_collected:sub(1, -2) -- Remove trailing space.
    end

    -- Format the CSV line with all relevant run data.
    local csv_line = string.format("%d,%s,%s,%d,%s,%s,%s\n", attempt_number, seed_key, timestamp, stars,
        level_name, state.run.end_reason, stars_collected)

    -- Append the CSV line to the attempt data file.
    local file = io.open(CONFIG.FILES.ATTEMPT_DATA, "a")
    if file then
        file:write(csv_line)
        file:close()
    end
end

-- Write the warp map data as a JSON file.
local function write_warp_log()
    local file = io.open(CONFIG.FILES.WARP_LOG, "w")
    if file then
        file:write(json.encode(state.run.warp_map))
        file:close()
    end
end

-- Write all run-related data to files and mark the run as complete.
local function write_data()
    write_attempts_file() -- Write the attempt count.
    write_pb_stars_file() -- Write the PB star count.
    write_run_data_csv() -- Write detailed run data as CSV.
    write_warp_log() -- Write the warp map as JSON.
    state.run.status = run_state.COMPLETE
end

local function load_config()
    -- Load the configuration file if it exists.
    local file = io.open("config.json", "r")
    if file then
        local config_data = json.decode(file:read("*all"))
        if config_data then
            CONFIG.BACKGROUND_IMAGE = config_data.BACKGROUND_IMAGE
            CONFIG.SHOW_SONG_TITLE = config_data.SHOW_SONG_TITLE
            CONFIG.SHOW_CAP_TIMER = config_data.SHOW_CAP_TIMER
        end
        file:close()
    end
end

local function save_config()
    -- Save the configuration to a file.
    local file = io.open("config.json", "w+")
    if file then
        local config_data = {
            BACKGROUND_IMAGE = CONFIG.BACKGROUND_IMAGE,
            SHOW_SONG_TITLE = CONFIG.SHOW_SONG_TITLE,
            SHOW_CAP_TIMER = CONFIG.SHOW_CAP_TIMER
        }
        file:write(json.encode(config_data))
        file:close()
    end
end

-- Render the on-screen UI overlay with current run and game data.
local function render_ui()
    local game_width = client.bufferwidth() -- Get current game screen width.
    local game_height = client.bufferheight() -- Get current game screen height.

    -- Calculate extra UI width based on aspect ratio and game width.
    local ui_width = math.floor((game_height * (16 / 9)) - game_width) - 20

    -- Determine font size and character width based on game height.
    local font_size = math.max(math.floor(game_height / 50), 8)
    local char_width = math.floor(font_size / 1.6)

    local logo_size = math.floor(game_height / 12) -- Define icon size for logos, stars, etc.

    -- Set extra padding for the game screen to accommodate the UI.
    client.SetGameExtraPadding(0, 0, ui_width + 20, 0)

    -- Call a placeholder function if the left mouse button is pressed when the mouse is within the logo image.
    if input.getmouse().Left and input.getmouse().X >= game_width and input.getmouse().X <= (game_width + logo_size) and
        input.getmouse().Y >= (game_height - (logo_size + 20)) and input.getmouse().Y <= game_height and not config_form then
        config_form = forms.newform(210, 140, "Configuration", function()
            forms.destroy(config_form)
            config_form = nil
        end)

        local config_form_height = forms.getproperty(config_form, "Height")
        local config_form_width = forms.getproperty(config_form, "Width")

        -- Add a dropdown to select the background image.
        local background_image_dropdown_label = forms.label(config_form, "Background Image:", 10, 12, 100, 20)
        local background_image_dropdown = forms.dropdown(config_form, BACKGROUND_IMAGES, 110, 10, 90, 20)
        forms.setproperty(background_image_dropdown, "SelectedItem", CONFIG.BACKGROUND_IMAGE)

        -- Add a checkbox to toggle the song title display.
        local show_song_title_checkbox_label = forms.label(config_form, "Show Song Title", 30, 45, 100, 20)
        local show_song_title_checkbox = forms.checkbox(config_form, nil, 13, 40)
        forms.setproperty(show_song_title_checkbox, "Checked", CONFIG.SHOW_SONG_TITLE)

        -- Add a checkbox to toggle the song title display.
        local show_cap_timer_checkbox_label = forms.label(config_form, "Show Cap Timer", 30, 72, 100, 20)
        local show_cap_timer_checkbox = forms.checkbox(config_form, nil, 13, 67)
        forms.setproperty(show_cap_timer_checkbox, "Checked", CONFIG.SHOW_CAP_TIMER)

        -- Add a button to save the configuration.
        forms.button(config_form, "OK", function()
            CONFIG.BACKGROUND_IMAGE = forms.getproperty(background_image_dropdown, "SelectedItem")
            CONFIG.SHOW_SONG_TITLE = forms.ischecked(show_song_title_checkbox)
            CONFIG.SHOW_CAP_TIMER = forms.ischecked(show_cap_timer_checkbox)
            save_config()
            forms.destroy(config_form)
            config_form = nil
        end, 10, 100, 90, 30)

        -- Add a button to close the configuration form.
        forms.button(config_form, "Cancel", function()
            forms.destroy(config_form)
            config_form = nil
        end, 110, 100, 90, 30)
    end

    -- Skip rendering if no changes in state (to save processing).
    if tablex.deepcompare(state, last_state) then
        return
    end

    -- Draw the background image if one is selected.
    if CONFIG.BACKGROUND_IMAGE ~= "(None)" then
        gui.drawImage("img/bg/" .. CONFIG.BACKGROUND_IMAGE .. ".jpg", game_width, 0, ui_width, game_height)
    end

    -- Draw the tracker logo in the bottom right of the game screen.
    gui.drawImage("img/logo.png", game_width, game_height - (logo_size + 20), logo_size, logo_size)

    -- Draw the tracker title centered in the UI panel.
    gui.drawString(game_width + math.floor(ui_width / 2), font_size, "IronMario Tracker", "lightblue", nil, font_size,
        CONFIG.FONT_FACE, nil, "center")

    -- If the running ROM version does not match the compatible version, show an error message.
    if not VALID_ROM_VERSION then
        gui.drawString(game_width + math.floor(ui_width / 2), font_size * 10, "Incompatible\nROM version!", "red", nil,
            font_size * 2, CONFIG.FONT_FACE, nil, "center")
        gui.drawString(game_width + math.floor(ui_width / 2), font_size * 15,
            "Expected: " .. CONFIG.COMPATIBLE_ROM_VERSION, "red", nil, font_size, CONFIG.FONT_FACE, nil, "center")
        gui.drawString(game_width + math.floor(ui_width / 2), font_size * 16, "Running: " .. CONFIG.RUNNING_ROM_VERSION,
            "red", nil, font_size, CONFIG.FONT_FACE, nil, "center")
        return -- Stop further UI rendering if ROM version is incompatible.
    end

    -- Render attempt number.
    gui.drawString(game_width, font_size * 3, "Attempt #" .. CONFIG.USER.ATTEMPTS, nil, nil, font_size, CONFIG.FONT_FACE)

    -- Render current star count and personal best (PB) stars.
    gui.drawString(game_width, font_size * 4, "Stars: " .. state.run.stars, nil, nil, font_size, CONFIG.FONT_FACE)
    gui.drawString(game_width + math.floor(ui_width / 3), font_size * 4, "PB: " .. CONFIG.USER.PB_STARS, "yellow", nil,
        font_size, CONFIG.FONT_FACE)

    -- Render current level name and run seed.
    gui.drawString(game_width, font_size * 6, "Level: " .. get_level_name(state.game.level_id), nil, nil, font_size,
        CONFIG.FONT_FACE)
    gui.drawString(game_width, font_size * 7, "Seed: " .. state.run.seed, nil, nil, font_size, CONFIG.FONT_FACE)

    -- Render cap timer.
    if state.mario.cap_timer > 0 and CONFIG.SHOW_CAP_TIMER then
        gui.drawString(game_width / 2 - 120, game_height - (font_size * 2 + 20 * 4), "Cap Timer: " .. math.floor(state.mario.cap_timer / 30), nil, nil, font_size * 2, CONFIG.FONT_FACE)
    end

    -- If the run is over (pending or complete), display "RUN OVER!" and "NEW PB!" if applicable.
    if state.run.status == run_state.PENDING or state.run.status == run_state.COMPLETE then
        gui.drawString(game_width + math.floor((ui_width / 3) * 2), font_size * 3, "RUN OVER!", "red", nil, font_size,
            CONFIG.FONT_FACE)
        if state.run.pb then
            gui.drawString(game_width + math.floor((ui_width / 3) * 2), font_size * 4, "NEW PB!", "lightgreen", nil,
                font_size, CONFIG.FONT_FACE)
        end
    end

    -- Define an ordered list of level abbreviations for displaying the warp map and star counts.
    local ordered_keys = {"BoB", "WF", "JRB", "CCM", "BBH", "HMC", "LLL", "SSL", "DDD", "SL", "WDW", "TTM", "THI",
                          "TTC", "RR", "PSS", "SA", "WMotR", "Wing", "Metal", "Vanish", "BitDW", "BitFS", "BitS"}

    -- Calculate positions for left and right columns.
    local left_col_x = game_width
    local right_col_x = game_width + math.floor(ui_width / 2)

    -- Render the warp map header.
    local warp_header_y = font_size * 9
    gui.drawString(game_width + math.floor(ui_width / 2), warp_header_y, "== Warp Map ==", "orange", nil, font_size,
        CONFIG.FONT_FACE, nil, "center")
    local warp_table_start_y = warp_header_y + (font_size * 2)

    -- Build a table of warp entries from the state's warp map using the ordered keys.
    local warp_entries = {}
    for _, key in ipairs(ordered_keys) do
        if state.run.warp_map[key] then
            table.insert(warp_entries, {
                key = key,
                value = state.run.warp_map[key]
            })
        end
    end

    -- Render warp entries in two columns.
    for i, entry in ipairs(warp_entries) do
        local col, row
        if i <= 12 then
            col = 1
            row = i
        else
            col = 2
            row = i - 12
        end
        local x = (col == 1) and left_col_x or right_col_x
        local y = warp_table_start_y + (row - 1) * font_size
        gui.drawString(x + (ui_width / 4), y, string.format("%s → %s", entry.key, entry.value), nil, nil, font_size,
            CONFIG.FONT_FACE, nil, "center")
    end

    -- Calculate vertical spacing based on the number of warp entries rendered.
    local warp_rows_used = (#warp_entries > 0) and math.min(12, #warp_entries) or 1

    -- Render the "Stars Collected" header.
    local star_header_y = warp_table_start_y + ((warp_rows_used + 1) * (font_size))
    gui.drawString(game_width + math.floor(ui_width / 2), star_header_y, "== Stars Collected ==", "yellow", nil,
        font_size, CONFIG.FONT_FACE, nil, "center")
    local star_table_start_y = star_header_y + (font_size * 2)

    -- Build a table of star entries from the state's star map using the ordered keys.
    local star_entries = {}
    for _, key in ipairs(ordered_keys) do
        if state.run.star_map[key] then
            table.insert(star_entries, {
                key = key,
                count = state.run.star_map[key]
            })
        end
    end

    -- Determine maximum label widths for left and right columns to align star icons.
    local left_max_width = 0
    local right_max_width = 0
    for i, entry in ipairs(star_entries) do
        local label_width = string.len(entry.key) * char_width
        if i <= 12 then
            if label_width > left_max_width then
                left_max_width = label_width
            end
        else
            if label_width > right_max_width then
                right_max_width = label_width
            end
        end
    end

    -- Render star entries along with star icons for each collected star.
    for i, entry in ipairs(star_entries) do
        local col, row
        if i <= 12 then
            col = 1
            row = i
        else
            col = 2
            row = i - 12
        end
        local x = (col == 1) and left_col_x or right_col_x
        local y = star_table_start_y + (row - 1) * (font_size + 3)
        gui.drawString(x, y, entry.key, nil, nil, font_size, CONFIG.FONT_FACE)

        local spacing = font_size
        local max_label_width = (col == 1) and left_max_width or right_max_width
        local icons_start_x = x + max_label_width + spacing

        for j = 1, entry.count do
            gui.drawImage("img/star.png", icons_start_x + (j - 1) * font_size, y + (font_size * 0.1), font_size * 0.8,
                font_size * 0.8)
        end
    end

    -- Optionally display the current song title if the toggle is enabled.
    if CONFIG.SHOW_SONG_TITLE and CONFIG.MUSIC_DATA.SONG_MAP[state.game.song] then
        gui.drawString(20 + math.floor(char_width / 2), game_height - (20 + math.floor(font_size * 1.25)),
            get_song_name(state.game.song), nil, nil, font_size, CONFIG.FONT_FACE)
    end

    -- Display version information and credits at the bottom right of the UI.
    gui.drawString(game_width + ui_width, game_height - font_size,
        "v" .. CONFIG.TRACKER_VERSION .. ' by WaffleSmacker and KaaniDog', "gray", nil,
        math.max(math.floor(font_size / 2), 8), CONFIG.FONT_FACE, nil, "right")
end

load_config()

-- Read stored attempt count and personal best star count from files.
read_attempts_file()
read_pb_stars_file()

console.clear() -- Clear the console for a clean output.

-- Main loop: executes every frame.
while true do
    -- Process on every other frame to reduce CPU load.
    if emu.framecount() % 2 == 0 then
        -- Update game state if the run isn't already pending (i.e., if it's still in progress).
        if state.run.status ~= run_state.PENDING then
            update_game_state()
        end

        -- If the run is active, check for any conditions that signal the run is over.
        if state.run.status == run_state.ACTIVE then
            check_run_over_conditions()
        end

        -- If a run has ended (pending state), write the run data to files.
        if state.run.status == run_state.PENDING then
            write_data()
        end

        -- Handle input: toggle the song title display if specific buttons are pressed.
        local current_inputs = joypad.get()
        if current_inputs["P1 L"] and current_inputs["P1 R"] and current_inputs["P1 A"] and current_inputs["P1 B"] and
            not state.input.music_toggle_pressed then
            state.input.music_toggle_pressed = true
            CONFIG.SHOW_SONG_TITLE = not CONFIG.SHOW_SONG_TITLE
        elseif (not current_inputs["P1 L"] or not current_inputs["P1 R"] or not current_inputs["P1 A"] or
            not current_inputs["P1 B"]) and state.input.music_toggle_pressed then
            state.input.music_toggle_pressed = false
        end

        render_ui() -- Render the UI overlay with the current state.
    end

    emu.frameadvance() -- Advance to the next frame.
end
