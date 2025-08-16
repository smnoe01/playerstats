--[[

Copyright (C) 2025
Smnoe01 (Atlante) (discord: smnoe01)

Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International
Public License

By exercising the Licensed Rights (defined below), You accept and agree
to be bound by the terms and conditions of this Creative Commons
Attribution-NonCommercial-ShareAlike 4.0 International Public License
("Public License"). To the extent this Public License may be
interpreted as a contract, You are granted the Licensed Rights in
consideration of Your acceptance of these terms and conditions, and the
Licensor grants You such rights in consideration of benefits the
Licensor receives from making the Licensed Material available under
these terms and conditions. See license.txt for more details

--]]

local modname = core.get_current_modname()
local storage = core.get_mod_storage()
local S = core.get_translator(modname) -- Translation (it, es, en, fr, ru, de)
local C = core.colorize

-- For discord, dcwebhook, etc
local function is_valid_playername(playername)
    return playername and playername ~= ""
end

local default_stats = {
    kills = 0,
    deaths = 0,
    messages = 0,
    blocks_broken = 0,
    blocks_placed = 0,
    items_crafted = 0,
    playtime = 0,
}

local join_times = {}
local dig_batches = {}
local place_batches = {}

-- Make sure the storage is initialized
local function get_storage(key)
    if not key or key == "" then
        return nil
    end

    local success, result = pcall(storage.get_string, storage, key)
    return success and result or nil
end

-- Function to handle potential errors during storage operations
-- This function will log an error if the set operation fails (Debug)
local function save_data (key, value)
    if not key or key == "" or not value then
        return false
    end

    local success = pcall(storage.set_string, storage, key, value)
    if not success then
        core.log("error", "[" .. modname .. "] Failed to save " .. key)
    end

    return success
end

-- Get player statistics, initializing if necessary (newplayer)
local function get_stats(playername)
    if not is_valid_playername then
        return nil
    end

    local data = get_storage("stats_" .. playername)
    if not data or data == "" then
        return nil
    end

    local success, stats = pcall(core.deserialize, data)
    if not success or not stats or type(stats) ~= "table" then
        core.log("warning", "[" .. modname .. "] Corrupted stats for " .. playername .. ", reinitializing")

        return nil
    end

    -- Make sure all default statistics (default_stats) are present
    for key, default_value in pairs(default_stats) do
        if not stats[key] or type(stats[key]) ~= "number" then
            stats[key] = default_value
        end
    end

    return stats
end

local function set_stats(playername, stats)
    if not is_valid_playername or not stats or type(stats) ~= "table" then
        return false
    end

    -- Make sure all statistics are not negative (avoid strange values)
    for key, value in pairs(stats) do
        local num_value = tonumber(value)

        stats[key] = num_value and math.max(0, math.floor(num_value)) or 0
    end

    local success, data = pcall(core.serialize, stats)
    if not success or not data then
        core.log("error", "[" .. modname .. "] Failed to serialize stats for " .. playername)
        return false
    end

    return save_data("stats_" .. playername, data)
end

-- Fonction to ensure player statistics are initialized
-- This function checks if the player exists and initializes their stats if not already done
local function ensure_stats(playername)
    if not is_valid_playername then
        return nil
    end

    local stats = get_stats(playername)
    if not stats then
        stats = table.copy(default_stats)

        if set_stats(playername, stats) then
            core.log("info", "[" .. modname .. "] Initialized stats for " .. tostring(playername))
        else
            return nil
        end

    end

    return stats
end

local function modify_stat(playername, stat_key, amount)
    if not playername or not stat_key or not amount or amount == 0 then
        return false
    end

    local stats = ensure_stats(playername)
    if not stats then
        return false
    end

    -- We add the amount to the specified stat
    stats[stat_key] = stats[stat_key] + amount
    return set_stats(playername, stats) -- We replace the old stats by the new ones
end

local function player_exists(playername)
    return playername and playername ~= "" and (core.player_exists(playername) or get_stats(playername) ~= nil)
end

local function format_number(num)
    if not num or type(num) ~= "number" then
        return "0"
    end

    -- Convert the number to a string and remove any decimal part
    -- This is to ensure we only format whole numbers
    local str = tostring(math.floor(num))
    if #str <= 3 then
        return str
    end

    -- Reverse the string, add spaces every 3 digits, then reverse it back
    -- This is a simple way to format numbers with spaces
    -- Example: "1234567" => "1 234 567"
    return str:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
end

local function format_time(seconds)
    if not seconds or type(seconds) ~= "number" then
        return "00h 00m 00s" -- Default format
    end
    local total_seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(total_seconds / 3600)
    local minutes = math.floor((total_seconds % 3600) / 60)
    local secs = total_seconds % 60

    local digits = math.max(2, string.len(tostring(hours)))
    local hour_format = "%0" .. digits .. "d"

    local formatted_hours = string.format(hour_format, hours)
    local formatted_hours_with_spaces = format_number(tonumber(formatted_hours))

    return formatted_hours_with_spaces .. "h " .. string.format("%02dm %02ds", minutes, secs)
end

-- Function to update the playtime for a player 
-- This function calculates the time spent since the last join and updates the playtime stat 
-- It avoid to use globalstep, its more efficient and consume less resources
-- This is called when a player join/leave and when he use the commande "/r <player_name>"
-- Warning it can contain some bugs/errors
local function update_playtime(playername)
    if not playername or not join_times[playername] then
        return false
    end

    local current_time = os.time()
    local session_time = current_time - join_times[playername]

    if session_time > 0 then
        modify_stat(playername, "playtime", session_time)
        join_times[playername] = current_time

        return true
    end

    return false
end

local function save_playtime(playername)
    if not playername or not join_times[playername] then
        return
    end

    local session_time = os.time() - join_times[playername]
    if session_time > 0 then
        modify_stat(playername, "playtime", session_time)
    end
end

-- We use batches to avoid too many calls to modify_stat, like when we have more of 30+ player, it can be very dangerous in terms of used ressources
-- Batches are used to accumulate dig/place actions and process them in one go
-- This is more efficient and avoids performance issues
local function process_dig_batch(playername)
    if dig_batches[playername] and dig_batches[playername] > 0 then
        modify_stat(playername, "blocks_broken", dig_batches[playername])
        dig_batches[playername] = nil
    end
end

local function process_place_batch(playername)
    if place_batches[playername] and place_batches[playername] > 0 then
        modify_stat(playername, "blocks_placed", place_batches[playername])
        place_batches[playername] = nil
    end
end

--------------------------------------------------------------
--- CORE EVENTS PART
--------------------------------------------------------------

core.register_on_newplayer(function(player)
    if not player then return end
    local playername = player:get_player_name()

    if playername and playername ~= "" then
        ensure_stats(playername)
    end
end)

core.register_on_joinplayer(function(player)
    if not player then
        return
    end

    local playername = player:get_player_name()

    if playername and playername ~= "" then
        ensure_stats(playername)
        join_times[playername] = os.time()
    end
end)

core.register_on_leaveplayer(function(player, timed_out)
    if not player then
        return
    end

    local playername = player:get_player_name()

    if playername and playername ~= "" then
        save_playtime(playername)
        process_dig_batch(playername)
        process_place_batch(playername)

        join_times[playername] = nil
    end
end)

-- We avoid to lost the playtime when the server shutdown
-- This function will save the playtime for all players when the server is shutting down
core.register_on_shutdown(function()
    for playername, _ in pairs(join_times) do
        save_playtime(playername)
    end
end)

core.register_on_dieplayer(function(player, reason)
    if not player then
        return
    end

    local playername = player:get_player_name()
    if playername and playername ~= "" then
        modify_stat(playername, "deaths", 1)
    end

    -- if the reason is of the death is a punch so we check if the reason if an object if yes then we check its a player to avoid erros
    if reason.type == "punch" and reason.object and reason.object:is_player() then
        local killer_name = reason.object:get_player_name()
        if killer_name and killer_name ~= "" then
            modify_stat(killer_name, "kills", 1)
        end
    end
end)

core.register_on_chat_message(function(playername, message)
    if not is_valid_playername or not message or message == "" then
        return
    end
    -- Maybe add that a command can be a message ?
    -- But player will spam command like /help, no one will see it so maybe useless to do that
    modify_stat(playername, "messages", 1)
end)

core.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then
        return
    end

    local playername = digger:get_player_name()

    if playername and playername ~= "" then
        modify_stat(playername, "blocks_broken", 1)
    end
end)

core.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if not placer or not placer:is_player() then
        return
    end

    local playername = placer:get_player_name()
    if playername and playername ~= "" then
        modify_stat(playername, "blocks_placed", 1)
    end
end)

core.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
    if not player or not player:is_player() or not itemstack then
        return
    end

    local playername = player:get_player_name()
    if not is_valid_playername then
        return
    end

    local count = itemstack:get_count()
    if count and count > 0 then
        modify_stat(playername, "items_crafted", count)
    end
end)

--------------------------------------------------------------
--- COMMANDS PART
--------------------------------------------------------------

core.register_chatcommand("r", {
    params = S("[@1]", "playername"),
    description = S("Show player statistics"),
    func = function(playername, param)
        if not is_valid_playername then
            return false, S("Invalid player name")
        end

        local target = (param and param ~= "" and param) or playername
        if not player_exists(target) then
            return false, S("Player @1 not found", target)
        end

        if core.player_exists(target) then
            update_playtime(target)
        end

        local stats = get_stats(target)
        if not stats then
            return false, S("No statistics found for @1", target)
        end

        local kd_ratio = stats.deaths > 0 and string.format("%.2f", stats.kills / stats.deaths) or "N/A"
        local msg = C("#FCD203", S("Statistics for @1:", target)) .. "\n" ..

                    -- Kills / Deaths / K/D Ratio
                    S("Kills: @1 | Deaths: @2 | K/D: @3",
                        C("#FCD203", format_number(stats.kills)),
                        C("#FCD203", format_number(stats.deaths)),
                        C("#FCD203", kd_ratio)) .. "\n" ..

                    -- Messages
                    S("Messages: @1", C("#FCD203", format_number(stats.messages))) .. "\n" ..

                    -- Blocks broken / Blocks placed
                    S("Blocks broken: @1 | Blocks placed: @2",
                        C("#FCD203", format_number(stats.blocks_broken)),
                        C("#FCD203", format_number(stats.blocks_placed))) .. "\n" ..

                    -- Items crafted
                    S("Items crafted: @1", C("#FCD203", format_number(stats.items_crafted))) .. "\n" ..

                    -- Playtime
                    S("Playtime: @1", C("#FCD203", format_time(stats.playtime)))
        return true, msg
    end,
})

local reset_confirmations = {}

local function planify_reset(playername)
    local current_time = os.time()
    reset_confirmations[playername] = current_time + 30
    local warning_msg = C("red",
        S("This will permanently delete all your statistics! Use /reset_stats again within 30 seconds to confirm.")
    )
    return true, warning_msg
end

local function reset_stats(playername)
    if not is_valid_playername then
        return false, S("Invalid player name")
    end

    local current_time = os.time()
    update_playtime(playername)

    if reset_confirmations[playername] then
        local time_left = reset_confirmations[playername] - current_time
        if time_left > 0 then
            reset_confirmations[playername] = nil
            local new_stats = table.copy(default_stats)
            if set_stats(playername, new_stats) then
                return true, S("Your statistics have been reset successfully!")
            else
                return false, C("red", S("Failed to reset statistics"))
            end
        else
            reset_confirmations[playername] = nil
        end
    end

    return planify_reset(playername)
end

core.register_chatcommand("reset_stats", {
    params = "",
    description = S("Reset your statistics (requires confirmation)"),
    func = function(playername, param)
        return reset_stats(playername)
    end,
})

core.register_chatcommand("set_stats", {
    params = S("<player_name> <type> <amount>"),
    description = S("Set player statistics (kills, deaths, messages, blocks_broken, blocks_placed, items_crafted, playtime)"),
    privs = {server = true},
    func = function(name, param)
        local parts = param and param:match("%S") and {} or nil
        if not parts then
            return false, S("Usage: /set_stats <player_name> <type> <amount>")
        end

        for p in param:gmatch("%S+") do
            parts[#parts + 1] = p
        end

        if #parts ~= 3 then
            return false, S("Usage: /set_stats <player_name> <type> <amount>")
        end

        local target, stat_type, amount = parts[1], parts[2]:lower(), tonumber(parts[3])

        if not amount or amount < 0 then
            return false, S("Invalid amount: @1 (must be a positive number)", parts[3])
        end

        if not default_stats[stat_type] then
            return false, S("Invalid stat type. Valid types: kills, deaths, messages, blocks_broken, blocks_placed, items_crafted, playtime")
        end

        local stats = get_stats(target)
        if not stats then
            return false, S("Player @1 not found", target)
        end

        local old_val = stats[stat_type]
        stats[stat_type] = amount

        if not set_stats(target, stats) then
            return false, S("Failed to save statistics for @1", target)
        end

        local old_str = stat_type == "playtime" and format_time(old_val) or format_number(old_val)
        local new_str = stat_type == "playtime" and format_time(amount) or format_number(amount)
        local stat_name = stat_type:gsub("_", " "):gsub("^%l", string.upper)

        return true, C("#FCD203", S("Statistics updated for @1", target)) .. "\n" ..
                     S("@1: @2 => @3", stat_name, C("red", old_str), C("#FCD203", new_str))
    end,
})

--------------------------------------------------------------
--- API PART
--------------------------------------------------------------
-- Heres the API for the playerstats mod
-- This API allows you to get, set, modify and reset player statistics
playerstats = {}


-- All statistics for the player, or nil if the player does not exist
-- Kills, deaths, messages, blocks_broken, blocks_placed, items_crafted, playtime
function playerstats.get_stats(playername)
    return get_stats(playername)
end


-- Set a specified stat for a player, it will increase the the old value by the new one
-- stats: Kills, deaths, messages, blocks_broken, blocks_placed, items_crafted, playtime
function playerstats.set_stats(playername, stats)
    return set_stats(playername, stats)
end


-- Available stats:
-- kills, deaths, messages, blocks_broken, blocks_placed, items_crafted
-- and playtime (in seconds)
-- How does it work, it will get the current stats for player and add the amount to the specified stats
-- DO NOT CONFUSE IT WITH playerstats.set_stats !!
function playerstats.modify_stat(playername, stat_key, amount)
    return modify_stat(playername, stat_key, amount)
end


-- Check if the player exists, either in the game or in the statistics
-- Returns true if the player exists, false otherwise
function playerstats.player_exists(playername)
    return player_exists(playername)
end


-- Reset the statistics for a player
-- This will set all statistics to their default values (0)
-- Returns true if successful, false otherwise
function playerstats.reset_stats(playername)
    return reset_stats(playername)
end



--------------------------------------------------
--- MIGRATION PART
--------------------------------------------------
if core.get_modpath("atl_server_statistics") then
    local migration_key = "migration_done_v2"
    local stats_mapping = {
        ["Messages Count"] = "messages",
        ["Deaths Count"] = "deaths", 
        ["Kills Count"] = "kills",
        ["Nodes Dug"] = "blocks_broken",
        ["Nodes Placed"] = "blocks_placed",
        ["Items Crafted"] = "items_crafted",
        ["PlayTime"] = "playtime"
    }

    storage.set_string(storage, "migration_done", "false")

    local function perform_migration()
        local success, data = pcall(atl_server_statistics.mod_storage.to_table, atl_server_statistics.mod_storage)

        if not success or not data or not data.fields then
            storage.set_string(storage, migration_key, "true")
            core.chat_send_all(core.colorize("#FF0000", S("Automatic migration to 'playerstats' failed. Use /force_migrate")))
            return
        end

        local atl_data = data.fields
        local migrated_players = {}

        for key, value in pairs(atl_data) do
            for old_stat, new_stat in pairs(stats_mapping) do
                local escaped_stat = old_stat:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
                local player_name = key:match("^(.+)_" .. escaped_stat .. "$")

                if player_name and player_name ~= "" then
                    migrated_players[player_name] = migrated_players[player_name] or table.copy(default_stats)
                    local numeric_value = tonumber(value)

                    if numeric_value and numeric_value >= 0 then
                        migrated_players[player_name][new_stat] = math.floor(numeric_value)
                    end
                end
            end
        end

        local migrated_count = 0
        for player_name, player_stats in pairs(migrated_players) do
            if set_stats(player_name, player_stats) then
                migrated_count = migrated_count + 1
            end
        end

        storage.set_string(storage, migration_key, "true")

        if migrated_count > 0 then
            core.chat_send_all(C("red", "Success! @1 players migrated to new system 'playerstats'", migrated_count))
            core.chat_send_all(C("red", "IMPORTANT: You can now disable 'atl_server_statistics' mod and restart server"))
        else
            core.chat_send_all(C("red", S("No data found to migrate for 'playerstats'")))
        end
    end

    core.register_chatcommand("force_migrate", {
        description = S("Force migration from atl_server_statistics"),
        privs = {server = true},
        func = function()
            storage.set_string(storage, migration_key, "false")
            perform_migration()
            return true, S("Migration forced")
        end,
    })

    function atl_server_statistics.increment_event_stat(player_name, event_key, amount)
        -- Nothing, we disable it
    end

    function atl_server_statistics.update_playtime_on_stats(player_name)
        -- Nothing, we disable it
    end

    core.register_on_mods_loaded(function()
        core.after(1, perform_migration)
    end)
end