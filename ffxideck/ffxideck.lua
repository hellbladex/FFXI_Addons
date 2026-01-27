_addon.name = 'ffxideck'
_addon.author = 'HB'
_addon.version = '1.2'

local socket = require("socket")
local server = socket.tcp()

-- Bind settings
-- change from 127.0.0.1 to 0.0.0.0 to connect from another pc
local success, err = server:bind("127.0.0.1", 12345)
if not success then
    print("FFXIDeck: Port 12345 is busy (another instance is already listening).")
    print("FFXIDeck: This instance will still receive commands via Windower IPC.")
else
    server:listen(0)
    server:settimeout(0)
    print("FFXIDeck: Master Socket listener started on port 12345.")
end

local update_interval = 0.1
local deck_is_running = true

function ffxideck_loop()
    if not deck_is_running then return end

    -- Only the "Master" instance (the one that successfully bound the port) runs this part
    if success then
        local client = server:accept()
        if client then
            client:settimeout(2) 
            local line, err = client:receive()
            if not err and line and line ~= "" then
                -- Broadcast the command to ALL local windower instances
                windower.send_ipc_message(line)
                -- Also process it locally
                process_command(line)
            end
            client:close()
        end
    end

    coroutine.schedule(ffxideck_loop, update_interval)
end

function process_command(line)
    local sep_index = line:find("|")
    if sep_index then
        local target_name = line:sub(1, sep_index - 1)
        local command = line:sub(sep_index + 1)
        
        -- FIX: Use ffxi.get_player() as shown in your error logs
        local player = windower.ffxi.get_player()
        local my_name = player and player.name or ""

        if target_name:lower() == "all" or target_name:lower() == my_name:lower() then
            windower.send_command(command)
        end
    else
        windower.send_command(line)
    end
end

-- Listen for commands relayed from the Master instance
windower.register_event('ipc message', function(msg)
    process_command(msg)
end)

ffxideck_loop()

windower.register_event('unload', function()
    deck_is_running = false
    if success then server:close() end
end)