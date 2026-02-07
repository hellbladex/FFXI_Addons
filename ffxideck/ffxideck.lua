_addon.name = 'ffxideck'
_addon.author = 'HB'
_addon.version = '2.1' 

local socket = require("socket")
local udp = socket.udp()

-- Setup UDP
local success, err = udp:setsockname("0.0.0.0", 12345)
udp:settimeout(0) 

local HELP_COLOR = 200
local IPC_PREFIX = "FFXIDECK_CMD:"
local running = true

if not success then
    windower.add_to_chat(HELP_COLOR, 'FFXIDeck UDP Port: ' .. tostring(err))
	windower.add_to_chat(HELP_COLOR, 'FFXIDeck: Using IPC to recieve commands via Master.')
else
    windower.add_to_chat(HELP_COLOR, 'FFXIDeck: UDP Port Connection successful! (Port 12345).')
end

function ffxideck_loop()
    if not running then return end

    if success then
        -- UDP check is nearly instant
        local data, ip, port = udp:receivefrom()
        if data and data ~= "" then
            data = data:gsub("^%s*(.-)%s*$", "%1")
            windower.send_ipc_message(IPC_PREFIX .. data)
            process_command(data)
        end
    end

    -- Schedule next check in 0.1 seconds
    coroutine.schedule(ffxideck_loop, 0.1)
end

function process_command(line)
    if not line or line == "" then return end
    
    local player = windower.ffxi.get_player()
    local my_name = player and player.name or ""
    local sep_index = line:find("|")

    if sep_index then
        local target_name = line:sub(1, sep_index - 1)
        local command = line:sub(sep_index + 1)
        if target_name:lower() == "all" or target_name:lower() == my_name:lower() then
            windower.send_command(command)
        end
    else
        windower.send_command(line)
    end
end

-- Slave/Multi-box listener
windower.register_event('ipc message', function(msg)
    if not success and msg:sub(1, #IPC_PREFIX) == IPC_PREFIX then
        process_command(msg:sub(#IPC_PREFIX + 1))
    end
end)

-- Start the loop
ffxideck_loop()

windower.register_event('unload', function()
    running = false
    if udp then udp:close() end
end)