_addon.name = 'ffxideck'
_addon.author = 'HB'
_addon.version = '1.3' -- Updated version

local socket = require("socket")
local server = socket.tcp()

local HELP_COLOR = 200
-- Bind settings
local success, err = server:bind("127.0.0.1", 12345)
if not success then
    windower.add_to_chat(HELP_COLOR, 'FFXIDeck: Port 12345 is busy (another instance is already listening).')
    windower.add_to_chat(HELP_COLOR, 'FFXIDeck: This instance will still receive commands via Windower IPC.')
else
    local ip, port = server:getsockname()
    windower.add_to_chat(HELP_COLOR, 'FFXIDeck: Successfully listening on '  .. tostring(ip) .. ":" .. tostring(port))
    server:listen(2)
    server:settimeout(0)
    windower.add_to_chat(HELP_COLOR, 'FFXIDeck: Master Socket listener started.')
end

local update_interval = 0.1
local deck_is_running = true

-- ECHO FIX: Unique prefix to identify messages originating from this Master
local IPC_PREFIX = "FFXIDECK_CMD:"

function ffxideck_loop()
    if not deck_is_running then return end

    if success then
        local client = server:accept()
        if client then
            client:settimeout(0.1) 
            local line, err = client:receive()
            if not err and line and line ~= "" then
                -- ECHO FIX: Broadcast with prefix so Slaves pick it up
                windower.send_ipc_message(IPC_PREFIX .. line)
               
                -- Process locally (Master executes the command once)
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
        
        local player = windower.ffxi.get_player()
        local my_name = player and player.name or ""

        if target_name:lower() == "all" or target_name:lower() == my_name:lower() then
            windower.send_command(command)
			 
        end
    else
        windower.send_command(line)
    end
end

-- ECHO FIX: Slaves listen for the prefix; Master ignores it
windower.register_event('ipc message', function(msg)
    -- Only process if it starts with our prefix AND we are NOT the Master
    if not success and msg:sub(1, #IPC_PREFIX) == IPC_PREFIX then
        local actual_command = msg:sub(#IPC_PREFIX + 1)
        process_command(actual_command)
    end
end)

ffxideck_loop()

windower.register_event('unload', function()
    deck_is_running = false
    if success then server:close() end
end)