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
these terms and conditions.

--]]

local modname = core.get_current_modname()
local version = "1.0.0"
local modpath = core.get_modpath(modname)

dofile(modpath .. "/src/api.lua")

core.log("action", "[" .. core.get_current_modname() .. "] Mod initialised, running version " .. version)