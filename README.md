# PlayerStats (1.1.0 Bug Fix)
Adds statistics for each player

## Features

This mod records the following statistics for each player:

- **Kills et Deaths**: PvP, Kills and Deaths
- **Messages**: Number of messages sent in chat
- **Blocks**: Number of blocks destroyed and placed
- **Craft**: Number of items crafted
- **Playing time**: Total playing time

## Installation
1. Place the mod folder in your `mods/` directory or in `world/worldmods`
2. Activate the mod
3. Restart the server

## Use
### Show statistics

```
/r     
```

Example:
```
Statistiques pour alice:
Kills: 15 | Deaths: 8 | K/D: 1.88
Messages: 1 247
Blocks broken: 5 892 | Blocks placed: 3 156  
Items crafted: 421
Playtime: 12h 35m 42s
```

### Reset your statistics

```
/reset_stats
```

This command requires confirmation, so you will need to re-send the /reset_stats command within 30 seconds, otherwise the action will be invalidated. Please note that this action is irreversible.

### Administration

For administrators with the privilege `server`:

```
/set_stats <player_name> <type> <amount>
```

Available types : `kills`, `deaths`, `messages`, `blocks_broken`, `blocks_placed`, `items_crafted`, `playtime`

Examples:
```
/set_stats alice kills 25
/set_stats bob playtime 7200
```

### Data structure

```lua
{
    kills = 0,
    deaths = 0,
    messages = 0,
    blocks_broken = 0,
    blocks_placed = 0,
    items_crafted = 0,
    playtime = 0
}
```

### Api support

All statistics for the player, or nil if the player does not exist
Kills, deaths, messages, blocks_broken, blocks_placed, items_crafted, playtime
```lua
function playerstats.get_stats(playername)
    return get_stats(playername)
end
```


Set a specified stat for a player, it will increase the the old value by the new one
stats: Kills, deaths, messages, blocks_broken, blocks_placed, items_crafted, playtime
```lua
function playerstats.set_stats(playername, stats)
    return set_stats(playername, stats)
end
```

kills, deaths, messages, blocks_broken, blocks_placed, items_crafted
and playtime (in seconds)
How does it work, it will get the current stats for player and add the amount to the specified stats
DO NOT CONFUSE IT WITH playerstats.set_stats !!
```lua
function playerstats.modify_stat(playername, stat_key, amount)
    return modify_stat(playername, stat_key, amount)
end
```

Check if the player exists, either in the game or in the statistics
Returns true if the player exists, false otherwise
```lua
function playerstats.player_exists(playername)
    return player_exists(playername)
end
```

Reset the statistics for a player
This will set all statistics to their default values (0)
Returns true if successful, false otherwise
```lua
function playerstats.reset_stats(playername)
    return reset_stats(playername)
end
```
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
these terms and conditions.
