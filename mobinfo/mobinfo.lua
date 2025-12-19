--[[
Copyright © 2018, HB of Quetzalcoatl
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
  * Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
  * Neither the name of BattleBrain nor the
  names of its contributors may be used to endorse or promote products
  derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Langly BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'Mobinfo'
_addon.author = 'HB'
_addon.version = '1.8' -- Updated version to reflect changes
_addon.date = '08.22.2025'
_addon.command = 'mobinfo'

config = require('config')
res = require('resources')
texts = require('texts')
local bestiary = require('familydb.ffxi_bestiary_combined_data').bestiary_combined_data
-- Encapsulate all addon functionality in a local table to prevent global scope pollution
local Mobinfo = {}

-- Local variables now part of the Mobinfo table
Mobinfo.currentzone = 0
Mobinfo.database = {}
Mobinfo.monsterName = ""
Mobinfo.monsterFamily = ""

Mobinfo.monsterTextBox = nil

-----------------------------------------------------------------------------------------------
-- Text Setup
defaults = {}
defaults.display = {}
defaults.display.pos = {}
defaults.display.pos.x = 0
defaults.display.pos.y = 0
defaults.display.bg = {}
defaults.display.bg.red = 0
defaults.display.bg.green = 0
defaults.display.bg.blue = 0
defaults.display.bg.alpha = 150
defaults.display.text = {}
defaults.display.text.font = 'Consolas'
defaults.display.text.red = 255
defaults.display.text.green = 255
defaults.display.text.blue = 255
defaults.display.text.alpha = 255
defaults.display.text.size = 10
defaults.display.text.bold = true
defaults.stats = {}
defaults.stats.showMinLevel = true
defaults.stats.showMaxLevel = true
defaults.stats.respawn = true
defaults.stats.showAggro = true
defaults.stats.showLink = true
defaults.stats.showTrueSight = true
defaults.stats.showSight = true
defaults.stats.showSound = true
defaults.stats.showBlood = true
defaults.stats.showMagic = true
defaults.stats.showJA = true
defaults.stats.showScent = true
defaults.stats.showDrops = true
defaults.stats.modifiers = true
defaults.stats.showBestiary = true

settings = config.load(defaults)
settings:save()

-----------------------------------------------------------------------------------------------

-- New: Lookup table for spawn types that should be ignored, for cleaner code
local spawn_types_to_ignore = {
  [1] = true, -- PC
  [2] = true, -- NPC
  [13] = true, -- Player Pet
  [14] = true  -- NPC Pet
}

-- Create the text object based on loaded settings
function Mobinfo.createTextBox()
    Mobinfo.monsterTextBox = texts.new()
    
    if Mobinfo.monsterTextBox then
        Mobinfo.monsterTextBox:pos(settings.display.pos.x, settings.display.pos.y)
        Mobinfo.monsterTextBox:font(settings.display.text.font)
        Mobinfo.monsterTextBox:size(settings.display.text.size)
        Mobinfo.monsterTextBox:visible(true)
        Mobinfo.monsterTextBox:bg_alpha(settings.display.bg.alpha)
        Mobinfo.monsterTextBox:bg_color(settings.display.bg.red,settings.display.bg.green,settings.display.bg.blue)
        Mobinfo.monsterTextBox:alpha(settings.display.text.alpha)
        Mobinfo.monsterTextBox:color(settings.display.text.red,settings.display.text.green,settings.display.text.blue)
        Mobinfo.monsterTextBox:bold(settings.display.text.bold)
		Mobinfo.monsterTextBox:draggable(true)
    else
        print("Error: texts.new() returned a nil value.")
    end
end

-- Load data from the main 'database' folder
function Mobinfo.loadDataFromFile()
    local directory_path = windower.addon_path..'/database'
    local filename = Mobinfo.currentzone .. ".lua"
    local full_file_path = directory_path .. "/" .. filename
    
    local func, err = loadfile(full_file_path)

    if not func then
        print("Error: Could not load file " .. filename .. ". " .. err)
        Mobinfo.database = {}
        return nil
    end
    
    local data_table = func()
    
    Mobinfo.database = data_table
    
    if not Mobinfo.database or not Mobinfo.database.Names then
        print("Error: The file '" .. filename .. "' does not contain a valid 'Names' table.")
        Mobinfo.database = {}
        return nil
    end
    
    return data_table
end

-- Load and merge data from the 'ffxidb' folder
function Mobinfo.loadFfxidbData()
    local directory_path = windower.addon_path..'/ffxidb'
    local filename = Mobinfo.currentzone .. ".lua"
    local full_file_path = directory_path .. "/" .. filename

    local func, err = loadfile(full_file_path)

    if not func then
        return nil
    end
    
    local ffxidb_data = func()
    
    if not ffxidb_data then
        return nil
    end
    
    if ffxidb_data.Names then
        for name, data in pairs(ffxidb_data.Names) do
            if Mobinfo.database.Names and Mobinfo.database.Names[name] then
                for key, value in pairs(data) do
                    Mobinfo.database.Names[name][key] = value
                end
            else
                if not Mobinfo.database.Names then
                    Mobinfo.database.Names = {}
                end
                Mobinfo.database.Names[name] = data
            end
        end
    else
        for name, drops_list in pairs(ffxidb_data) do
            if not Mobinfo.database.Names[name] then
                Mobinfo.database.Names[name] = {}
            end

            if type(Mobinfo.database.Names[name].Drops) ~= 'table' then
                Mobinfo.database.Names[name].Drops = {}
            end

            local existing_drops = {}
            if type(Mobinfo.database.Names[name].Drops) == 'table' then
                for _, drop_entry in ipairs(Mobinfo.database.Names[name].Drops) do
                    existing_drops[drop_entry.name] = true
                end
            end

            for _, new_drop in ipairs(drops_list) do
                if not existing_drops[new_drop.name] then
                    table.insert(Mobinfo.database.Names[name].Drops, new_drop)
                end
            end
        end
    end
end

---
-- Corrected: Use required bestiary data and handle family as a string
function Mobinfo.loadBestiaryData()
    local bestiary_data = bestiary

    if not bestiary_data then
        return nil
    end

    -- The bestiary data is structured differently, so we need to iterate through it
    for name, entry_data in pairs(bestiary_data) do
        -- Process abilities to ensure a consistent format, regardless of whether the mob already exists
        if type(entry_data.abilities) == 'table' then
            local abilities_list = {}
            for _, ability_entry in ipairs(entry_data.abilities) do
                if type(ability_entry) == 'table' and ability_entry.ability then
                    table.insert(abilities_list, ability_entry.ability)
                else
                    -- Handle the case where the entry is already a string
                    table.insert(abilities_list, tostring(ability_entry))
                end
            end
            entry_data.abilities = abilities_list
        end

        -- Check if the mob exists in the main database
        if Mobinfo.database.Names and Mobinfo.database.Names[name] then
            -- If it exists, merge the data
            Mobinfo.database.Names[name].family = entry_data.family
            Mobinfo.database.Names[name].abilities = entry_data.abilities
        else
            -- If the mob does not exist in the main database, create a new entry
            if not Mobinfo.database.Names then
                Mobinfo.database.Names = {}
            end
            Mobinfo.database.Names[name] = entry_data
        end
    end
end

-- Refactored function to handle all data loading
function Mobinfo.load()
    local area = windower.ffxi.get_info()
    Mobinfo.currentzone = area.zone
    Mobinfo.loadDataFromFile()
    Mobinfo.loadFfxidbData()
    Mobinfo.loadBestiaryData() -- New function call
    Mobinfo.monsterName = ""
end

-- Refactored function with a data-driven approach to display information
function Mobinfo.checkAndPrintMonsterData()
    local outputText = {}
    
    if Mobinfo.monsterName ~= "" and Mobinfo.database and Mobinfo.database.Names then
        local searchName = Mobinfo.monsterName:lower():gsub('^%s*(.-)%s*$', '%1')

        for key, value in pairs(Mobinfo.database.Names) do
            if key:lower() == searchName then
                table.insert(outputText, "\\cs(0,255,255)Monster: " .. key .. "\\cr\n")
                
                
                local info_fields = {
                    { setting = settings.stats.showMinLevel, label = "MinLevel: ", value = value.MinLevel },
                    { setting = settings.stats.showMaxLevel, label = "MaxLevel: ", value = value.MaxLevel },
                    { setting = settings.stats.respawn, label = "Respawn: ", value = (value.Respawn or 0) / 60, suffix = " Min" },
                    { setting = settings.stats.showAggro, label = "Aggro: ", value = value.Aggro, is_bool = true },
                    { setting = settings.stats.showLink, label = "Link: ", value = value.Link, is_bool = true },
                    { setting = settings.stats.showTrueSight, label = "TrueSight: ", value = value.TrueSight, is_bool = true },
                    { setting = settings.stats.showSight, label = "Sight: ", value = value.Sight, is_bool = true },
                    { setting = settings.stats.showSound, label = "Sound: ", value = value.Sound, is_bool = true },
                    { setting = settings.stats.showBlood, label = "Blood: ", value = value.Blood, is_bool = true },
                    { setting = settings.stats.showMagic, label = "Magic: ", value = value.Magic, is_bool = true },
                    { setting = settings.stats.showJA, label = "JA: ", value = value.JA, is_bool = true },
                    { setting = settings.stats.showScent, label = "Scent: ", value = value.Scent, is_bool = true },
                }

                for _, field in ipairs(info_fields) do
                    if field.setting and field.value ~= nil then
                        local line = field.label
                        if field.is_bool then
                            local color = (field.value == true) and "\\cs(255,0,0)" or "\\cs(0,255,0)"
                            line = line .. color .. tostring(field.value) .. "\\cr"
                        else
                            line = line .. tostring(field.value)
                        end
                        if field.suffix then
                            line = line .. field.suffix
                        end
                        table.insert(outputText, line .. "\n")
                    end
                end

                if settings.stats.showDrops and type(value.Drops) == 'table' then
                    table.insert(outputText, "\\cs(0,255,255)Drops:\\cr\n")
                    for _, drop_entry in ipairs(value.Drops) do
                        table.insert(outputText, "\\cs(224,235,16)" .. drop_entry.name .. " (" .. drop_entry.average_rate .. ")\\cr\n")
                    end
                end

                if settings.stats.modifiers and value.Modifiers then
                    table.insert(outputText, "\\cs(0,255,255)Weakness Modifiers:\\cr\n")
                    for mod_name, mod_value in pairs(value.Modifiers) do
                        local color = (mod_value >= 1) and "\\cs(0,255,0)" or "\\cs(255,0,0)"
                        table.insert(outputText, mod_name .. ": " .. color .. tostring(mod_value) .. "\\cr\n")
                    end
                end
                
                -- New: Display Bestiary information
                if settings.stats.showBestiary and value.family and type(value.family) == 'string' then
                    table.insert(outputText, "\\cs(0,255,255)Monster Family:\\cr\n")
                    table.insert(outputText, value.family .. "\n")
                end
                if settings.stats.showBestiary and value.abilities and type(value.abilities) == 'table' then
                    table.insert(outputText, "\\cs(0,255,255)Monster Abilities:\\cr\n")
                    for _, ability in ipairs(value.abilities) do
                        table.insert(outputText, ability .. "\n")
                    end
                end

                Mobinfo.monsterTextBox:text(table.concat(outputText, ""))
                return
            end
        end
    end
    
    Mobinfo.monsterTextBox:text("Monster '" .. Mobinfo.monsterName .. "' not found.")
end

-- New: Addon Command Handler to allow for in-game changes
windower.register_event('addon command', function(...)
    local args = {...}
    local command = args[1]
    
    if not command then
        windower.add_to_chat(8, 'Mobinfo: Use "//mobinfo pos [x] [y]" to change position.')
        windower.add_to_chat(8, 'Mobinfo: Use "//mobinfo size [size]" to change font size.')
        windower.add_to_chat(8, 'Mobinfo: Use "//mobinfo save" to save settings.')
        return
    end
    
    command = command:lower()
    
    if command == 'pos' and #args >= 3 then
        local x = tonumber(args[2])
        local y = tonumber(args[3])
        if x and y then
            settings.display.pos.x = x
            settings.display.pos.y = y
            Mobinfo.monsterTextBox:pos(x, y)
            
			settings:save()
        end
    elseif command == 'size' and #args >= 2 then
        local size = tonumber(args[2])
        if size then
            settings.display.text.size = size
            Mobinfo.monsterTextBox:size(size)
            
			settings:save()
        end
    elseif command == 'save' then
		settings:save()
        
        
    else
        windower.add_to_chat(8, 'Mobinfo: Unrecognized command or missing arguments.')
    end
end)

-- Event handlers now call the methods of the Mobinfo table
windower.register_event('zone change', function(new, old)
    Mobinfo.load()
    Mobinfo.monsterTextBox:text('') -- Clear the text box on zone change
end)

windower.register_event('target change', function(new, old)
    local mob = windower.ffxi.get_mob_by_target('t')    
    
    if mob and not spawn_types_to_ignore[mob.spawn_type] then
        Mobinfo.monsterName = mob.name
       
        Mobinfo.checkAndPrintMonsterData()
    else
        Mobinfo.monsterName = ""
        Mobinfo.monsterTextBox:text('')
    end
end)

windower.register_event('load', function()
    
    Mobinfo.createTextBox()
    Mobinfo.load()
end)

windower.register_event('unload', function()
    
    settings:save()
	
end)