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
