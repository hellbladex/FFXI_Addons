--[[
Copyright © 2025, HB of Quetzalcoatl
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Pathfinder nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL HB BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
--------------------------------------------------------------------------------
-- ADDON UTILITIES (Native Lua Replacements)
--------------------------------------------------------------------------------

if not string.trim then
    function string:trim()
        return self:gsub('^%s*(.-)%s*$', '%1')
    end
end

--------------------------------------------------------------------------------
-- ADDON IDENTIFIERS
--------------------------------------------------------------------------------
_addon.version = '1.0'
_addon.name = 'Pathfinder'
_addon.command = 'pf' 
_addon.author = 'HB of Quetz' 
_addon.date = '12.2.2025'

local ADDON_NAME = 'pathfinder'
local LOG_COLOR = 200
local ERROR_COLOR = 167
local HELP_COLOR = 154

config = require('config')

-- Global control variable for the loop
local pathfinder_is_running = false 



-- State variables
local role = 'slave'     
local is_active = true 
local path_queue = {}   
local last_master_pos = {} 
local player_name = nil 



-- ** CENTRALIZED PLAYER DATA STORAGE **
local player_data = {
    name = nil,
    status = nil,
    x = nil,
    y = nil,
    z = nil,
    zone = nil,
	is_charmed = false, 
    is_valid = false    -- Indicates if a full set of data was successfully retrieved
}
defaults = {}
defaults.update_interval = 0.05
defaults.min_distance = 1.0   -- adjusted from 1 to 5 in hopes of fix in laggy areas Master: Records a point only after moving min_distance units.
defaults.max_queue_size = 1000  -- Slave: Maximum number of positions to queue.
defaults.node_tolerance = 0.5 -- Slave: Distance to target before moving to the next node.
defaults.max_node_jump_dist = 50.0 -- Set the execution interval (0.1 seconds = 10 updates per second)
defaults.record_while_busy = false -- If true, Master records/sends even when engaged (status != 0) or charmed.

settings = config.load(defaults)
settings:save()

-- Configuration
local update_interval = settings.update_interval
local min_distance = settings.min_distance   -- adjusted from 1 to 5 in hopes of fix in laggy areas Master: Records a point only after moving min_distance units.
local max_queue_size = settings.max_queue_size  -- Slave: Maximum number of positions to queue.
local node_tolerance = settings.node_tolerance -- Slave: Distance to target before moving to the next node.
local max_node_jump_dist = settings.max_node_jump_dist -- Slave: If distance between current node and next is > this, clear queue.
local record_while_busy = settings.record_while_busy



--------------------------------------------------------------------------------
-- CORE NAVIGATION LOGIC 
--------------------------------------------------------------------------------

local function calculate_distance(p_x, p_y, t_x, t_y)
    local dx = t_x - p_x
    local dy = t_y - p_y
    return math.sqrt(dx*dx + dy*dy) 
end

-- FIX: Use math.atan2 result directly in radians, applying a sign flip for FFXI's coordinate system.
local function run_to_position(p_x, p_y, t_x, t_y)
    local angle_rad = math.atan2((t_y - p_y), (t_x - p_x)) * -1
    windower.ffxi.run(angle_rad) 
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function help()
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: Command List (Prefix: //pf)', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, '---')
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **ROLE & CONTROL**', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **master** : Sets your role to Master (records/sends path via IPC).', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **slave** : Sets your role to Slave (receives/follows path). (Default on load)', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **start** : Activates the pathfinding loop. (Starts automatically on load)', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **stop** : Halts the pathfinding loop (Slave stops running, Master stops recording).', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, '---')
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **QUEUE MANAGEMENT**', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **clear** : Clears all recorded nodes currently stored in the queue.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **status / s** : Shows the current path queue length and settings.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, '---')
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **FILE I/O**', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **mark** : (Master Only) Records your current position to a sequential mark_N.txt file.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **export <filename.txt>** : (Slave Only) Saves the current path queue to a file in the /paths folder.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s ::   In order to export you must do //pf stop on the slave and then run the route with the master.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **import <filename.txt>** : (Slave Only) Loads a path from the /paths folder, replacing the current queue.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s ::   Import can be used to run a saved path on the fly, for instance moving slaves to a pre-recorded spot via send.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, '---')
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **TUNING**', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s ::   Settings do not get auto saved if you find settings you like adjust them in the /data/settings.xml', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **send <dist>** : (Master Only) Sets min. distance (yalms) Master moves before sending an update. (Current: %.2f)', ADDON_NAME, min_distance))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **jump <dist>** : (Slave Only) Sets the max distance (yalms) between nodes before clearing the queue (teleport detection). (Current: %.2f)', ADDON_NAME, max_node_jump_dist))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **interval <hz>** : Sets the addon clock rate (Current: %.2f)', ADDON_NAME, 1/update_interval))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **help** : Displays this help message.', ADDON_NAME))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: **busy** : (Master Only) Toggles recording even when engaged or charmed. (Current: %s)', ADDON_NAME, record_while_busy and 'ON' or 'OFF'))
end

local function reset_state()
    windower.ffxi.run(false)
    
    -- Only clear the path queue if the role is NOT slave.
    if role ~= 'slave' then
        path_queue = {}
    end
    
    last_master_pos = {}
end

local function clear_path_queue()
    path_queue = {}
    windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Path queue manually CLEARED. Length: 0.', ADDON_NAME))
end

local function show_queue_status()
    local length = #path_queue
    local status_message = string.format(':: %s :: Path queue length: %d / %d -- Max jump: %.2f -- Distance to send: %.2f yalms -- Refresh Rate %d hz -- Follow while Engaged %s .', ADDON_NAME, length, max_queue_size, max_node_jump_dist, min_distance, 1/update_interval, record_while_busy and 'ON' or 'OFF')
    windower.add_to_chat(LOG_COLOR, status_message)
end

local function update_role(new_role)
    reset_state()
    role = new_role
    
    local color = LOG_COLOR
    if new_role == 'master' then
        windower.add_to_chat(color, string.format(':: %s :: Role set to MASTER. Ready to record.', ADDON_NAME))
    elseif new_role == 'slave' then
        windower.add_to_chat(color, string.format(':: %s :: Role set to SLAVE. Ready to follow.', ADDON_NAME))
    else
        role = 'none'
        windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Role unset. Use master/slave to assign.', ADDON_NAME))
    end
end

local function toggle_active(state)
    is_active = state
    
    if is_active then
        if role == 'none' then
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Started, but no role set. Use master/slave.', ADDON_NAME))
        else
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Role [%s] ACTIVATED. Resuming path.', ADDON_NAME, role:upper()))
        end
    else
        reset_state()
        windower.add_to_chat(LOG_COLOR, string.format(':: %s :: DEACTIVATED. Path queue manually CLEARED. Length: 0.', ADDON_NAME))
    end
end

-- ** CENTRALIZED DATA REFRESH FUNCTION **
local function refresh_player_data()
    -- Initial Name Acquisition: Use windower.ffxi.get_player() ONCE if name is unknown.
    -- This is the compromise to avoid get_player() in the main loop while still getting the required name.
    if not player_name then
        local p_obj = windower.ffxi.get_player()
        if p_obj and p_obj.name then 
            player_name = p_obj.name
        else 
            player_data.is_valid = false
            return
        end
    end

    -- Get player's mob info (contains name, status, position, charmed)
    local player_mob_info = windower.ffxi.get_mob_by_name(player_name)
    
    -- Get zone info 
    local zone_info = windower.ffxi.get_info()
	
	
    -- Check if we got all necessary info
    if player_mob_info and zone_info and not zone_info.mog_house and zone_info.zone ~= 280 then
        
        -- Aggressively cast and validate coordinates/zone
        player_data.x = tonumber(player_mob_info.x)
        player_data.y = tonumber(player_mob_info.y)
        player_data.z = tonumber(player_mob_info.z)
        player_data.zone = tonumber(zone_info.zone)
         
        -- Pull data points directly from mob object
        player_data.name = player_name
        player_data.status = player_mob_info.status
        player_data.is_charmed = player_mob_info.charmed or false 
        
        -- Final validation that all critical data points are numbers
        player_data.is_valid = (
            type(player_data.x) == 'number' and
            type(player_data.y) == 'number' and
            type(player_data.z) == 'number' and
            type(player_data.zone) == 'number' and
            player_data.name ~= nil
        )
    else
        player_data.is_valid = false
    end
	
end

--------------------------------------------------------------------------------
-- SLAVE LOGIC: RECEIVING AND FOLLOWING
--------------------------------------------------------------------------------


windower.register_event('ipc message', function(msg)
    
    if type(msg) ~= 'string' then return end
    
    -- RULE: Only process IPC messages if the role is SLAVE.
    if role ~= 'slave' then return end

    -- NEW PATTERN: Extract 4 parameters: x, y, z, and zone ID
    local x_str, y_str, z_str, zone_str = msg:match("^PF|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
    
    if not x_str then return end 

    local data = {
        x = tonumber(x_str),
        y = tonumber(y_str),
        z = tonumber(z_str),
        zone = tonumber(zone_str) -- NEW: Assign the zone ID from Master
    }
    
    -- NEW VALIDATION: Check all four numbers
    if not data.x or not data.y or not data.z or not data.zone then return end

    -- ** Read slave zone from centralized data **
    local slave_zone = player_data.zone 
    
    if not player_data.is_valid or not slave_zone then return end -- Slave is not in a valid state

    -- **ZONE MISMATCH CHECK)**
    -- If the received zone ID does not match the Slave's current zone ID, drop the message.
    if data.zone ~= slave_zone then
        --print(string.format('[SLAVE WARNING] Master (%d) is in a different zone than Slave (%d). IPC message dropped.', data.zone, slave_zone))
        return 
    end

    -- INITIAL JUMP CHECK 
    -- ** Read slave position from centralized data **
    local p_x = player_data.x
    local p_y = player_data.y
    
    if p_x and p_y then
        local dist_to_master = calculate_distance(p_x, p_y, data.x, data.y)
        
        -- If the Master's new position is too far from the Slave's current position,
        -- it indicates a teleport occurred while the Master was moving. Clear the queue
        if dist_to_master > max_node_jump_dist then
            --windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: DETECTED INITIAL JUMP! Master (%.2f, %.2f) is %.2f units away. Path cleared and no new node queued.', ADDON_NAME, data.x, data.y, dist_to_master))
            path_queue = {}
            return 
        end
    end
    
    
    --print(string.format('[SLAVE DEBUG] Received Master Zone ID: %d (Matches Slave Zone ID: %d)', data.zone, slave_zone))
    
    -- SLAVE RULE: Only record if the queue is not full
    if #path_queue < max_queue_size then
        path_queue[#path_queue + 1] = data
    end
end)

local function follow_path()
    -- ** Use centralized player_data **
    if not player_data.is_valid then
        --windower.ffxi.run(false)
        return
    end

    local p_x = player_data.x
    local p_y = player_data.y
    local p_zone = player_data.zone 
		
    if #path_queue == 0 then
        --windower.ffxi.run(false) 
        return
    end

    
    local current_target = path_queue[1]
    
    -- Check if the Slave has jumped/teleported away from the path/zone
    if p_zone ~= current_target.zone then
        -- Zone mismatch with the target node's zone
        windower.ffxi.run(false)
        path_queue = {}
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: SLAVE ZONE JUMP DETECTED! Slave is in zone %d, but the next node is in zone %d. Path cleared.', ADDON_NAME, p_zone, current_target.zone))
        return
    end
    
	local dist_to_next_node = calculate_distance(p_x, p_y, current_target.x, current_target.y)


    -- SLAVE RULE: Check distance and delete the node if reached
    if dist_to_next_node < node_tolerance then -- Use the pre-calculated distance
        
        -- ... (The existing 'Check for a large distance jump to the NEXT node' logic remains here) ...
        if #path_queue >= 2 then
            local next_target = path_queue[2]
            local dist_to_next_node_in_path = calculate_distance(current_target.x, current_target.y, next_target.x, next_target.y)
            
            if dist_to_next_node_in_path > max_node_jump_dist then
                -- Distance jump is too large. Clear queue and stop.
                windower.ffxi.run(false)
                path_queue = {} 
                return
            end
        end
        
        table.remove(path_queue, 1) -- Delete the executed node
        
        if #path_queue == 0 then
            windower.ffxi.run(false) -- Stop if queue is now empty
            return
        end
        current_target = path_queue[1] -- Move to the next node
    end

    run_to_position(p_x, p_y, current_target.x, current_target.y)
end

--------------------------------------------------------------------------------
-- MASTER LOGIC: RECORDING AND SENDING
--------------------------------------------------------------------------------


local function record_and_send()
    if role ~= 'master' then return end
	
    -- ** Use centralized player_data **
    if not player_data.is_valid then return end

    -- Get Zone ID and position from centralized data
    local p_zone = player_data.zone
    local p_x = player_data.x
    local p_y = player_data.y
    local p_z = player_data.z
    
    local current_pos = {
        x = p_x, 
        y = p_y,
        z = p_z,
        zone = p_zone 
    }
    
    local should_record = false
    
    local is_last_pos_valid = (
        last_master_pos.x and last_master_pos.y and
        type(last_master_pos.x) == 'number' and
        type(last_master_pos.y) == 'number'
    )

    if not is_last_pos_valid then
        should_record = true
        windower.add_to_chat(LOG_COLOR, '[MASTER LOG] Recording initial/re-recording corrected position.')
    else
        local dist_moved = calculate_distance(current_pos.x, current_pos.y, last_master_pos.x, last_master_pos.y) 
        
        -- MASTER RULE: Only record if moved at least min_distance OR if the zone has changed
        if dist_moved >= min_distance or current_pos.zone ~= last_master_pos.zone then
             should_record = true
        end
    end

    -- ** Use player_data.status and player_data.is_charmed **
	local is_free = player_data.status == 0 or player_data.status == 5 or player_data.status == 85 and player_data.is_charmed == false
	
	if should_record and (record_while_busy or is_free) then
        last_master_pos = current_pos
        
        -- FORMAT: PF|x|y|z|zone
        local message = string.format('PF|%f|%f|%f|%d', 
            current_pos.x, 
            current_pos.y, 
            current_pos.z,
            current_pos.zone 
        )
        
        if type(windower.send_ipc_message) == 'function' then
            windower.send_ipc_message(message)
        else
            if os.clock() % 5.0 < 0.02 then
                windower.add_to_chat(1, ':: FATAL ERROR :: windower.send_ipc_message is unavailable. Cannot function as Master.')
            end
        end
    end
end

local function save_path_queue_to_file(custom_filename)
    if #path_queue == 0 then
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Path queue is empty. Nothing to save.', ADDON_NAME))
        return
    end

    local filename
    if custom_filename and custom_filename:trim() ~= '' then
        -- Use the provided custom filename
        filename = string.format('%s/paths/%s', windower.addon_path, custom_filename)
    else
        -- Create a filename using the current date/time to avoid overwriting 
        local timestamp = os.date('!%Y%m%d_%H%M%S')
        filename = string.format('%s/paths/%s_%s.txt', windower.addon_path, _addon.name, timestamp)
    end

    -- Ensure the 'paths' directory exists
    local paths_dir = string.format('%s/paths', windower.addon_path)
    if windower.dir_exists and not windower.dir_exists(paths_dir) then
        windower.create_dir(paths_dir)
    end
    
    local file = io.open(filename, 'w')
    
    if file then
        file:write(string.format('-- Path queue data for %s\n', _addon.name))
        file:write(string.format('-- Saved on: %s\n', os.date('%Y-%m-%d %H:%M:%S')))
        file:write('-- Format: x, y, z, zone\n\n')
        
        for i, node in ipairs(path_queue) do
            -- Use string.format to ensure a consistent, readable format for each node
            local line = string.format('%f,%f,%f,%d\n', node.x, node.y, node.z, node.zone)
            file:write(line)
        end
        
        file:close()
        windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Path queue saved to: **%s**', ADDON_NAME, filename))
    else
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Could not open file for writing: %s', ADDON_NAME, filename))
    end
end

local function import_path_queue_from_file(filename)
    -- Prepend the paths directory to the filename
    local full_path = string.format('%s/paths/%s', windower.addon_path, filename)
    
    local file = io.open(full_path, 'r')
    
    if not file then
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Could not open file: %s', ADDON_NAME, filename))
        return
    end
    
    local new_queue = {}
    local line_count = 0
    local successful_nodes = 0

    for line in file:lines() do
        line_count = line_count + 1
        
        
        -- Skip comments and empty lines
        if line:match('^%s*%-%-') or line:match('^%s*$') then
            -- Skip to the next iteration of the loop
        else 
            -- Now process the line only if it is NOT a comment or empty
            
            -- Expecting: x, y, z, zone
            local x_str, y_str, z_str, zone_str = line:match("([^,]+),([^,]+),([^,]+),([^,]+)$")
            
            if x_str and y_str and z_str and zone_str then
                local data = {
                    x = tonumber(x_str),
                    y = tonumber(y_str),
                    z = tonumber(z_str),
                    zone = tonumber(zone_str)
                }
                
                -- Basic validation
                if data.x and data.y and data.z and data.zone then
                    new_queue[#new_queue + 1] = data
                    successful_nodes = successful_nodes + 1
                else
                    windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: WARNING: Skipping invalid node on line %d in %s.', ADDON_NAME, line_count, filename))
                end
            else
                windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: WARNING: Skipping malformed line %d in %s.', ADDON_NAME, line_count, filename))
            end
        end
    end
    
    file:close()
    
    if successful_nodes > 0 then
        path_queue = new_queue -- Replace the current queue
        windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Successfully imported %d nodes from %s.', ADDON_NAME, successful_nodes, filename))
    else
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Found no valid nodes in %s. Path queue remains unchanged.', ADDON_NAME, filename))
    end
end

local function save_current_position_to_file()
    if role ~= 'master' then
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Must be in MASTER role to use the mark command.', ADDON_NAME))
        return 
    end

    -- ** Use centralized player_data **
    if not player_data.is_valid then 
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Could not get valid player position data.', ADDON_NAME))
        return 
    end

    -- Get position data from centralized player_data
    local p_zone = player_data.zone
    local p_x = player_data.x
    local p_y = player_data.y
    local p_z = player_data.z
    
    -- All explicit checks for number types are now handled by player_data.is_valid check.

    -- 1. Ensure the 'paths' directory exists
    local paths_dir = string.format('%s/paths', windower.addon_path)
    if windower.dir_exists and not windower.dir_exists(paths_dir) then
        windower.create_dir(paths_dir)
    end
    
    -- 2. Find the next sequential file name
    local sequence_number = 1
    local base_name = 'mark_'
    local full_path
    
    while true do
        local check_filename = string.format('%s%d.txt', base_name, sequence_number)
        full_path = string.format('%s/%s', paths_dir, check_filename)
        
        if windower.file_exists and not windower.file_exists(full_path) then
            -- Found the next available number!
            break 
        end
        sequence_number = sequence_number + 1
        
        
        if sequence_number > 999 then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Sequence number limit (999) reached.', ADDON_NAME))
            return
        end
    end
    
    -- 3. Write the file
    local file = io.open(full_path, 'w')
    
    if file then
        file:write(string.format('-- Single position data for %s\n', _addon.name))
        file:write(string.format('-- Saved on: %s\n', os.date('%Y-%m-%d %H:%M:%S')))
        file:write(string.format('-- Saved as mark_%d.txt\n', sequence_number))
        file:write('-- Format: x, y, z, zone\n\n')
        
        -- The single node line
        local line = string.format('%f,%f,%f,%d\n', p_x, p_y, p_z, p_zone)
        file:write(line)
        
        file:close()
        windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Current position saved to: %s', ADDON_NAME, string.format('mark_%d.txt', sequence_number)))
    else
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Could not open file for writing: %s', ADDON_NAME, full_path))
    end
end
--------------------------------------------------------------------------------
-- MAIN EVENT LOOP AND COMMAND HANDLER
--------------------------------------------------------------------------------

local function main_loop()
    -- ** Centralized data fetch is the very first thing to run **
    refresh_player_data() 
    
    
    if not is_active then return end

    if role == 'master' then
        record_and_send()
    elseif role == 'slave' then
        follow_path()
    end
end

function pathfinder_loop()
    -- Check the flag first. If false, we exit the recursion gracefully.
    if not pathfinder_is_running then
        return
    end

    main_loop() 
    -------------------------------------------------------

    -- Schedule the next run. Time is in seconds.
    coroutine.schedule(pathfinder_loop, update_interval)
	
end

local function update_role_status(cmd, arg) 
    
    if cmd == 'start' then
        if not pathfinder_is_running then
            pathfinder_is_running = true
            
            -- Start the loop immediately (time = 0)
            coroutine.schedule(pathfinder_loop, 0) 
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Pathfinder loop started.', ADDON_NAME))
        else
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Pathfinder is already running.', ADDON_NAME))
        end
        
    elseif cmd == 'stop' then
        if pathfinder_is_running then
            -- Set the flag to false. The currently running coroutine will exit on its next check.
            pathfinder_is_running = false
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Pathfinder loop stopped.', ADDON_NAME))
			clear_path_queue()
			windower.ffxi.run(false)
		else
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Pathfinder is already stopped.', ADDON_NAME))
        end
	elseif cmd == 'master' then
        update_role('master')
        toggle_active(true)
    elseif cmd == 'slave' then
        update_role('slave')
        toggle_active(true)
	elseif cmd == 'help' then 
        help()
    elseif cmd == 'clear' then
        clear_path_queue()
    elseif cmd == 'status' or cmd == 's' then 
        show_queue_status()
	elseif cmd == 'export' then 
		if role ~= 'slave' then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: The **export** command is only available when your role is **Slave**.', ADDON_NAME))
            return
        end
        save_path_queue_to_file(arg)
    elseif cmd == 'import' then 
		if role ~= 'slave' then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: The **import** command is only available when your role is **Slave**.', ADDON_NAME))
            return
        end
        if arg and type(arg) == 'string' and arg:trim() ~= '' then
            import_path_queue_from_file(arg)
        else
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Missing filename. Use: import <filename.txt>.', ADDON_NAME))
        end
	elseif cmd == 'mark' then
		if role ~= 'master' then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: The **mark** command is only available when your role is **MASTER**.', ADDON_NAME))
            return
        end
        save_current_position_to_file()
	elseif cmd == 'jump' then 
		if role ~= 'slave' then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: The **jump** command is only available when your role is **SLAVE**.', ADDON_NAME))
            return
        end
        local new_dist = tonumber(arg) 
        
        if new_dist and new_dist > 0 then
            max_node_jump_dist = new_dist
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: **max_node_jump_dist** set to %.2f.', ADDON_NAME, max_node_jump_dist))
        else
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Invalid distance "%s". Must be a number > 0. Current: %.2f.', ADDON_NAME, tostring(arg), max_node_jump_dist))
        end
	elseif cmd == 'send' then 
		if role ~= 'master' then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: The **send** command is only available when your role is **MASTER**.', ADDON_NAME))
            return
        end
        local new_acc = tonumber(arg) 
        
        if new_acc and new_acc > 0 then
            min_distance = new_acc
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Send every %.2f yalms.', ADDON_NAME, min_distance))
        
        end
	elseif cmd == 'interval' then 
        local new_freq_hz = tonumber(arg) 
        
        if new_freq_hz and new_freq_hz > 0 then
            -- Calculate the new interval (seconds) = 1 / Frequency (Hz)
            update_interval = 1 / new_freq_hz
            
            -- Display the set frequency (Hz) and the resulting interval (seconds)
            windower.add_to_chat(LOG_COLOR, string.format(':: %s :: **update_frequency** set to %.2f Hz (%.3f seconds).', ADDON_NAME, new_freq_hz, update_interval))
        else
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Invalid frequency "%s". Must be a number > 0. Current: %.2f Hz.', ADDON_NAME, tostring(arg), 1/update_interval))
        end
	elseif cmd == 'busy' then
        if role ~= 'master' then
            windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: The **busy** command is only available when your role is **MASTER**.', ADDON_NAME))
            return
        end
        -- Toggle the state
        record_while_busy = not record_while_busy
        settings.record_while_busy = record_while_busy -- Save the change to the settings table
        --settings:save()                               -- Persist the setting to the config file

        local state_str = record_while_busy and 'ON' or 'OFF'
        
        
        windower.add_to_chat(LOG_COLOR, string.format(':: %s :: **record_while_busy** set to **%s**. (Master will record/send even when engaged/charmed).', ADDON_NAME, state_str))
    else
        windower.add_to_chat(ERROR_COLOR, string.format(':: %s :: ERROR: Unknown command "%s". Use: master | slave | start | stop | clear | status | help | busy |send | jump <dist> | interval <hz> | export <filename.txt> | import <filename.txt> | mark', ADDON_NAME, cmd))
    end
end

windower.register_event('addon command', function(...)
    
    
    
    if select('#', ...) == 0 then return end

    local cmd_table = {...} 
    local cmd_word = cmd_table[1]
    local cmd_arg = cmd_table[2] 

    if not cmd_word then return end
	update_role_status(cmd_word:lower(), cmd_arg)
end)

local function initialize_addon_start()
    -- 1. Set the default role and state
    update_role('slave')       -- Sets role = 'slave'
    toggle_active(true)        -- Sets is_active = true and clears state
    
    -- 2. Set the loop control flag and START the scheduled loop
    pathfinder_is_running = true
    coroutine.schedule(pathfinder_loop, 0) 
end

-- Call the initialization function when the addon loads
initialize_addon_start()

windower.register_event('logout', function()
    
    windower.send_command('lua unload pathfinder')
	
end)

-- Initialization message
windower.add_to_chat(LOG_COLOR, string.format(':: %s :: Commands (//pf): master | slave | start | stop | clear | status | help | busy | send | jump <dist> | interval <hz> |  export <filename.txt> | import <filename.txt> | mark', ADDON_NAME, tostring(arg)))
windower.add_to_chat(HELP_COLOR, string.format(':: %s :: Everyone is a SLAVE on load!!! Make sure to set someone as the MASTER!!!', ADDON_NAME, tostring(arg)))