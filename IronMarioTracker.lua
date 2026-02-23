-- IronMario Tracker Script
-- This script tracks various aspects of a run (attempt count, stars, warp mapping, etc.) by reading emulator memory,
-- logging data to files, and rendering an on-screen overlay.
-- It uses lunajson for JSON encoding and pl.tablex for deep table functions.
local json = require("lib.lunajson") -- JSON encoding/decoding library
local tablex = require("lib.pl.tablex") -- Extended table functions (e.g., deepcopy, deepcompare)

-- gSaveBuffer is at 0x8004cda0
local SAVE_FILE_BASE = 0x8004CDA0
local SAVE_SLOT_ADDR = 0x801D050A
local SAVE_FILE_SIZE = 0x48  -- Proper struct size (56 bytes)

local SAVE_FLAGS_OFFSET = 0x38
local COURSE_STARS_OFFSET = 0x40
local COURSE_COINS_OFFSET = 0x59
local NUM_STAR_COURSES = 25
local NUM_COIN_COURSES = 15

-- Save flags (optional, not used here but retained)
local SAVE_FLAGS = {
    {0x00000001, "FILE_EXISTS"},
    {0x00000002, "HAVE_WING_CAP"},
    {0x00000004, "HAVE_METAL_CAP"},
    {0x00000008, "HAVE_VANISH_CAP"},
    {0x00000010, "HAVE_KEY_1"},
    {0x00000020, "HAVE_KEY_2"},
    {0x00000040, "UNLOCKED_BASEMENT_DOOR"},
    {0x00000080, "UNLOCKED_UPSTAIRS_DOOR"},
    {0x00000100, "DDD_MOVED_BACK"},
    {0x00000200, "MOAT_DRAINED"},
    {0x00000400, "UNLOCKED_PSS_DOOR"},
    {0x00000800, "UNLOCKED_WF_DOOR"},
    {0x00001000, "UNLOCKED_CCM_DOOR"},
    {0x00002000, "UNLOCKED_JRB_DOOR"},
    {0x00004000, "UNLOCKED_BITDW_DOOR"},
    {0x00008000, "UNLOCKED_BITFS_DOOR"},
    {0x00010000, "CAP_ON_GROUND"},
    {0x00020000, "CAP_ON_KLEPTO"},
    {0x00040000, "CAP_ON_UKIKI"},
    {0x00080000, "CAP_ON_MR_BLIZZARD"},
    {0x00100000, "UNLOCKED_50_STAR_DOOR"},
    {0x00200000, "IS_SET_SEED"},
    {0x01000000, "COLLECTED_TOAD_STAR_1"},
    {0x02000000, "COLLECTED_TOAD_STAR_2"},
    {0x04000000, "COLLECTED_TOAD_STAR_3"},
    {0x08000000, "COLLECTED_MIPS_STAR_1"},
    {0x10000000, "COLLECTED_MIPS_STAR_2"},
}

function get_current_file_index()
    local val = memory.read_u16_be(SAVE_SLOT_ADDR)
    if val < 1 or val > 4 then
        return 0 -- fallback to File A
    end
    return val - 1
end

function decode_star_flags(flags)
    local stars = {}
    for i = 0, 6 do
        if (flags & (1 << i)) ~= 0 then
            table.insert(stars, i + 1)
        end
    end
    return stars
end

function get_star_flags_for_course(fileIndex, courseIndex)
    local addr = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + COURSE_STARS_OFFSET + courseIndex
    return memory.read_u8(addr) & 0x7F
end

function get_all_star_flags()
    local fileIndex = get_current_file_index()
    local flags = {}
    for i = 0, NUM_STAR_COURSES - 1 do
        flags[i + 1] = get_star_flags_for_course(fileIndex, i)
    end
    return flags
end

function get_coins_flags_for_course(fileIndex, courseIndex)
    local addr = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + COURSE_COINS_OFFSET + courseIndex
    return memory.read_u8(addr) & 0x7F
end

function get_all_coins_flags()
    local fileIndex = get_current_file_index()
    local flags = {}
    for i = 0, NUM_COIN_COURSES - 1 do
        flags[i + 1] = get_coins_flags_for_course(fileIndex, i)
    end
    return flags
end

local COURSE_NAMES = {
    "Bob-omb Battlefield", "Whomp's Fortress", "Jolly Roger Bay", "Cool, Cool Mountain", "Big Boo's Haunt",
    "Hazy Maze Cave", "Lethal Lava Land", "Shifting Sand Land", "Dire, Dire Docks", "Snowman's Land",
    "Wet-Dry World", "Tall, Tall Mountain", "Tiny-Huge Island", "Tick Tock Clock", "Rainbow Ride",
    "Bowser in the Dark World", "Bowser in the Fire Sea", "Bowser in the Sky",
    "Princess's Secret Slide", "Wing Mario Over the Rainbow", "Vanish Cap Under the Moat", "Metal Cap Cavern",
    "Tower of the Wing Cap", "Secret Aquarium", "Toad + MIPS Stars / Secrets"
}

function print_star_collection_with_addresses()
    -- Debug function removed
end


-- Door star requirement system
local DOOR_STAR_REQUIREMENTS = {
    -- Table of door names in StarDoorReqIDs enum order
    door_names = {
        "WF", "PSS", "JRB", "CCM", "BitDW", "Basement", "BBH", "Wing", 
        "HMC", "DDD", "SL", "THI", "TTM", "Upstairs", "BitS", "[Sentinel Value - No Level]"
    },
    -- Memory address for the LUT-array start
    lut_base_address = 0x8020F0E4
}

-- Function to get star requirement for a door
local function get_door_star_requirement(door_index)
    if not DOOR_STAR_REQUIREMENTS or not DOOR_STAR_REQUIREMENTS.lut_base_address then
        return 0 -- Default to 0 if memory address is not available
    end
    
    local success, result = pcall(function()
        return memory.read_u8(DOOR_STAR_REQUIREMENTS.lut_base_address + (door_index - 1))
    end)
    
    if success then
        return result
    else
        return 0 -- Default to 0 if memory read fails
    end
end





-- Save flag definitions
local SAVE_FLAGS = {
    {0x00000001, "FILE_EXISTS"},
    {0x00000002, "HAVE_WING_CAP"},
    {0x00000004, "HAVE_METAL_CAP"},
    {0x00000008, "HAVE_VANISH_CAP"},
    {0x00000010, "HAVE_KEY_1"},
    {0x00000020, "HAVE_KEY_2"},
    {0x00000040, "UNLOCKED_BASEMENT_DOOR"},
    {0x00000080, "UNLOCKED_UPSTAIRS_DOOR"},
    {0x00000100, "DDD_MOVED_BACK"},
    {0x00000200, "MOAT_DRAINED"},
    {0x00000400, "UNLOCKED_PSS_DOOR"},
    {0x00000800, "UNLOCKED_WF_DOOR"},
    {0x00001000, "UNLOCKED_CCM_DOOR"},
    {0x00002000, "UNLOCKED_JRB_DOOR"},
    {0x00004000, "UNLOCKED_BITDW_DOOR"},
    {0x00008000, "UNLOCKED_BITFS_DOOR"},
    {0x00010000, "CAP_ON_GROUND"},
    {0x00020000, "CAP_ON_KLEPTO"},
    {0x00040000, "CAP_ON_UKIKI"},
    {0x00080000, "CAP_ON_MR_BLIZZARD"},
    {0x00100000, "UNLOCKED_50_STAR_DOOR"},
    {0x00200000, "IS_SET_SEED"},
    {0x01000000, "COLLECTED_TOAD_STAR_1"},
    {0x02000000, "COLLECTED_TOAD_STAR_2"},
    {0x04000000, "COLLECTED_TOAD_STAR_3"},
    {0x08000000, "COLLECTED_MIPS_STAR_1"},
    {0x10000000, "COLLECTED_MIPS_STAR_2"},
}

-- Decode and list all active flags
local function decode_flags(value, flagDefs)
    local setFlags = {}
    for _, flag in ipairs(flagDefs) do
        if (value & flag[1]) ~= 0 then
            table.insert(setFlags, flag[2])
        end
    end
    return setFlags
end

-- Unified flag reader for the current save file
function print_save_file_flags()
    local fileIndex = get_current_file_index()

    -- Calculate base address for this save file's flags
    local flagsAddrLow  = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + SAVE_FLAGS_OFFSET
    local flagsAddrHigh = flagsAddrLow + 4

    -- Read flags
    local flagsLow  = memory.read_u32_be(flagsAddrLow)
    local flagsHigh = memory.read_u32_be(flagsAddrHigh)

    -- Debug output removed
end

local ROM_HASH = "7EE741D097C660E74330FAB27FC83727592A57EA"

-- Main configuration table that holds version info, file paths, memory addresses, and user data.
local CONFIG = {
    TRACKER_VERSION = '1.2',
    FONT_FACE = 'Lucida Console',
    SHOW_SONG_TITLE = false, -- Flag to toggle song title display on the UI.
    SHOW_CAP_TIMER = false, -- Flag to toggle cap timer display on the UI.
    SHOW_ONLY_SEEN_LEVELS = false, -- Flag to toggle showing only levels with warp or star data.
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

-- Add new streamer data config options to CONFIG
CONFIG.STREAMER_STAR_DATA = false
CONFIG.STREAMER_SEED = false
CONFIG.STREAMER_LEVEL = false
CONFIG.STREAMER_SONG = false
CONFIG.REVERSE_STAR_COLORS = false -- Flag to reverse star colors (collected=white, uncollected=gray)

-- Color mapping for cross-environment compatibility
local COLOR_MAP = {
    -- Standard colors that should work in most environments
    white = "white",
    gray = "gray", 
    red = "red",
    green = "green",
    blue = "blue",
    yellow = "yellow",
    black = "black",
    -- Fallback colors for potentially problematic names
    lightblue = "blue", -- Fallback to blue if lightblue not supported
    lightgray = "gray", -- Fallback to gray if lightgray not supported
    lightgreen = "green", -- Fallback to green if lightgreen not supported
    teal = "blue", -- Fallback to blue if teal not supported
    lime = "green", -- Fallback to green if lime not supported
    magenta = "red", -- Fallback to red if magenta not supported
    orange = "yellow", -- Fallback to yellow if orange not supported
    purple = "blue", -- Fallback to blue if purple not supported
    cyan = "blue", -- Fallback to blue if cyan not supported
    pink = "red", -- Fallback to red if pink not supported
    brown = "yellow", -- Fallback to yellow if brown not supported
    navy = "blue", -- Fallback to blue if navy not supported
    maroon = "red", -- Fallback to red if maroon not supported
    olive = "green", -- Fallback to green if olive not supported
    gold = "yellow", -- Fallback to yellow if gold not supported
    silver = "gray" -- Fallback to gray if silver not supported
}

-- Function to get a safe color that works across environments
local function get_safe_color(color_name)
    return COLOR_MAP[color_name] or "white" -- Default to white if color not found
end

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
    LIVES = CONFIG.MEM.HUD_BASE + 0x0, -- Address for the number of lives displayed.
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
        [28] = "Race Fanfare",
        [29] = "Super Mario 64 - Stage Boss",
        [30] = "Super Mario 64 - Ultimate Koopa",
        [31] = "Super Mario 64 - File Select",
        [32] = "Super Mario 64 - Powerful Mario",
        [33] = "Super Mario 64 - Title Theme",
        [34] = "Bomberman 64 - Green Garden",
        [35] = "Dumb Ways to Die - TanukiDan",
        [36] = "Bomberman Hero - Redial",
        [37] = "Wii Shop Channel",
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
        [58] = "Mario & Luigi: Partners in Time - Thwomp Caverns",
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
        [71] = "Pokemon Diamond and Pearl - Eterna Forest",
        [72] = "Pokemon HeartGold and SoulSilver - Lavender Town",
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
        [105] = "Mario and Luigi: Bowser's Inside Story - Bumpsy Plains",
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
        [120] = "Mario and Luigi: Partners in Time - Yoshi's Village",
        [121] = "Touhou 10: Mountain of Faith - Youkai Mountain",
        [122] = "Mario and Luigi: Bowser's Inside Story - Deep Castle",
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
        [138] = "Paper Mario: The Thousand-Year Door - Eight Key Domain",
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
        [154] = "Banjo-Kazooie - Mumbo's Mountain",
        [155] = "Donkey Kong Country 2 - Jib Jig",
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
        [167] = "Bomberman 64 - Green Garden New",
        [168] = "Animal Crossing - KK Rider",
        [169] = "Banjo-Kazooie - Click Clock Woods",
        [170] = "Killer Instinct - Title Theme",
        [171] = "TLoZ: Majora's Mask - Astral Observatory",
        [172] = "TLoZ: The Wind Waker - Pirate's Fortress",
        [173] = "Mega Man - Cold Man",
        [174] = "Metroid Prime - Magmoor Caverns",
        [175] = "Metroid Prime - Phendrana Drifts",
        [176] = "Mario and Luigi: Superstar Saga - Hoohoo Village",
        [177] = "Mega Man 2 - Flash Man",
        [178] = "Mega Man 2 - Wily Stage 1",
        [179] = "Mega Man 3 - Needle Man",
        [180] = "Mega Man 3 - Shadow Man",
        [181] = "Mega Man 3 - Title Theme",
        [182] = "Mega Man X - Chill Penguin",
        [183] = "Mega Man X - Flame Mammoth",
        [184] = "Mega Man X - Opening Stage",
        [185] = "Mega Man X - Spark Mandrill",
        [186] = "Mega Man X - Storm Eagle",
        [187] = "Mega Man X2 - Bubble Crab",
        [188] = "Mother 3 - Going Alone",
        [189] = "Paper Mario - Fight Theme",
        [190] = "Pictionary - Title Screen",
        [191] = "Pilotwings 64 - Birdman",
        [192] = "Pizza Tower - Tropical Crust",
        [193] = "Pizza Tower - ET Wahwahs",
        [194] = "Pokemon Diamond and Pearl - Route 216",
        [195] = "Pokemon FireRed and LeafGreen - Gym Battle",
        [196] = "Pokemon FireRed and LeafGreen - Trainer Battle",
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
        [207] = "Sonic Adventure 2 - City Escape",
        [208] = "Silver Surfer - Stage 1",
        [209] = "Super Mario 3D World - Sunshine Seaside",
        [210] = "Sonic the Hedgehog - Star Light Zone",
        [211] = "Sonic 3 - Final Boss",
        [212] = "Sonic Mania - Tabloid Jargon",
        [213] = "Star Fox - Fortuna",
        [214] = "Star Fox 64 - Corneria",
        [215] = "Sonic the Hedgehog 3 - Desert Palace Zone",
        [216] = "Street Fighter 2 - Guile's Theme",
        [217] = "Tetris Attack - Forest Stage",
        [218] = "TLoZ: Majora's Mask - Deku Palace",
        [219] = "TLoZ: Majora's Mask - Milk Bar",
        [220] = "TLoZ: Skyward Sword - Knight's Academy",
        [221] = "Wario Land - Stonecarving City",
        [222] = "Wii - Mii Channel",
        [223] = "Wii Party - Roll to the Goal",
        [224] = "Yoshi's Island - Big Boss",
        [225] = "Yoshi's Island - Athletic Theme",
        [226] = "Yooka-Laylee - Tropic Trials",
        [227] = "DuckTales - The Moon",
        [228] = "F-Zero - Big Blue",
        [229] = "F-Zero - Mute City",
        [230] = "Katamari Damacy - Katamari on the Rocks",
        [231] = "Kirby and the Forgotten Land - Fast Flowing Waterworks",
        [232] = "Knuckles' Chaotix - Door Into Summer",
        [233] = "Mario and Luigi: Dream Team - Try, Try Again",
        [234] = "Mario and Luigi: Superstar Saga - Oho Ocean",
        [235] = "Mario Kart 7 - Piranha Plant Slide",
        [236] = "Mario Kart 8 - Sunshine Airport",
        [237] = "Mario Kart 8 - Sweet Sweet Canyon",
        [238] = "Mario Kart Wii - Coconut Mall",
        [239] = "Mega Man X - Boomer Kuwanger",
        [240] = "Metroid Fusion - Main Deck",
        [241] = "Paper Mario: Color Splash - Cherry Lake",
        [242] = "Pizza Tower - Good Eatin'",
        [243] = "Super Mario Bros. Wonder - Wonder Overworld",
        [244] = "Sonic 3 - Ice Cap Zone",
        [245] = "Star Fox 64 - Area 6",
        [246] = "Star Fox 64 - Sector Y"
    }
}

local VALID_ROM_VERSION = nil
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
        music_toggle_pressed = false, -- Flag to track toggling of song title display.
        show_all_levels_toggle_pressed = false, -- Flag to toggle showing all levels or only those with data.
        show_all_levels = true -- Default to showing all levels.
    },
    mario = {}, -- Will hold Mario's position, velocity, health, etc.
    run = {
        status = run_state.INACTIVE, -- Current run state.
        stars = 0, -- Total stars collected during the run.
        warp_map = {}, -- Map of intended warp destinations to actual warp outcomes.
        star_map = {}, -- Mapping of levels to star counts collected.
        star_bits = {}, -- Per-course star bitfields for the current save file.
        last_star_level = nil -- Most recently entered level with stars (excluding castle)
    },
    game = {
        level_id = 1 -- Current level ID; default value.
    }
}

local BACKGROUND_IMAGES = {"(None)", "Cave", "City", "Desert", "Dgr", "Fire", "Forest", "Fuji", "Mountains", "Ocean", "Pattern", "Sky",
                           "Storm", "Steel", "CaptWaffle", "Custom"}

-- Table to store the previous state (for change detection in UI rendering).
local last_state = {}

local config_form = nil -- Placeholder for the configuration form.
-- Add a global force_redraw flag
force_redraw = force_redraw or false

-- Global variable to track if the star info page is being shown
show_star_info_page = show_star_info_page or nil

-- Global variable to track if warp data has been loaded
warp_data_loaded = false

-- Function to check if a level is unlocked based on total stars and special conditions
local function is_level_unlocked(level_abbr)
    -- Special cases based on flags and conditions
    if level_abbr == "LLL" or level_abbr == "SSL" or level_abbr == "Vanish" then
        -- Locked until basement door flag is set in save file
        if not state or not state.run then
            return false -- Default to locked if state is not available
        end
        local fileIndex = get_current_file_index()
        local flagsAddrLow = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + SAVE_FLAGS_OFFSET
        local flagsLow = memory.read_u32_be(flagsAddrLow)
        return (flagsLow & 0x00000040) ~= 0 -- UNLOCKED_BASEMENT_DOOR flag
    end
    
    if level_abbr == "TTM" or level_abbr == "WDW" then
        -- Locked until upstairs door flag is set in save file
        if not state or not state.run then
            return false -- Default to locked if state is not available
        end
        local fileIndex = get_current_file_index()
        local flagsAddrLow = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + SAVE_FLAGS_OFFSET
        local flagsLow = memory.read_u32_be(flagsAddrLow)
        return (flagsLow & 0x00000080) ~= 0 -- UNLOCKED_UPSTAIRS_DOOR flag
    end
    
    if level_abbr == "RR" or level_abbr == "WMotR" then
        -- Locked until TTC is unlocked (check TTC's door requirement)
        if not state or not state.run or not state.run.stars then
            return false -- Default to locked if state is not available
        end
        local ttc_required_stars = get_door_star_requirement(13) -- TTC is door index 13
        return state.run.stars >= ttc_required_stars
    end
    
    if level_abbr == "SA" then
        -- Unlocked once JRB star requirements are met
        local jrb_required_stars = get_door_star_requirement(3) -- JRB is door index 3
        if not state or not state.run or not state.run.stars then
            return false -- Default to locked if state is not available
        end
        return state.run.stars >= jrb_required_stars
    end
    
    if level_abbr == "Metal" then
        -- Unlocked once player successfully enters HMC
        -- Check if HMC has been visited (has stars)
        if not state or not state.run or not state.run.star_map then
            return false -- Default to locked if state is not available
        end
        return (state.run.star_map["HMC"] and state.run.star_map["HMC"] > 0)
    end
    
    if level_abbr == "BitFS" then
        -- Unlocked after DDD star requirement is complete AND user has successfully gotten one star in DDD
        local ddd_required_stars = get_door_star_requirement(10) -- DDD is door index 10
        if not state or not state.run or not state.run.stars or not state.run.star_map then
            return false -- Default to locked if state is not available
        end
        -- Check both conditions: enough total stars AND at least 1 star in DDD
        return (state.run.stars >= ddd_required_stars and state.run.star_map["DDD"] and state.run.star_map["DDD"] > 0)
    end
    
    if level_abbr == "DDD" then
        -- Unlocked after star requirement is complete AND basement door is unlocked
        local ddd_required_stars = get_door_star_requirement(10) -- DDD is door index 10
        if not state or not state.run or not state.run.stars then
            return false -- Default to locked if state is not available
        end
        
        -- Check basement door flag
        local fileIndex = get_current_file_index()
        local flagsAddrLow = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + SAVE_FLAGS_OFFSET
        local flagsLow = memory.read_u32_be(flagsAddrLow)
        local basement_unlocked = (flagsLow & 0x00000040) ~= 0 -- UNLOCKED_BASEMENT_DOOR flag
        
        -- Check both conditions: enough total stars AND basement is unlocked
        return (state.run.stars >= ddd_required_stars and basement_unlocked)
    end
    
    -- Standard door-based levels
    local level_to_door = {
        WF = 1, PSS = 2, JRB = 3, CCM = 4, BitDW = 5, BBH = 7, Wing = 8,
        HMC = 9, DDD = 10, SL = 11, THI = 12, TTC = 13, BitS = 15
    }
    
    local door_index = level_to_door[level_abbr]
    if not door_index then
        return true -- Levels not in the door system are always unlocked
    end
    
    local required_stars = get_door_star_requirement(door_index)
    if not state or not state.run or not state.run.stars then
        return true -- Default to unlocked if state is not available
    end
    
    return state.run.stars >= required_stars
end

-- Function to determine warp color based on level status
local function get_warp_color(level_abbr)
    -- If in menu (level_id 0), show normal colors
    if state.game.level_id == 0 then
        return get_safe_color("white")
    end
    
    -- Check if this is the most recently entered level with stars (excluding castle)
    local is_most_recent = (level_abbr == state.run.last_star_level)
    
    if is_most_recent then
        return get_safe_color("green") -- Most recently entered level with stars
    elseif not is_level_unlocked(level_abbr) then
        return get_safe_color("red") -- Locked level (back to simple red)
    elseif state.run.star_map[level_abbr] and state.run.star_map[level_abbr] > 0 then
        return get_safe_color("gray") -- Visited level with stars
    else
        return get_safe_color("lightblue") -- Unlocked but not visited
    end
end

-- Function to determine warp color based on source and destination
local function get_warp_pair_color(source_abbr, dest_abbr)
    -- If in menu (level_id 0 or 1), show normal colors
    if state.game.level_id == 0 or state.game.level_id == 1 then
        return get_safe_color("white")
    end
    
    -- For locked levels, check the source (left side)
    if not is_level_unlocked(source_abbr) then
        return get_safe_color("red") -- Locked level
    end
    
    -- For visited/most recent levels, check the destination (right side)
    if dest_abbr ~= "?" then
        local is_most_recent = (dest_abbr == state.run.last_star_level)
        if is_most_recent then
            return get_safe_color("green") -- Most recently entered level with stars
        elseif state.run.star_map[dest_abbr] and state.run.star_map[dest_abbr] > 0 then
            return get_safe_color("gray") -- Visited level with stars
        end
    end
    
    -- Default: unlocked but not visited
    return get_safe_color("lightblue")
end

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
    -- Re-read the file to get the latest value
    local file = io.open(CONFIG.FILES.ATTEMPT_COUNT, "r")
    local file_attempts = 0
    if file then
        file_attempts = tonumber(file:read("*all")) or 0
        file:close()
    end
    -- Use the higher of the two (in case of manual edit)
    local to_write = math.max(CONFIG.USER.ATTEMPTS, file_attempts)
    file = io.open(CONFIG.FILES.ATTEMPT_COUNT, "w")
    if file then
        file:write(to_write)
        file:close()
    end
end

-- Write the personal best stars count to file.
local function write_pb_stars_file()
    -- Re-read the file to get the latest value
    local file = io.open(CONFIG.FILES.PB_COUNT, "r")
    local file_pb = 0
    if file then
        file_pb = tonumber(file:read("*all")) or 0
        file:close()
    end
    -- Use the higher of the two (PB should never decrease)
    local to_write = math.max(CONFIG.USER.PB_STARS, file_pb)
    file = io.open(CONFIG.FILES.PB_COUNT, "w")
    if file then
        file:write(to_write)
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

-- Unified course index mapping system
local COURSE_INDEX_MAPPING = {
    -- Index to abbreviation mapping
    INDEX_TO_ABBR = {
        [0] = "BoB", [1] = "WF", [2] = "JRB", [3] = "CCM", [4] = "BBH", [5] = "HMC", [6] = "LLL", [7] = "SSL",
        [8] = "DDD", [9] = "SL", [10] = "WDW", [11] = "TTM", [12] = "THI", [13] = "TTC", [14] = "RR",
        [15] = "BitDW", [16] = "BitFS", [17] = "BitS", [18] = "PSS", [19] = "Metal", [20] = "Wing", 
        [21] = "Vanish", [22] = "WMotR", [23] = "SA"
    },
    -- Abbreviation to index mapping
    ABBR_TO_INDEX = {
        BoB = 0, WF = 1, JRB = 2, CCM = 3, BBH = 4, HMC = 5, LLL = 6, SSL = 7, DDD = 8, SL = 9,
        WDW = 10, TTM = 11, THI = 12, TTC = 13, RR = 14, BitDW = 15, BitFS = 16, BitS = 17, PSS = 18, 
        Metal = 19, Wing = 20, Vanish = 21, WMotR = 22, SA = 23
    }
}

-- Returns the level abbreviation for a given course index (0-based)
local function get_level_abbr_from_index(course_index)
    return COURSE_INDEX_MAPPING.INDEX_TO_ABBR[course_index]
end

-- Returns the course index for a given level abbreviation
local function get_index_from_level_abbr(level_abbr)
    return COURSE_INDEX_MAPPING.ABBR_TO_INDEX[level_abbr]
end

-- Add this near the top with other state variables:
local last_level_for_auto_display = nil

-- Helper function to count bits in a number (used for star counting)
local function countbits(n)
    local c = 0
    for i = 0, 6 do if (n & (1 << i)) ~= 0 then c = c + 1 end end
    return c
end

-- Helper function to check save flags
local function check_save_flag(flag_mask)
    local fileIndex = get_current_file_index()
    local flagsAddrLow = SAVE_FILE_BASE + (fileIndex * SAVE_FILE_SIZE) + SAVE_FLAGS_OFFSET
    local flagsLow = memory.read_u32_be(flagsAddrLow)
    return (flagsLow & flag_mask) ~= 0
end

-- Debug function to print all flag data
function print_debug_flag_status()
    -- Function disabled - no longer needed
end

-- Debug functions removed

-- Save current attempt and seed information
local function save_current_run_info()
    local file = io.open("usr/current_run_info.json", "w")
    if file then
        local run_info = {
            attempt = CONFIG.USER.ATTEMPTS,
            seed = state.run.seed,
            timestamp = os.time()
        }
        file:write(json.encode(run_info))
        file:close()
    end
end

-- Check if current run matches the saved run info (for crash recovery)
local function check_run_continuity()
    local file = io.open("usr/current_run_info.json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        if content and content ~= "" then
            local success, saved_info = pcall(json.decode, content)
            if success and saved_info then
                -- Check if seed matches the saved attempt
                if saved_info.seed == state.run.seed then
                    -- Additional validation: check if player has any stars
                    local total_stars = 0
                    local star_flags = get_all_star_flags()
                    for _, flags in ipairs(star_flags) do
                        total_stars = total_stars + countbits(flags)
                    end
                    
                    if total_stars > 0 then
                        -- This is definitely a continuation, don't increment attempt
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end
        end
    end
    return false
end

-- Write the warp map data as a JSON file.
local function write_warp_log()
    local file = io.open(CONFIG.FILES.WARP_LOG, "w")
    if file then
        local warp_data = {
            seed = state.run.seed,
            attempt = CONFIG.USER.ATTEMPTS,
            warp_map = state.run.warp_map
        }
        file:write(json.encode(warp_data))
        file:close()
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
    state.mario.lives = memory.read_u16_be(CONFIG.MEM.HUD.LIVES)

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
    
    -- Update last_star_level when entering a new level with stars (excluding castle)
    if level_abbr and state.game.level_id ~= 0 and state.game.level_id ~= 1 and state.game.level_id ~= 6 and state.game.level_id ~= 16 then
        -- Check if this is a level change (not the same as last frame)
        if last_state.game.level_id ~= state.game.level_id then
            state.run.last_star_level = level_abbr
        end
    end

    -- Auto-show detailed star info when entering a main level
    local main_levels = {BBH=true, BoB=true, CCM=true, DDD=true, HMC=true, JRB=true, LLL=true, RR=true, SSL=true, SL=true, TTM=true, TTC=true, THI=true, WDW=true, WMotR=true, Wing=true, WF=true, Metal=true, Vanish=true, SA=true, PSS=true, BitDW=true, BitFS=true, BitS=true}
    if level_abbr and main_levels[level_abbr] and level_abbr ~= last_level_for_auto_display then
        show_star_info_page = level_abbr
        last_level_for_auto_display = level_abbr
    elseif not level_abbr or not main_levels[level_abbr] then
        -- Reset when not in a main level (castle grounds, menu, etc.)
        last_level_for_auto_display = nil
    end

    -- Auto-close detailed star info when returning to outside or inside castle or run ends
    if state.game.level_id == 16 or state.game.level_id == 6 or state.run.end_reason then
        show_star_info_page = nil
        last_level_for_auto_display = nil
    end

    -- Update the warp map if not already set, provided that the intended level is valid
    -- and the current level is not one of the excluded ones (levels 6 and 16).
    if not state.run.warp_map[intended_level_abbr] and state.game.intended_level_id ~= 0 and state.game.level_id ~= 6 and state.game.level_id < 100 and
        state.game.level_id ~= 16 then
        state.run.warp_map[intended_level_abbr] = level_abbr
        -- Save warp data immediately when a new connection is discovered
        write_warp_log()
    end

    -- Update star counts from save file data only when total stars increase
    if state.run.stars > last_state.run.stars then
        local starFlags = get_all_star_flags()
        for i, star_bits in ipairs(starFlags) do
            local course_abbr = get_level_abbr_from_index(i - 1) -- Convert 0-based index to level abbreviation
            if course_abbr then
                local star_count = 0
                for j = 0, 6 do
                    if (star_bits & (1 << j)) ~= 0 then
                        star_count = star_count + 1
                    end
                end
                state.run.star_map[course_abbr] = star_count
            end
        end
        -- print_star_collection_with_addresses()
        -- print_save_file_flags()
    end

    -- If the level indicates a new run (level_id 16) and the run is not already active, initialize a new run.
    if state.game.level_id == 16 and state.run.status == run_state.INACTIVE then
        -- Check if this is a continuation of the same run (crash recovery)
        local is_continuation = check_run_continuity()
        
        if not is_continuation then
            -- This is a new run, increment attempt counter
            CONFIG.USER.ATTEMPTS = CONFIG.USER.ATTEMPTS + 1
            write_attempts_file() -- Save the attempt count immediately
            state.run.warp_map = {} -- Clear previous warp data for new run
        else
            -- Don't clear warp_map for continuation - it will be loaded from file
        end
        
        state.run.status = run_state.ACTIVE
        state.run.end_reason = nil
        state.run.pb = false
        -- Don't clear star_map - we'll populate it from save file data
        
        -- Save current run info for future crash recovery
        save_current_run_info()
    end

    if state.game.level_id == 1 and state.run.status == run_state.COMPLETE then
        state.run.status = run_state.INACTIVE
    end

end

-- Check for run-ending conditions (e.g., Mario dying, falling, environmental hazards).
local function check_run_over_conditions()
    -- Debug tracking removed
    
    if state.mario.hp == 0 and state.mario.lives == 0 and last_state.mario.hp > 0 then
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
    elseif (state.game.delayed_warp_op == 18 or state.game.delayed_warp_op == 20) and state.mario.lives == 0 and last_state.mario.hp > 0 then
        state.run.end_reason = 'Fell Out of Level'
    end

    -- If an end reason is determined, mark the run as pending and record the end time.
    if state.run.end_reason then
        state.run.status = run_state.PENDING

        -- Reset warp information and display when run ends
        state.run.warp_map = {}
        state.run.star_map = {}
        show_star_info_page = nil  -- Return to main display
        last_level_for_auto_display = nil  -- Reset auto-display state

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

-- Load the warp map data from JSON file if it matches current seed and attempt.
local function load_warp_log()
    local file = io.open(CONFIG.FILES.WARP_LOG, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        if content and content ~= "" then
            local success, warp_data = pcall(json.decode, content)
            if success and warp_data then
                -- Check if the saved data matches current seed and attempt
                if warp_data.seed == state.run.seed and warp_data.attempt == CONFIG.USER.ATTEMPTS then
                    state.run.warp_map = warp_data.warp_map or {}
                    return true
                else
                    state.run.warp_map = {} -- Clear old data
                    return false
                end
            end
        end
    end
    return false
end

-- Write all run-related data to files and mark the run as complete.
local function write_data()
    write_attempts_file() -- Write the attempt count.
    write_pb_stars_file() -- Write the PB star count.
    write_run_data_csv() -- Write detailed run data as CSV.
    write_warp_log() -- Write the warp map as JSON.
    state.run.status = run_state.COMPLETE
end

-- Streamer Data output logic
local last_star_count = nil
local last_seed = nil
local last_level_abbr = nil
local last_song = nil
local function write_streamer_data()
    -- Write current star data
    if CONFIG.STREAMER_STAR_DATA and state and state.run and state.run.stars ~= last_star_count then
        local f = io.open("usr/stars.txt", "w")
        if f then f:write(tostring(state.run.stars)); f:close() end
        last_star_count = state.run.stars
    end
    -- Write current seed
    if CONFIG.STREAMER_SEED and state and state.run and state.run.seed ~= last_seed then
        local f = io.open("usr/seed.txt", "w")
        if f then f:write(tostring(state.run.seed)); f:close() end
        last_seed = state.run.seed
    end
    -- Write current level abbreviation
    local main_levels = {BBH=true,BoB=true,CCM=true,DDD=true,HMC=true,JRB=true,LLL=true,RR=true,SSL=true,SL=true,TTM=true,TTC=true,THI=true}
    local level_abbr = get_level_abbr and get_level_abbr(state and state.game and state.game.level_id or 0) or nil
    if CONFIG.STREAMER_LEVEL and level_abbr and main_levels[level_abbr] and level_abbr ~= last_level_abbr then
        local f = io.open("usr/level.txt", "w")
        if f then f:write(level_abbr); f:close() end
        last_level_abbr = level_abbr
    end
    -- Write current song
    if CONFIG.STREAMER_SONG and state and state.game and state.game.song ~= last_song then
        local song_name = get_song_name and get_song_name(state.game.song) or tostring(state.game.song)
        local f = io.open("usr/current_song.txt", "w")
        if f then f:write(song_name); f:close() end
        last_song = state.game.song
    end
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
            CONFIG.SHOW_ONLY_SEEN_LEVELS = config_data.SHOW_ONLY_SEEN_LEVELS or false
            CONFIG.STREAMER_STAR_DATA = config_data.STREAMER_STAR_DATA or false
            CONFIG.STREAMER_SEED = config_data.STREAMER_SEED or false
            CONFIG.STREAMER_LEVEL = config_data.STREAMER_LEVEL or false
            CONFIG.STREAMER_SONG = config_data.STREAMER_SONG or false
            CONFIG.REVERSE_STAR_COLORS = config_data.REVERSE_STAR_COLORS or false
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
        SHOW_CAP_TIMER = CONFIG.SHOW_CAP_TIMER,
        SHOW_ONLY_SEEN_LEVELS = CONFIG.SHOW_ONLY_SEEN_LEVELS,
        STREAMER_STAR_DATA = CONFIG.STREAMER_STAR_DATA,
        STREAMER_SEED = CONFIG.STREAMER_SEED,
        STREAMER_LEVEL = CONFIG.STREAMER_LEVEL,
        STREAMER_SONG = CONFIG.STREAMER_SONG,
        REVERSE_STAR_COLORS = CONFIG.REVERSE_STAR_COLORS
    }
        file:write(json.encode(config_data))
        file:close()
    end
    force_redraw = true
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
    
    -- Smaller font size for warp and level mapping section
    local warp_font_size = math.max(math.floor(game_height / 55), 7)
    local warp_char_width = math.floor(warp_font_size / 1.6)

    local logo_size = math.floor(game_height / 12) -- Define icon size for logos, stars, etc.
    
    -- Get current level abbreviation for color coding
    local current_level_abbr = get_level_abbr and get_level_abbr(state and state.game and state.game.level_id or 0) or nil

    -- Set extra padding for the game screen to accommodate the UI.
    client.SetGameExtraPadding(0, 0, ui_width + 20, 0)

    -- Settings button click detection
    local settings_x = game_width + 10
    local settings_y = game_height - (font_size + 15)
    local settings_w = char_width * 9
    local settings_h = font_size + 10
    
    if input.getmouse().Left and input.getmouse().X >= (settings_x - 4) and input.getmouse().X <= (settings_x + settings_w) and
        input.getmouse().Y >= (settings_y - 2) and input.getmouse().Y <= (settings_y + settings_h) and not config_form then
        -- Make the config form larger for better spacing
        config_form = forms.newform(380, 410, "Configuration", function()
            forms.destroy(config_form)
            config_form = nil
            force_redraw = true
        end)

        local config_form_height = forms.getproperty(config_form, "Height")
        local config_form_width = forms.getproperty(config_form, "Width")

        -- Tracker Settings header
        forms.label(config_form, "Tracker Settings", 10, 5, 360, 20)
        -- Add a dropdown to select the background image.
        local background_image_dropdown_label = forms.label(config_form, "Background Image:", 10, 27, 140, 20)
        local background_image_dropdown = forms.dropdown(config_form, BACKGROUND_IMAGES, 160, 25, 180, 20)
        forms.setproperty(background_image_dropdown, "SelectedItem", CONFIG.BACKGROUND_IMAGE)

        -- Add a checkbox to toggle the song title display.
        local show_song_title_checkbox_label = forms.label(config_form, "Show Song Title", 35, 60, 250, 20)
        local show_song_title_checkbox = forms.checkbox(config_form, nil, 13, 55)
        forms.setproperty(show_song_title_checkbox, "Checked", CONFIG.SHOW_SONG_TITLE)

        -- Add a checkbox to toggle the cap timer display.
        local show_cap_timer_checkbox_label = forms.label(config_form, "Show Cap Timer", 35, 87, 250, 20)
        local show_cap_timer_checkbox = forms.checkbox(config_form, nil, 13, 82)
        forms.setproperty(show_cap_timer_checkbox, "Checked", CONFIG.SHOW_CAP_TIMER)

        -- Add a checkbox to toggle showing only seen levels.
        local show_only_seen_levels_label = forms.label(config_form, "Show Only Seen Levels", 35, 114, 250, 20)
        local show_only_seen_levels_checkbox = forms.checkbox(config_form, nil, 13, 109)
        forms.setproperty(show_only_seen_levels_checkbox, "Checked", CONFIG.SHOW_ONLY_SEEN_LEVELS)

        -- Add a checkbox to reverse star colors.
        local reverse_star_colors_label = forms.label(config_form, "Reverse Star Colors", 35, 141, 250, 20)
        local reverse_star_colors_checkbox = forms.checkbox(config_form, nil, 13, 136)
        forms.setproperty(reverse_star_colors_checkbox, "Checked", CONFIG.REVERSE_STAR_COLORS)

        -- Streamer Data header
        forms.label(config_form, "------------------ Streamer Data ------------------", 10, 165, 360, 20)
        
        -- Add description about streamer data functionality
        forms.label(config_form, "When enabled, text files will be automatically", 10, 185, 360, 15)
        forms.label(config_form, "generated and updated in IronMarioTracker/usr/", 10, 200, 360, 15)
        forms.label(config_form, "whenever there are in-game changes.", 10, 215, 360, 15)
        
        -- Add checkboxes for streamer data
        local streamer_star_data_checkbox = forms.checkbox(config_form, "Current Star Data", 13, 240)
        forms.setproperty(streamer_star_data_checkbox, "Checked", CONFIG.STREAMER_STAR_DATA)
        local streamer_seed_checkbox = forms.checkbox(config_form, "Current Seed", 13, 265)
        forms.setproperty(streamer_seed_checkbox, "Checked", CONFIG.STREAMER_SEED)
        local streamer_level_checkbox = forms.checkbox(config_form, "Current Level", 13, 290)
        forms.setproperty(streamer_level_checkbox, "Checked", CONFIG.STREAMER_LEVEL)
        local streamer_song_checkbox = forms.checkbox(config_form, "Current Song", 13, 315)
        forms.setproperty(streamer_song_checkbox, "Checked", CONFIG.STREAMER_SONG)

        -- Add a button to save the configuration.
        forms.button(config_form, "OK", function()
            CONFIG.BACKGROUND_IMAGE = forms.getproperty(background_image_dropdown, "SelectedItem")
            CONFIG.SHOW_SONG_TITLE = forms.ischecked(show_song_title_checkbox)
            CONFIG.SHOW_CAP_TIMER = forms.ischecked(show_cap_timer_checkbox)
            CONFIG.SHOW_ONLY_SEEN_LEVELS = forms.ischecked(show_only_seen_levels_checkbox)
            CONFIG.STREAMER_STAR_DATA = forms.ischecked(streamer_star_data_checkbox)
            CONFIG.STREAMER_SEED = forms.ischecked(streamer_seed_checkbox)
            CONFIG.STREAMER_LEVEL = forms.ischecked(streamer_level_checkbox)
            CONFIG.STREAMER_SONG = forms.ischecked(streamer_song_checkbox)
            CONFIG.REVERSE_STAR_COLORS = forms.ischecked(reverse_star_colors_checkbox)
            save_config()
            forms.destroy(config_form)
            config_form = nil
            force_redraw = true
        end, 50, 360, 100, 30)

        -- Add a button to close the configuration form.
        forms.button(config_form, "Cancel", function()
            forms.destroy(config_form)
            config_form = nil
            force_redraw = true
        end, 230, 360, 100, 30)
    end
    
    -- Level Select button click detection
    local level_select_x = settings_x + settings_w + 10
    local level_select_y = settings_y
    local level_select_w = char_width * 14
    local level_select_h = settings_h
    
    if input.getmouse().Left and input.getmouse().X >= (level_select_x - 4) and input.getmouse().X <= (level_select_x + level_select_w) and
        input.getmouse().Y >= (level_select_y - 2) and input.getmouse().Y <= (level_select_y + level_select_h) and not config_form then
        
        -- Create level selection form
        
        -- Create level selection form
        local level_select_form = forms.newform(280, 120, "Level Select", function()
            forms.destroy(level_select_form)
            level_select_form = nil
            force_redraw = true
        end)
        
        -- Level selection header
        forms.label(level_select_form, "Select a level:", 10, 10, 260, 20)
        
        -- Create list of all levels
        local all_levels = {"BoB", "WF", "JRB", "CCM", "BBH", "HMC", "LLL", "SSL", "DDD", "SL", "WDW", "TTM", "THI",
                           "TTC", "RR", "PSS", "SA", "WMotR", "Wing", "Metal", "Vanish", "BitDW", "BitFS", "BitS"}
        
        -- Add dropdown for level selection
        local level_dropdown = forms.dropdown(level_select_form, all_levels, 10, 30, 200, 20)
        forms.setproperty(level_dropdown, "SelectedItem", "BoB")
        
        -- Add button to view selected level
        forms.button(level_select_form, "View", function()
            local selected_level = forms.getproperty(level_dropdown, "SelectedItem")
            show_star_info_page = selected_level
            forms.destroy(level_select_form)
            level_select_form = nil
            force_redraw = true
        end, 20, 70, 80, 30)
        
        -- Add cancel button
        forms.button(level_select_form, "Cancel", function()
            forms.destroy(level_select_form)
            level_select_form = nil
            force_redraw = true
        end, 180, 70, 80, 30)
    end
    
    -- Current level button click detection
    local current_level_x = level_select_x + level_select_w + 10
    local current_level_y = settings_y
    local current_level_w = char_width * 8
    local current_level_h = settings_h
    
    if current_level_abbr and current_level_abbr ~= "" and current_level_abbr ~= "?" then
        _G.prev_current_level_mouse_left = _G.prev_current_level_mouse_left or false
        local mouse = input.getmouse()
        if mouse.Left and not _G.prev_current_level_mouse_left and mouse.X >= (current_level_x - 4) and mouse.X <= (current_level_x + current_level_w) and
           mouse.Y >= (current_level_y - 2) and mouse.Y <= (current_level_y + current_level_h) and not show_star_info_page and not config_form then
            show_star_info_page = current_level_abbr
            force_redraw = true
        end
        _G.prev_current_level_mouse_left = mouse.Left
    end

    -- Skip rendering if no changes in state (to save processing).
    local state_changed = not tablex.deepcompare(state, last_state)
    if not state_changed and not force_redraw then
        return
    end



    -- Optionally display the current song title if the toggle is enabled (always show if enabled, even on star info page)
    if CONFIG.SHOW_SONG_TITLE and CONFIG.MUSIC_DATA.SONG_MAP[state.game.song] then
        gui.drawString(20 + math.floor(char_width / 2), game_height - (20 + math.floor(font_size * 1.25)),
            get_song_name(state.game.song), nil, nil, font_size, CONFIG.FONT_FACE)
    end

    -- If star info page is active, draw only that and return
    if show_star_info_page then
        render_star_info_page(show_star_info_page)
        force_redraw = false
        return
    end

    -- All UI drawing code below this point

    -- Draw the background image if one is selected.
    if CONFIG.BACKGROUND_IMAGE ~= "(None)" then
        gui.drawImage("img/bg/" .. CONFIG.BACKGROUND_IMAGE .. ".jpg", game_width, 0, ui_width, game_height)
    end

    -- Draw the Settings button in the bottom right of the game screen.
    local settings_x = game_width + 10
    local settings_y = game_height - (font_size + 15)
    local settings_w = char_width * 9
    local settings_h = font_size + 10
    
    -- Draw button background (matching back button style)
    gui.drawBox(settings_x - 4, settings_y - 2, settings_x + settings_w, settings_y + settings_h, "black", "gray")
    
    -- Draw "Settings" text centered in the button
    gui.drawString(settings_x, settings_y + 4, "Settings", "black", nil, font_size, CONFIG.FONT_FACE)
    
    -- Draw the Level Select button next to the Settings button
    local level_select_x = settings_x + settings_w + 10
    local level_select_y = settings_y
    local level_select_w = char_width * 14
    local level_select_h = settings_h
    
    -- Draw button background (matching back button style)
    gui.drawBox(level_select_x - 4, level_select_y - 2, level_select_x + level_select_w, level_select_y + level_select_h, "black", "gray")
    
    -- Draw "Level Select" text centered in the button
    gui.drawString(level_select_x, level_select_y + 4, "Level Select", "black", nil, font_size, CONFIG.FONT_FACE)
    
            -- Draw current level button (only when in a valid level)
        if current_level_abbr and current_level_abbr ~= "" and current_level_abbr ~= "?" then
            local current_level_x = level_select_x + level_select_w + 10
            local current_level_y = settings_y
            local current_level_w = char_width * 8  -- Wider to fit "Vanish" and longer names
            local current_level_h = settings_h
            
            -- Draw button background (matching other button style)
            gui.drawBox(current_level_x - 4, current_level_y - 2, current_level_x + current_level_w, current_level_y + current_level_h, "black", "gray")
            
            -- Draw current level abbreviation centered in the button
            gui.drawString(current_level_x + (current_level_w / 2), current_level_y + 4, current_level_abbr, "black", nil, font_size, CONFIG.FONT_FACE, nil, "center")
        end

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

    -- Draw background box for stats section
    local stats_box_x = game_width + 5
    local stats_box_y = font_size * 4
    local stats_box_w = math.floor(ui_width / 2) - 10
    local stats_box_h = font_size * 4 + 10
    gui.drawBox(stats_box_x, stats_box_y, stats_box_x + stats_box_w, stats_box_y + stats_box_h, nil, "#222222")
    
    -- Render attempt number.
    gui.drawString(game_width + 13, font_size * 5 - 8, "Attempt #" .. CONFIG.USER.ATTEMPTS, nil, nil, font_size, CONFIG.FONT_FACE)

    -- Render seed number.
    gui.drawString(game_width + 13, font_size * 6 - 8, "Seed: " .. state.run.seed, nil, nil, font_size, CONFIG.FONT_FACE)
    -- Render current star count and personal best (PB) stars.
    gui.drawString(game_width + 13, font_size * 7 - 8, "Stars: " .. state.run.stars, nil, nil, font_size, CONFIG.FONT_FACE)
    gui.drawString(game_width + 13, font_size * 8 - 8, "PB: " .. CONFIG.USER.PB_STARS, "yellow", nil,
        font_size, CONFIG.FONT_FACE)



    -- If the run is over (pending or complete), display "RUN OVER!" and "NEW PB!" if applicable.
    if state.run.status == run_state.PENDING or state.run.status == run_state.COMPLETE then
        gui.drawString(game_width + math.floor((ui_width / 3) * 2), font_size * 3, "RUN OVER!", "red", nil, font_size,
            CONFIG.FONT_FACE)
        if state.run.pb then
            gui.drawString(game_width + math.floor((ui_width / 3) * 2), font_size * 4, "NEW PB!", "lightgreen", nil,
                font_size, CONFIG.FONT_FACE)
        end
    end

    -- Define an ordered list of level abbreviations for displaying the unified table.
    local ordered_keys = {"BoB", "WF", "JRB", "CCM", "BBH", "HMC", "LLL", "RR", "SSL", "DDD", "SL", "WDW", "TTM", "THI",
                          "TTC", "PSS", "SA", "WMotR", "Wing", "Metal", "Vanish", "BitDW", "BitFS"}


    -- Calculate positions for left and right columns.
    local left_col_x = game_width + 10
    local right_col_x = game_width + math.floor(ui_width / 2)

    -- Add a toggle to show all levels or only those with data (warp or stars)
    if state.input.show_all_levels_toggle_pressed == nil then
        state.input.show_all_levels_toggle_pressed = false
        state.input.show_all_levels = true -- default: show all
    end
    local current_inputs = joypad.get()
    if current_inputs["P1 L"] and current_inputs["P1 R"] and current_inputs["P1 X"] and current_inputs["P1 Y"] and not state.input.show_all_levels_toggle_pressed then
        state.input.show_all_levels_toggle_pressed = true
        state.input.show_all_levels = not state.input.show_all_levels
    elseif (not current_inputs["P1 L"] or not current_inputs["P1 R"] or not current_inputs["P1 X"] or not current_inputs["P1 Y"]) and state.input.show_all_levels_toggle_pressed then
        state.input.show_all_levels_toggle_pressed = false
    end

    -- Render the unified table header.
    local table_header_y = font_size * 11
    -- Remove the unified table header line
    local table_start_y = table_header_y + (font_size * 2)

    -- Build the unified table: for each level, find the warp destination and star count.
    local unified_entries = {}
    for _, level_abbr in ipairs(ordered_keys) do
        -- Find the warp destination: search warp_map for a key whose value matches this level_abbr
        local warp_dest = "?"
        for src, dest in pairs(state.run.warp_map) do
            if src == level_abbr then
                warp_dest = dest
                break
            end
        end
        -- Only add if showing all, or if there is data
        if not CONFIG.SHOW_ONLY_SEEN_LEVELS or (warp_dest ~= "?" or (state.run.star_map[warp_dest] or 0) > 0) then
            table.insert(unified_entries, {
                warp_source = level_abbr,
                level_abbr = warp_dest,
                star_count = state.run.star_map[warp_dest] or 0
            })
        end
    end

    -- Determine maximum label widths for left and right columns to align star counts.
    local left_max_width = 0
    local right_max_width = 0
    for i, entry in ipairs(unified_entries) do
        local label_width = string.len(entry.warp_source .. " → " .. entry.level_abbr) * warp_char_width
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
    
    -- Add padding for star counters (reduced spacing)
    local star_padding = warp_char_width * 5  -- Reduced space for "⭐ xN" 
    left_max_width = left_max_width + star_padding
    right_max_width = right_max_width + star_padding

    -- Always draw a dark background behind the warps & stars table (increased height to include icons)
    local table_header_y = font_size * 8  -- Moved up to make room for icons
    local table_start_y = table_header_y + (font_size * 2)
    local table_bg_x = game_width
    local table_bg_y = table_start_y - warp_font_size // 2
    local table_bg_w = ui_width
    local table_bg_h = (warp_font_size + 3) * 12 + warp_font_size // 2 + font_size * 3  -- Minimal extra height
    gui.drawBox(table_bg_x, table_bg_y, table_bg_x + table_bg_w, table_bg_y + table_bg_h, nil, "#222222")
    


    -- Render Toad, MIPS, and Key icons at the top of the box
    local icon_size = math.floor(warp_font_size * 1.8)
    local icon_spacing = icon_size + 10
    local group_spacing = icon_size + 20 -- Extra spacing between groups
    
    -- Calculate total width including group spacing for centering
    local total_width = (2 * icon_spacing) + group_spacing + (1 * icon_spacing) + group_spacing + (1 * icon_spacing)
    local start_x = game_width + math.floor((ui_width - total_width) / 2) - 10
    local icon_y = table_bg_y + warp_font_size * 0.5  -- Position at very top of box
    
    -- Only show icons when in a valid game state (not main menu)
    if state.game.level_id ~= 0 and state.game.level_id ~= 1 then
        -- Toad icons (3 total)
        for i = 1, 3 do
            local has_toad = check_save_flag(0x01000000 << (i - 1)) -- COLLECTED_TOAD_STAR_1, 2, 3
            local img_path = has_toad and "img/toad.png" or "img/no_toad.png"
            gui.drawImage(img_path, start_x + (i - 1) * icon_spacing, icon_y, icon_size, icon_size)
        end
        
        -- MIPS icons (2 total) - with gap after toads
        for i = 1, 2 do
            local has_mips = check_save_flag(0x08000000 << (i - 1)) -- COLLECTED_MIPS_STAR_1, 2
            local img_path = has_mips and "img/mips.png" or "img/no_mips.png"
            gui.drawImage(img_path, start_x + (2 * icon_spacing) + group_spacing + (i - 1) * icon_spacing, icon_y, icon_size, icon_size)
        end
        
        -- Key icons (2 total) - with gap after mips
        for i = 1, 2 do
            local has_key = false
            if i == 1 then
                -- Key 1: HAVE_KEY_1 OR UNLOCKED_BASEMENT_DOOR
                has_key = check_save_flag(0x00000010) or check_save_flag(0x00000040)
            else
                -- Key 2: HAVE_KEY_2 OR UNLOCKED_UPSTAIRS_DOOR
                has_key = check_save_flag(0x00000020) or check_save_flag(0x00000080)
            end
            local img_path = has_key and "img/key.png" or "img/no_key.png"
            gui.drawImage(img_path, start_x + (2 * icon_spacing) + group_spacing + (1 * icon_spacing) + group_spacing + (i - 1) * icon_spacing, icon_y, icon_size, icon_size)
        end
    end
    
    -- Add spacing between icons and warp list
    local warp_start_y = icon_y + icon_size + warp_font_size
    
    -- Render unified entries in two columns with color coding
    for i, entry in ipairs(unified_entries) do
        local col, row
        if i <= 12 then
            col = 1
            row = i
        else
            col = 2
            row = i - 12
        end
        local x = (col == 1) and left_col_x or right_col_x
        local y = warp_start_y + (row - 1) * (warp_font_size + 3)
        
        -- Get color based on warp pair logic
        local text_color = get_warp_pair_color(entry.warp_source, entry.level_abbr)
        

        
        -- Show 'Warp Source → Level' (source on left, destination on right)
        local label = string.format("%s → %s", entry.warp_source, entry.level_abbr)
        gui.drawString(x, y, label, text_color, nil, warp_font_size, CONFIG.FONT_FACE)
        
        -- Calculate star counter position with proper spacing
        local max_width = (i <= 12) and left_max_width or right_max_width
        local star_x = x + max_width - star_padding
        
        -- Show the star icon/count aligned to the right side of the column
        if entry.level_abbr ~= "?" and entry.star_count > 0 then
            gui.drawImage("img/star.png", star_x, y + (warp_font_size * 0.1), warp_font_size * 0.8, warp_font_size * 0.8)
            gui.drawString(star_x + warp_font_size * 0.8 + 1, y, string.format("x%d", entry.star_count), "yellow", nil, warp_font_size, CONFIG.FONT_FACE)
        end
    end





    -- At the end of render_ui, reset force_redraw
    force_redraw = false
end

load_config()

-- Read stored attempt count and personal best star count from files.
read_attempts_file()
read_pb_stars_file()


-- List of Levels to show detailed info for.
local MAIN_LEVELS = {
    BBH = true, BoB = true, CCM = true, DDD = true, HMC = true, JRB = true, LLL = true, RR = true,
    SSL = true, SL = true, TTM = true, TTC = true, THI = true, WDW = true, WMotR = true, Wing = true, 
    Metal = true, Vanish = true, SA = true, PSS = true, BitDW = true, BitFS = true, BitS = true
}





-- Add this at the top of the file or near other config tables:
local STAR_DESCRIPTIONS = {
    BoB = {
        "Defeat King Bob-omb", -- Defeat King Bob-omb
        "Win Koopa Race", -- Win Koopa Race
        "Box Star", -- Shoot to the Island in the Sky
        "Red Coins", -- Find the 8 Red Coins
        "Find 5 Secrets", -- Find the 5 Secrets
        "Open Star 1", -- Behind Chain Chomp's Gate
        "100-Coin Star" -- 100-Coin Star
    },
    WF = {
        "Defeat Whomp", -- Chip Off Whomp's Block
        "Open Star 1", -- To the Top of the Fortress
        "Open Star 2", -- Shoot into the Wild Blue
        "Red Coins", -- Red Coins on the Floating Isle
        "Open Star 3", -- Fall onto the Caged Island
        "Open Star 4", -- Blast Away the Wall
        "100-Coin Star" -- 100-Coin Star
    },
    JRB = {
        "Star in Ship", -- Plunder in the Sunken Ship
        "Eel Tail", -- Can the Eel Come Out to Play?
        "Treasure Boxes", -- Treasure of the Ocean Cave
        "Red Coins", -- Red Coins on the Ship Afloat
        "Box Star", -- Blast to the Stone Pillar
        "Open Star 1", -- Through the Jet Stream
        "100-Coin Star" -- 100-Coin Star
    },
    CCM = {
        "Complete Slide", -- Slip Slidin' Away
        "Return Baby Penguin", -- Li'l Penguin Lost
        "Penguin Slide Race", -- Big Penguin Race
        "Red Coins", -- Frosty Slide for 8 Red Coins
        "Make Snowman Whole", -- Snowman's Lost His Head
        "Open Star 1", -- Wall Kicks Will Work
        "100-Coin Star" -- 100-Coin Star
    },
    BBH = {
        "Defeat 5 Boos", -- Go on a Ghost Hunt
        "Merry-Go-Round Boos", -- Ride Big Boo's Merry-Go-Round
        "Open Star 1", -- Secret of the Haunted Books
        "Red Coins", -- Seek the 8 Red Coins
        "Defeat Big Boo", -- Big Boo's Balcony
        "Run Around Big Eye", -- Eye to Eye in the Secret Room
        "100-Coin Star" -- 100-Coin Star
    },
    HMC = {
        "Open Star 1", -- Swimming Beast in the Cavern
        "Red Coins", -- Elevate for 8 Red Coins
        "Open Star 2", -- Metal-Head Mario Can Move!
        "Open Star 3", -- Navigating the Toxic Maze
        "Open Star 4", -- A-Maze-Ing Emergency Exit
        "Open Star 5", -- Watch for Rolling Rocks
        "100-Coin Star" -- 100-Coin Star
    },
    LLL = {
        "Defeat Big Bully", -- Boil the Big Bully
        "3 Shiny Bullies", -- Bully the Bullies
        "Red Coins", -- 8-Coin Puzzle with 15 Pieces
        "Open Star 1", -- Red-Hot Log Rolling
        "Volcano: Open Star 1", -- Hot-Foot-It into the Volcano
        "Volcano: Open Star 2", -- Elevator Tour in the Volcano
        "100-Coin Star" -- 100-Coin Star
    },
    SSL = {
        "Hit Bird", -- In the Talons of the Big Bird
        "Open Star 1", -- Shining Atop the Pyramid
        "Pyramid: Open Star 1", -- Inside the Ancient Pyramid
        "Pyramid: Hand Boss", -- Stand Tall on the Four Pillars
        "Red Coins", -- Free Flying for 8 Red Coins
        "Pyramid: 5 Secrets", -- Pyramid Puzzle
        "100-Coin Star" -- 100-Coin Star
    },
    DDD = {
        "Open Star 1", -- Board Bowser's Sub
        "4 Chests", -- Chests in the Current
        "Red Coins", -- Pole-Jumping for Red Coins
        "Sub Area: Rings of Water", -- Through the Jet Stream
        "Mantaray Rings", -- The Manta Ray's Reward
        "Open Star 2", -- Collect the Caps...
        "100-Coin Star" -- 100-Coin Star
    },
    SL = {
        "Open Star 1", -- Snowman's Big Head
        "Defeat Bully", -- Chill with the Bully
        "Open Star 2", -- In the Deep Freeze
        "Box Star", -- Whirl from the Freezing Pond
        "Red Coins", -- Shell Shreddin' for Red Coins
        "Igloo: Open Star 1", -- Into the Igloo
        "100-Coin Star" -- 100-Coin Star
    },
    WDW = {
        "Box Star 1", -- Shocking Arrow Lifts!
        "Box Star 2", -- Top o' the Town
        "5 Secrets", -- Secrets in the Shallows & Sky
        "Open Star 1", -- Express Elevator--Hurry Up!
        "Town: Red Coins", -- Go to Town for Red Coins
        "Town: Open Star 1", -- Quick Race Through Downtown!
        "100-Coin Star" -- 100-Coin Star
    },
    TTM = {
        "Open Star 1", -- Scale the Mountain
        "Catch Monkey", -- Mystery of the Monkey Cage
        "Red Coins", -- Scary 'Shrooms, Red Coins
        "Open Star 2", -- Mysterious Mountainside
        "Open Star 3", -- Breathtaking View from Bridge
        "Open Star 4", -- Blast to the Lonely Mushroom
        "100-Coin Star" -- 100-Coin Star
    },
    THI = {
        "Small: 5 Big Piranhas", -- Pluck the Piranha Flower
        "Small: Box Star", -- The Tip Top of the Huge Island
        "Small:Race Koopa", -- Rematch with Koopa the Quick
        "Big: 5 Secrets", -- Five Itty Bitty Secrets
        "Small: Red Coins", -- Wiggler's Red Coins
        "Defeat Wiggler", -- Make Wiggler Squirm
        "100-Coin Star" -- 100-Coin Star
    },
    TTC = {
        "Open Star 1", -- Roll into the Cage
        "Open Star 2", -- The Pit and the Pendulums
        "Open Star 3", -- Get a Hand
        "Open Star 4", -- Stomp on the Thwomp
        "Open Star 5", -- Timed Jumps on Moving Bars
        "Red Coins", -- Stop Time for Red Coins
        "100-Coin Star" -- 100-Coin Star
    },
    RR = {
        "Open Star 1", -- Cruiser Crossing the Rainbow
        "Open Star 2", -- The Big House in the Sky
        "Red Coins", -- Coins Amassed in a Maze
        "Open Star 3", -- Swingin' in the Breeze
        "Open Star 4", -- Tricky Triangles!
        "Box Star 1", -- Somewhere Over the Rainbow
        "100-Coin Star" -- 100-Coin Star
    },
    PSS = {
        "Box Star",
        "Slide Fast - Under 21 Secs"
    },
    WMotR = {
        "Red Coins"
    },
    Wing = {
        "Red Coins"
    },
    Metal = {
        "Red Coins"
    },
    Vanish = {
        "Red Coins"
    },
    SA = {
        "Red Coins"
    },
    BitDW = {
        "Red Coins"
    },
    BitFS = {
        "Red Coins"
    },
    BitS = {
        "Red Coins"
    }
}

-- Add this near STAR_DESCRIPTIONS or at the top:
local LEVEL_FULL_NAMES = {
    BoB = "Bob-omb Battlefield",
    WF = "Whomp's Fortress",
    JRB = "Jolly Roger Bay",
    CCM = "Cool, Cool Mountain",
    BBH = "Big Boo's Haunt",
    HMC = "Hazy Maze Cave",
    LLL = "Lethal Lava Land",
    SSL = "Shifting Sand Land",
    DDD = "Dire, Dire Docks",
    SL = "Snowman's Land",
    WDW = "Wet-Dry World",
    TTM = "Tall, Tall Mountain",
    THI = "Tiny-Huge Island",
    TTC = "Tick Tock Clock",
    RR = "Rainbow Ride",
    PSS = "Peach's Secret Slide",
    WMotR = "Wing Mario Over the Rainbow",
    Wing = "Wing Cap",
    Metal = "Metal Cap",
    Vanish = "Vanish Cap",
    SA = "Secret Aquarium",
    BitDW = "Bowser in the Dark World",
    BitFS = "Bowser in the Fire Sea",
    BitS = "Bowser in the Sky"
}

-- Add this near STAR_DESCRIPTIONS:
local STAR_IMAGES = {
    BoB = {
        nil,           -- Star 1: Defeat King Bob-omb
        nil,           -- Star 2: Win Koopa Race
        "img/block.png",   -- Star 3: Shoot to the Island in the Sky
        "img/redcoin.png", -- Star 4: Find the 8 Red Coins
        nil,           -- Star 5: Find the 5 Secrets
        nil,           -- Star 6: Behind Chain Chomp's Gate
        nil            -- Star 7: 100-Coin Star
    },
    WF = {
        nil,           -- Star 1: Chip Off Whomp's Block
        nil,           -- Star 2: To the Top of the Fortress
        nil,           -- Star 3: Shoot into the Wild Blue
        "img/redcoin.png", -- Star 4: Red Coins on the Floating Isle
        nil,           -- Star 5: Fall onto the Caged Island
        nil,           -- Star 6: Blast Away the Wall
        nil            -- Star 7: 100-Coin Star
    },
    JRB = {
        nil,           -- Star 1: Plunder in the Sunken Ship
        nil,           -- Star 2: Can the Eel Come Out to Play?
        nil,           -- Star 3: Treasure of the Ocean Cave
        "img/redcoin.png", -- Star 4: Red Coins on the Ship Afloat
        "img/block.png",   -- Star 5: Blast to the Stone Pillar
        nil,           -- Star 6: Through the Jet Stream
        nil            -- Star 7: 100-Coin Star
    },
    CCM = {
        nil,           -- Star 1: Slip Slidin' Away
        nil,           -- Star 2: Li'l Penguin Lost
        nil,           -- Star 3: Big Penguin Race
        "img/redcoin.png", -- Star 4: Frosty Slide for 8 Red Coins
        nil,           -- Star 5: Snowman's Lost His Head
        nil,           -- Star 6: Wall Kicks Will Work
        nil            -- Star 7: 100-Coin Star
    },
    BBH = {
        nil,           -- Star 1: Go on a Ghost Hunt
        nil,           -- Star 2: Ride Big Boo's Merry-Go-Round
        nil,           -- Star 3: Secret of the Haunted Books
        "img/redcoin.png", -- Star 4: Seek the 8 Red Coins
        nil,           -- Star 5: Big Boo's Balcony
        nil,           -- Star 6: Eye to Eye in the Secret Room
        nil            -- Star 7: 100-Coin Star
    },
    HMC = {
        nil,           -- Star 1: Swimming Beast in the Cavern
        "img/redcoin.png", -- Star 2: Elevate for 8 Red Coins
        nil,           -- Star 3: Metal-Head Mario Can Move!
        nil,           -- Star 4: Navigating the Toxic Maze
        nil,           -- Star 5: A-Maze-Ing Emergency Exit
        nil,           -- Star 6: Watch for Rolling Rocks
        nil            -- Star 7: 100-Coin Star
    },
    LLL = {
        nil,           -- Star 1: Boil the Big Bully
        nil,           -- Star 2: Bully the Bullies
        "img/redcoin.png", -- Star 3: 8-Coin Puzzle with 15 Pieces
        nil,           -- Star 4: Red-Hot Log Rolling
        nil,           -- Star 5: Hot-Foot-It into the Volcano
        nil,           -- Star 6: Elevator Tour in the Volcano
        nil            -- Star 7: 100-Coin Star
    },
    SSL = {
        nil,           -- Star 1: In the Talons of the Big Bird
        nil,           -- Star 2: Shining Atop the Pyramid
        nil,           -- Star 3: Inside the Ancient Pyramid
        nil,           -- Star 4: Stand Tall on the Four Pillars
        "img/redcoin.png", -- Star 5: Free Flying for 8 Red Coins
        nil,           -- Star 6: Pyramid Puzzle
        nil            -- Star 7: 100-Coin Star
    },
    DDD = {
        nil,           -- Star 1: Board Bowser's Sub
        nil,           -- Star 2: Chests in the Current
        "img/redcoin.png", -- Star 3: Pole-Jumping for Red Coins
        nil,           -- Star 4: Through the Jet Stream
        nil,           -- Star 5: The Manta Ray's Reward
        nil,           -- Star 6: Collect the Caps...
        nil            -- Star 7: 100-Coin Star
    },
    SL = {
        nil,           -- Star 1: Snowman's Big Head
        nil,           -- Star 2: Chill with the Bully
        nil,           -- Star 3: In the Deep Freeze
        "img/block.png",   -- Star 4: Whirl from the Freezing Pond
        "img/redcoin.png", -- Star 5: Shell Shreddin' for Red Coins
        nil,           -- Star 6: Into the Igloo
        nil            -- Star 7: 100-Coin Star
    },
    WDW = {
        "img/block.png",  -- Star 1: Shocking Arrow Lifts!
        "img/block.png",  -- Star 2: Top o' the Town
        nil,           -- Star 3: Secrets in the Shallows & Sky
        nil,           -- Star 4: Express Elevator--Hurry Up!
        "img/redcoin.png", -- Star 5: Go to Town for Red Coins
        nil,           -- Star 6: Quick Race Through Downtown!
        nil            -- Star 7: 100-Coin Star
    },
    TTM = {
        nil,           -- Star 1: Scale the Mountain
        nil,           -- Star 2: Mystery of the Monkey Cage
        "img/redcoin.png", -- Star 3: Scary 'Shrooms, Red Coins
        nil,           -- Star 4: Mysterious Mountainside
        nil,           -- Star 5: Breathtaking View from Bridge
        nil,           -- Star 6: Blast to the Lonely Mushroom
        nil            -- Star 7: 100-Coin Star
    },
    THI = {
        nil,           -- Star 1: Pluck the Piranha Flower
        "img/block.png",   -- Star 2: The Tip Top of the Huge Island
        nil,           -- Star 3: Rematch with Koopa the Quick
        nil,           -- Star 4: Five Itty Bitty Secrets
        "img/redcoin.png", -- Star 5: Wiggler's Red Coins
        nil,           -- Star 6: Make Wiggler Squirm
        nil            -- Star 7: 100-Coin Star
    },
    TTC = {
        nil,           -- Star 1: Roll into the Cage
        nil,           -- Star 2: The Pit and the Pendulums
        nil,           -- Star 3: Get a Hand
        nil,           -- Star 4: Stomp on the Thwomp
        nil,           -- Star 5: Timed Jumps on Moving Bars
        "img/redcoin.png", -- Star 6: Stop Time for Red Coins
        nil            -- Star 7: 100-Coin Star
    },
    RR = {
        nil,           -- Star 1: Cruiser Crossing the Rainbow
        nil,           -- Star 2: The Big House in the Sky
        "img/redcoin.png", -- Star 3: Coins Amassed in a Maze
        nil,           -- Star 4: Swingin' in the Breeze
        nil,           -- Star 5: Tricky Triangles!
        "img/block.png",  -- Star 6: Somewhere Over the Rainbow
        nil            -- Star 7: 100-Coin Star
    },
    PSS = {
        "img/block.png", 
        nil
    },
    WMotR = {
        "img/redcoin.png"
    },
    Wing = {
        "img/redcoin.png"
    },
    Metal = {
        "img/redcoin.png"
    },
    Vanish = {
        "img/redcoin.png"
    },
    SA = {
        "img/redcoin.png"
    },
    BitDW = {
        "img/redcoin.png"
    },
    BitFS = {
        "img/redcoin.png"
    },
    BitS = {
        "img/redcoin.png"
    }
}

-- Update star_map from save file data
local function update_star_map_from_save()
    local starFlags = get_all_star_flags()
    for i, star_bits in ipairs(starFlags) do
        local course_abbr = get_level_abbr_from_index(i - 1)
        if course_abbr then
            local star_count = 0
            for j = 0, 6 do
                if (star_bits & (1 << j)) ~= 0 then
                    star_count = star_count + 1
                end
            end
            state.run.star_map[course_abbr] = star_count
        end
    end
end

function render_star_info_page(level_abbr)
    local game_width = client.bufferwidth()
    local game_height = client.bufferheight()
    local ui_width = math.floor((game_height * (16 / 9)) - game_width) - 20
    local font_size = math.max(math.floor(game_height / 50), 8)
    local char_width = math.floor(font_size / 1.6)
    -- Draw the background image if one is selected (same as normal view page)
    if CONFIG.BACKGROUND_IMAGE ~= "(None)" then
        gui.drawImage("img/bg/" .. CONFIG.BACKGROUND_IMAGE .. ".jpg", game_width, 0, ui_width, game_height)
    else
        -- Fallback to solid black background if no image is selected
        gui.drawBox(game_width, 0, game_width + ui_width, game_height, "black", "black")
    end
    
    -- Draw background box for level detail content
    local content_box_x = game_width + 10
    local content_box_y = font_size * 3 - 3
    local content_box_w = ui_width - 20
    local content_box_h = (20 * font_size) + 50 -- Extended further to provide space under the final star description
    gui.drawBox(content_box_x, content_box_y, content_box_x + content_box_w, content_box_y + content_box_h, nil, "#222222")
    
    local back_x = game_width + 10
    local back_y = 5
    local back_w = char_width * 8
    local back_h = font_size + 10
    gui.drawBox(back_x - 4, back_y - 2, back_x + back_w, back_y + back_h, "gray", "white")
    gui.drawString(back_x, back_y + 4, "< Back", "black", nil, font_size, CONFIG.FONT_FACE)
    
    -- Draw the Settings button in the top right
    local settings_x = game_width + ui_width - (char_width * 9) - 10
    local settings_y = 5
    local settings_w = char_width * 9
    local settings_h = font_size + 10
    
    -- Draw button background (matching back button style)
    gui.drawBox(settings_x - 4, settings_y - 2, settings_x + settings_w, settings_y + settings_h, "black", "gray")
    
    -- Draw "Settings" text centered in the button
    gui.drawString(settings_x, settings_y + 4, "Settings", "black", nil, font_size, CONFIG.FONT_FACE)
    
    -- Draw the Level Select button next to the Settings button
    local level_select_x = settings_x - (char_width * 14) - 10
    local level_select_y = settings_y
    local level_select_w = char_width * 14
    local level_select_h = settings_h
    
    -- Draw button background (matching back button style)
    gui.drawBox(level_select_x - 4, level_select_y - 2, level_select_x + level_select_w, level_select_y + level_select_h, "black", "gray")
    
    -- Draw "Level Select" text centered in the button
    gui.drawString(level_select_x, level_select_y + 4, "Level Select", "black", nil, font_size, CONFIG.FONT_FACE)
    local image_base_size = math.floor(ui_width * 0.3)
    local img_width = math.floor(ui_width * 0.35)
    local img_height = math.floor(game_height * 0.13)
    local img_x = game_width + math.floor((ui_width - image_base_size) / 2)
    local img_y = font_size * 3
    local img_path = string.format("img/levels/%s.jpg", level_abbr)
    gui.drawImage(img_path, img_x, img_y, image_base_size, image_base_size)
    
    -- Render cap timer next to the level picture (if enabled and active)
    if state.mario.cap_timer > 0 and CONFIG.SHOW_CAP_TIMER then
        local cap_x = game_width + 10  -- Position to the left of the level image
        local cap_y = img_y + image_base_size / 2  -- Center vertically with the image
        local seconds_remaining = tostring(math.floor(state.mario.cap_timer / 30))
        gui.drawString(cap_x - 6, cap_y - font_size, "Cap Timer", "yellow", nil, font_size, CONFIG.FONT_FACE)
        gui.drawString(cap_x + 26, cap_y + font_size - 12, seconds_remaining, "yellow", nil, font_size, CONFIG.FONT_FACE)
    end
    local level_name = LEVEL_FULL_NAMES[level_abbr] or level_abbr
    local name_y = img_y + image_base_size + font_size * 1.2
    gui.drawString(game_width + math.floor(ui_width / 2), name_y, level_name, nil, nil, font_size, CONFIG.FONT_FACE, nil, "center")
    -- Abbreviation in parentheses below
    gui.drawString(game_width + math.floor(ui_width / 2), name_y + font_size * 1.1, string.format("(%s)", level_abbr), "gray", nil, math.floor(font_size * 0.9), CONFIG.FONT_FACE, nil, "center")

    local course_index = get_index_from_level_abbr(level_abbr)
    if course_index ~= nil then
        local file_index = get_current_file_index()
        local star_flags = get_star_flags_for_course(file_index, course_index)
        local coin_count = get_coins_flags_for_course(file_index, course_index)
        local star_descriptions = STAR_DESCRIPTIONS[level_abbr] or {}
        local star_y = name_y + font_size * 2.5
        local star_size = font_size * 1.4
        local max_stars = #star_descriptions
        if max_stars == 0 then max_stars = 1 end -- Default to at least 1 star
        
        local row_x = game_width + math.floor(ui_width / 2) - math.floor((max_stars * (star_size + 8)) / 2)
        for i = 0, max_stars - 1 do
            local collected = (star_flags & (1 << i)) ~= 0
            local icon = collected and "img/star.png" or "img/empty_star.png"
            local x = row_x + i * (star_size + 8)
            gui.drawImage(icon, x, star_y, star_size, star_size)
            gui.drawString(x + star_size // 2, star_y + star_size + 2, tostring(i+1), "white", nil, math.floor(font_size * 0.8), CONFIG.FONT_FACE, nil, "center")
        end
        local below_y = star_y + star_size + font_size * 1.5
        -- Only show max coins for main levels (not small levels)
        local small_levels = {WMotR = true, Wing = true, Metal = true, Vanish = true, SA = true, PSS = true, BitDW = true, BitFS = true, BitS = true}
        local details_y
        if not small_levels[level_abbr] then
            -- Add a line break before star details
            details_y = below_y + font_size * 1.8 - 15
        else
            -- For small levels, no max coins display
            details_y = below_y + font_size * 0.6 - 15
        end
        local icon_size = math.floor(font_size * 0.8)
        local max_stars = #star_descriptions
        if max_stars == 0 then max_stars = 1 end -- Default to at least 1 star
        
        for i = 0, max_stars - 1 do
            local desc = star_descriptions[i+1] or (tostring(i+1))
            local star_images = STAR_IMAGES[level_abbr] or {}
            local image_name = star_images[i+1]
            
            -- Check if this star is collected
            local is_collected = (star_flags & (1 << i)) ~= 0
            local text_color
            if CONFIG.REVERSE_STAR_COLORS then
                text_color = is_collected and get_safe_color("white") or get_safe_color("gray")
            else
                text_color = is_collected and get_safe_color("gray") or get_safe_color("white")
            end
            
            local text_content = string.format("%d: %s", i+1, desc)
            local center_x = game_width + math.floor(ui_width / 2)
            
            -- Draw text centered
            gui.drawString(center_x, details_y + font_size * i * 1.2, text_content, text_color, nil, font_size, CONFIG.FONT_FACE, nil, "center")
            
            -- Draw icon after text if it exists
            if image_name then
                local text_width = string.len(text_content) * math.floor(font_size / 1.6)  -- Approximate text width
                local icon_x = center_x + (text_width / 2) + 10  -- Position icon after centered text with 10px spacing
                gui.drawImage(image_name, icon_x, details_y + font_size * i * 1.2, icon_size, icon_size)
            end
        end
    end
end

-- Main loop: executes every frame.
while true do
    -- Always-run block for level image clickable area (runs every frame)
    do
        local game_width = client.bufferwidth()
        local game_height = client.bufferheight()
        local ui_width = math.floor((game_height * (16 / 9)) - game_width) - 20
        local font_size = math.max(math.floor(game_height / 50), 8)
        local ordered_keys = {"BoB", "WF", "JRB", "CCM", "BBH", "HMC", "LLL", "SSL", "DDD", "SL", "WDW", "TTM", "THI",
                              "TTC", "RR", "PSS", "SA", "WMotR", "Wing", "Metal", "Vanish", "BitDW", "BitFS", "BitS"}
        local current_level_abbr = get_level_abbr and get_level_abbr(state and state.game and state.game.level_id or 0) or nil
        local abbr_in_list = false
        for _, abbr in ipairs(ordered_keys) do
            if abbr == current_level_abbr then abbr_in_list = true break end
        end
        local img_width = math.floor(ui_width * 0.35)
        local img_height = math.floor(game_height * 0.13)
        local img_x = game_width + ui_width - img_width - 8
        local img_y = font_size * 3
        _G.prev_image_mouse_left = _G.prev_image_mouse_left or false
        local mouse = input.getmouse()
        -- Debug prints removed, keep only click detection
        if abbr_in_list and mouse.Left and not _G.prev_image_mouse_left and not show_star_info_page and not config_form
           and mouse.X >= img_x and mouse.X <= (img_x + img_width)
           and mouse.Y >= img_y and mouse.Y <= (img_y + img_height) then
            show_star_info_page = current_level_abbr
            force_redraw = true
        end
        _G.prev_image_mouse_left = mouse.Left
    end
    -- Process on every other frame to reduce CPU load.
    if emu.framecount() % 2 == 0 then
        -- Update game state if the run isn't already pending (i.e., if it's still in progress).
        if state.run.status ~= run_state.PENDING then
            update_game_state()
            
            -- Move warp/star data loading block here
            if not warp_data_loaded then
                if state.run.seed and state.run.seed ~= 0 and state.game.level_id ~= 0 then
                    load_warp_log()
                    update_star_map_from_save()
                    warp_data_loaded = true
                end
            end
        end

        -- If the run is active, check for any conditions that signal the run is over.
        if state.run.status == run_state.ACTIVE then
            check_run_over_conditions()
        end

        -- If a run has ended (pending state), write the run data to files.
        if state.run.status == run_state.PENDING then
            write_data()
        end

        -- Call write_streamer_data in the main loop, after updating state
        write_streamer_data()

        render_ui() -- Render the UI overlay with the current state.
    end

    -- Always-run block for back button click detection on the star info overlay
    if show_star_info_page then
        local game_width = client.bufferwidth()
        local game_height = client.bufferheight()
        local ui_width = math.floor((game_height * (16 / 9)) - game_width) - 20
        local font_size = math.max(math.floor(game_height / 50), 8)
        local char_width = math.floor(font_size / 1.6)
        local back_x = game_width
        local back_y = 5
        local back_w = char_width * 8
        local back_h = font_size + 10
        local mouse = input.getmouse()
        if mouse.Left and mouse.X >= (back_x - 4) and mouse.X <= (back_x + back_w) and mouse.Y >= (back_y - 2) and mouse.Y <= (back_y + back_h) then
            show_star_info_page = nil
            force_redraw = true
        end
        
        -- Track mouse state for level detail page buttons
        _G.prev_level_select_mouse_left = _G.prev_level_select_mouse_left or false
        
        -- Settings button click detection for level detail page
        local settings_x = game_width + ui_width - (char_width * 9) - 10
        local settings_y = 5
        local settings_w = char_width * 9
        local settings_h = font_size + 10
        
        if mouse.Left and mouse.X >= (settings_x - 4) and mouse.X <= (settings_x + settings_w) and
            mouse.Y >= (settings_y - 2) and mouse.Y <= (settings_y + settings_h) and not config_form then
            -- Make the config form larger for better spacing
            config_form = forms.newform(380, 410, "Configuration", function()
                forms.destroy(config_form)
                config_form = nil
                force_redraw = true
            end)

            local config_form_height = forms.getproperty(config_form, "Height")
            local config_form_width = forms.getproperty(config_form, "Width")

            -- Tracker Settings header
            forms.label(config_form, "Tracker Settings", 10, 5, 360, 20)
            -- Add a dropdown to select the background image.
            local background_image_dropdown_label = forms.label(config_form, "Background Image:", 10, 27, 140, 20)
            local background_image_dropdown = forms.dropdown(config_form, BACKGROUND_IMAGES, 160, 25, 180, 20)
            forms.setproperty(background_image_dropdown, "SelectedItem", CONFIG.BACKGROUND_IMAGE)

            -- Add a checkbox to toggle the song title display.
            local show_song_title_checkbox_label = forms.label(config_form, "Show Song Title", 35, 60, 250, 20)
            local show_song_title_checkbox = forms.checkbox(config_form, nil, 13, 55)
            forms.setproperty(show_song_title_checkbox, "Checked", CONFIG.SHOW_SONG_TITLE)

            -- Add a checkbox to toggle the cap timer display.
            local show_cap_timer_checkbox_label = forms.label(config_form, "Show Cap Timer", 35, 87, 250, 20)
            local show_cap_timer_checkbox = forms.checkbox(config_form, nil, 13, 82)
            forms.setproperty(show_cap_timer_checkbox, "Checked", CONFIG.SHOW_CAP_TIMER)

            -- Add a checkbox to toggle showing only seen levels.
            local show_only_seen_levels_label = forms.label(config_form, "Show Only Seen Levels", 35, 114, 250, 20)
            local show_only_seen_levels_checkbox = forms.checkbox(config_form, nil, 13, 109)
            forms.setproperty(show_only_seen_levels_checkbox, "Checked", CONFIG.SHOW_ONLY_SEEN_LEVELS)

            -- Add a checkbox to reverse star colors.
            local reverse_star_colors_label = forms.label(config_form, "Reverse Star Colors", 35, 141, 250, 20)
            local reverse_star_colors_checkbox = forms.checkbox(config_form, nil, 13, 136)
            forms.setproperty(reverse_star_colors_checkbox, "Checked", CONFIG.REVERSE_STAR_COLORS)

            -- Streamer Data header
            forms.label(config_form, "------------------ Streamer Data ------------------", 10, 165, 360, 20)
            
            -- Add description about streamer data functionality
            forms.label(config_form, "When enabled, text files will be automatically", 10, 185, 360, 15)
            forms.label(config_form, "generated and updated in IronMarioTracker/usr/", 10, 200, 360, 15)
            forms.label(config_form, "whenever there are in-game changes.", 10, 215, 360, 15)
            
            -- Add checkboxes for streamer data
            local streamer_star_data_checkbox = forms.checkbox(config_form, "Current Star Data", 13, 240)
            forms.setproperty(streamer_star_data_checkbox, "Checked", CONFIG.STREAMER_STAR_DATA)
            local streamer_seed_checkbox = forms.checkbox(config_form, "Current Seed", 13, 265)
            forms.setproperty(streamer_seed_checkbox, "Checked", CONFIG.STREAMER_SEED)
            local streamer_level_checkbox = forms.checkbox(config_form, "Current Level", 13, 290)
            forms.setproperty(streamer_level_checkbox, "Checked", CONFIG.STREAMER_LEVEL)
            local streamer_song_checkbox = forms.checkbox(config_form, "Current Song", 13, 315)
            forms.setproperty(streamer_song_checkbox, "Checked", CONFIG.STREAMER_SONG)

            -- Add a button to save the configuration.
            forms.button(config_form, "OK", function()
                CONFIG.BACKGROUND_IMAGE = forms.getproperty(background_image_dropdown, "SelectedItem")
                CONFIG.SHOW_SONG_TITLE = forms.ischecked(show_song_title_checkbox)
                CONFIG.SHOW_CAP_TIMER = forms.ischecked(show_cap_timer_checkbox)
                CONFIG.SHOW_ONLY_SEEN_LEVELS = forms.ischecked(show_only_seen_levels_checkbox)
                CONFIG.REVERSE_STAR_COLORS = forms.ischecked(reverse_star_colors_checkbox)
                CONFIG.STREAMER_STAR_DATA = forms.ischecked(streamer_star_data_checkbox)
                CONFIG.STREAMER_SEED = forms.ischecked(streamer_seed_checkbox)
                CONFIG.STREAMER_LEVEL = forms.ischecked(streamer_level_checkbox)
                CONFIG.STREAMER_SONG = forms.ischecked(streamer_song_checkbox)
                save_config()
                forms.destroy(config_form)
                config_form = nil
                force_redraw = true
            end, 50, 360, 100, 30)

            -- Add a button to close the configuration form.
            forms.button(config_form, "Cancel", function()
                forms.destroy(config_form)
                config_form = nil
                force_redraw = true
            end, 230, 360, 100, 30)
        end
        
        -- Level Select button click detection for level detail page
        local level_select_x = settings_x - (char_width * 14) - 10
        local level_select_y = settings_y
        local level_select_w = char_width * 14
        local level_select_h = settings_h
        
        if mouse.Left and mouse.X >= (level_select_x - 4) and mouse.X <= (level_select_x + level_select_w) and
            mouse.Y >= (level_select_y - 2) and mouse.Y <= (level_select_y + level_select_h) and not config_form and not _G.prev_level_select_mouse_left then
            
            -- Create level selection form
            local level_select_form = forms.newform(280, 120, "Level Select", function()
                forms.destroy(level_select_form)
                level_select_form = nil
                force_redraw = true
            end)
            
            -- Level selection header
            forms.label(level_select_form, "Select a level:", 10, 10, 260, 20)
            
            -- Create list of all levels
            local all_levels = {"BoB", "WF", "JRB", "CCM", "BBH", "HMC", "LLL", "SSL", "DDD", "SL", "WDW", "TTM", "THI",
                               "TTC", "RR", "PSS", "SA", "WMotR", "Wing", "Metal", "Vanish", "BitDW", "BitFS", "BitS"}
            
            -- Add dropdown for level selection
            local level_dropdown = forms.dropdown(level_select_form, all_levels, 10, 30, 200, 20)
            forms.setproperty(level_dropdown, "SelectedItem", "BoB")
            
            -- Add button to view selected level
            forms.button(level_select_form, "View", function()
                local selected_level = forms.getproperty(level_dropdown, "SelectedItem")
                show_star_info_page = selected_level
                forms.destroy(level_select_form)
                level_select_form = nil
                force_redraw = true
            end, 20, 70, 80, 30)
            
            -- Add cancel button
            forms.button(level_select_form, "Cancel", function()
                forms.destroy(level_select_form)
                level_select_form = nil
                force_redraw = true
            end, 180, 70, 80, 30)
        end
        
        -- Update level select mouse state tracking
        _G.prev_level_select_mouse_left = mouse.Left
    end

    emu.frameadvance() -- Advance to the next frame.
end
