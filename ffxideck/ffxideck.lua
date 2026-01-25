_addon.name = 'ffxideck'
_addon.author = 'HB'
_addon.version = '1.0'

local socket = require("socket")
local server = socket.tcp()

-- Bind settings
server:bind("127.0.0.1", 12345)
server:listen(0)
server:settimeout(0)

local update_interval = 0.1
local deck_is_running = true

print("FFXIDeck: Socket listener scheduled (Interval: " .. update_interval .. "s)")

function ffxideck_loop()
    -- Check the flag to allow stopping/unloading gracefully
    if not deck_is_running then
        return
    end

    -- Attempt to accept a connection
    local client = server:accept()
    if client then
        client:settimeout(2) 
        local line, err = client:receive()
        if not err and line and line ~= "" then
            -- Execute the command received from the C# App
            windower.send_command(line)
        end
        client:close()
    end

    -------------------------------------------------------
    -- Schedule the next run (0.1 seconds from now)
    coroutine.schedule(ffxideck_loop, update_interval)
end

-- Kick off the first run
ffxideck_loop()

-- Cleanup event to stop the loop when the addon is unloaded
windower.register_event('unload', function()
    deck_is_running = false
    server:close()
end)