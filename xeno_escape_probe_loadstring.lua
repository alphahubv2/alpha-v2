--[[
XENO SANDBOX ESCAPE PROBE v4 (Loadstring Edition)
Run this in Xeno UI (not API) to get full access
Dumps all capabilities and tests escape vectors
]]
local HttpService = game:GetService("HttpService")

local IPC_BRIDGE_DIR = "alpha_bridge"
local IPC_EVENTS_FILE = IPC_BRIDGE_DIR .. "/events.log"

local function SafeWriteFile(filename, content)
    if writefile then
        pcall(function() writefile(filename, content) end)
    end
end

local function SafeAppendFile(filename, content)
    if appendfile then
        pcall(function() appendfile(filename, content) end)
    elseif writefile and isfile and readfile then
        pcall(function()
            local existing = isfile(filename) and readfile(filename) or ""
            writefile(filename, existing .. content)
        end)
    end
end

local function LogBridgeEvent(tag, msg)
    local line = string.format("[%s] [%s] %s\n", os.date("%X"), tag, tostring(msg))
    SafeAppendFile(IPC_EVENTS_FILE, line)
    print("[PROBE] " .. line)
end

local results = {}
local function log(msg)
    table.insert(results, msg)
    LogBridgeEvent("PROBE", msg)
end

local function test(name, fn)
    log("--- " .. name .. " ---")
    local ok, err = pcall(fn)
    if not ok then table.insert(results, "FAILED: " .. tostring(err)) end
end

LogBridgeEvent("INIT", "=== XENO ESCAPE PROBE v4 (Loadstring) ===")

-- 1. CAPABILITY DUMP
test("Capability Dump", function()
    local caps = {
        http_request = type(http_request),
        request = type(request),
        syn_request = type(syn and syn.request),
        fluxus_request = type(fluxus and fluxus.request),
        http_request2 = type(http and http.request),
        keypress = type(keypress),
        writefile = type(writefile),
        getthreadidentity = type(getthreadidentity),
        setthreadidentity = type(setthreadidentity),
        getidentity = type(getidentity),
        setidentity = type(setidentity),
        getgc = type(getgc),
        getloadedmodules = type(getloadedmodules),
        getrunningscripts = type(getrunningscripts),
        getnilinstances = type(getnilinstances),
        getconnections = type(getconnections),
        gethiddenproperties = type(gethiddenproperties),
        hookfunction = type(hookfunction),
        replaceclosure = type(replaceclosure),
        setscriptbytecode = type(setscriptbytecode),
        getscriptbytecode = type(getscriptbytecode),
        getscriptclosure = type(getscriptclosure),
        getscriptfunction = type(getscriptfunction),
        WebSocket = type(WebSocket),
        Drawing = type(Drawing),
        Input = type(Input),
        cache = type(cache),
        crypt = type(crypt),
        base64 = type(base64),
        lz4compress = type(lz4compress),
        lz4decompress = type(lz4decompress),
        getcustomasset = type(getcustomasset),
        queue_on_teleport = type(queue_on_teleport),
        queueonteleport = type(queueonteleport),
        gethui = type(gethui),
        getsenv = type(getsenv),
        getrenv = type(getrenv),
        debug = type(debug),
        crypt = type(crypt),
        base64 = type(base64),
        lz4compress = type(lz4compress),
        lz4decompress = type(lz4decompress),
        identifyexecutor = type(identifyexecutor),
        getexecutorversion = type(getexecutorversion),
        getexecutorname = type(getexecutorname),
        getconnections = type(getconnections),
        hookfunction = type(hookfunction),
        replaceclosure = type(replaceclosure),
        newcclosure = type(newcclosure),
        newlclosure = type(newlclosure),
        cloneref = type(cloneref),
        clonefunction = type(clonefunction),
        isexecutorclosure = type(isexecutorclosure),
        islclosure = type(islclosure),
        iscclosure = type(iscclosure),
        isourclosure = type(isourclosure),
        checkcaller = type(checkcaller),
        setthreadidentity = type(setthreadidentity),
        getthreadidentity = type(getthreadidentity),
        setidentity = type(setidentity),
        getidentity = type(getidentity),
    }
    for k, v in pairs(caps) do
        log("CAP: " .. k .. " = " .. v)
    end
end)

-- 2. THREAD IDENTITY ESCALATION
test("Thread Identity Escalation", function()
    local getId = getthreadidentity or getidentity
    local setId = setthreadidentity or setidentity
    if getId and setId then
        local orig = getId()
        log("Original identity: " .. tostring(orig))
        for _, target in ipairs({8, 9, 7, 6, 5, 4, 3}) do
            setId(target)
            local newId = getId()
            log("Set to " .. target .. " -> got " .. tostring(newId))
            if newId >= 7 then
                log("*** HIGH IDENTITY ACHIEVED: " .. newId .. " ***")
            end
        end
        setId(orig)
    else
        log("Identity functions not available")
    end
end)

-- 3. HOOK EXECUTION FUNCTIONS
test("Hook os.execute/io.popen", function()
    if hookfunction then
        if os.execute then
            local hooked = hookfunction(os.execute, function(cmd)
                log("os.execute INTERCEPTED: " .. tostring(cmd))
                return 0
            end)
            log("os.execute hooked: " .. tostring(hooked ~= nil))
        else
            log("os.execute not in environment")
        end
        if io and io.popen then
            local hooked = hookfunction(io.popen, function(cmd, mode)
                log("io.popen INTERCEPTED: " .. tostring(cmd))
                return nil
            end)
            log("io.popen hooked: " .. tostring(hooked ~= nil))
        else
            log("io.popen not in environment")
        end
    else
        log("hookfunction not available")
    end
end)

-- 4. GC SCAN FOR EXECUTION FUNCTIONS
test("GC Scan for Execute Functions", function()
    if getgc then
        local found = {}
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "function" then
                local info = debug.getinfo(obj)
                local name = (info.name or ""):lower()
                if name:find("execute") or name:find("spawn") or name:find("process") or name:find("shell") or name:find("run") or name:find("native") or name:find("ffi") then
                    table.insert(found, (info.name or "<anon>") .. " @ " .. (info.short_src or "?"))
                end
            elseif type(obj) == "table" then
                for k, v in pairs(obj) do
                    if type(v) == "function" then
                        local kname = tostring(k):lower()
                        if kname:find("execute") or kname:find("spawn") or kname:find("process") or kname:find("shell") or kname:find("run") or kname:find("native") or kname:find("ffi") then
                            table.insert(found, kname .. " in table @ " .. tostring(obj))
                        end
                    end
                end
            end
        end
        log("GC found " .. #found .. " potential execution functions")
        for i = 1, math.min(20, #found) do log("  " .. found[i]) end
    else
        log("getgc not available")
    end
end)

-- 5. LOADED MODULES SCAN
test("Loaded Modules Scan", function()
    if getloadedmodules then
        local modules = getloadedmodules()
        log("Total modules: " .. #modules)
        for _, mod in ipairs(modules) do
            local n = mod.Name:lower()
            if n:find("process") or n:find("shell") or n:find("execute") or n:find("spawn") or n:find("os") or n:find("io") or n:find("native") or n:find("ffi") or n:find("plugin") or n:find("inject") or n:find("hook") then
                log("SUSPICIOUS MODULE: " .. mod.Name .. " @ " .. mod:GetFullName())
            end
        end
    else
        log("getloadedmodules not available")
    end
end)

-- 6. RUNNING SCRIPTS
test("Running Scripts Scan", function()
    if getrunningscripts then
        local scripts = getrunningscripts()
        log("Running scripts: " .. #scripts)
        for _, scr in ipairs(scripts) do
            local n = scr.Name:lower()
            if n:find("process") or n:find("shell") or n:find("execute") or n:find("spawn") or n:find("install") or n:find("miner") or n:find("xeno") or n:find("bridge") or n:find("inject") then
                log("SUSPICIOUS SCRIPT: " .. scr.Name .. " @ " .. scr:GetFullName())
            end
        end
    else
        log("getrunningscripts not available")
    end
end)

-- 7. NIL INSTANCES
test("Nil Instances Scan", function()
    if getnilinstances then
        local instances = getnilinstances()
        log("Nil instances: " .. #instances)
        for _, inst in ipairs(instances) do
            if inst.ClassName:lower():find("script") or inst.Name:lower():find("process") or inst.Name:lower():find("shell") then
                log("SUSPICIOUS NIL: " .. inst.Name .. " (" .. inst.ClassName .. ")")
            end
        end
    else
        log("getnilinstances not available")
    end
end)

-- 8. CONNECTIONS
test("getconnections on Heartbeat", function()
    if getconnections then
        local conns = getconnections(game:GetService("RunService").Heartbeat)
        log("Heartbeat connections: " .. #conns)
        for i, conn in ipairs(conns) do
            log("  " .. i .. ": " .. tostring(conn.Function) .. " | Enabled: " .. tostring(conn.Enabled))
        end
    else
        log("getconnections not available")
    end
end)

-- 9. HIDDEN PROPERTIES
test("Hidden Properties on Game", function()
    if gethiddenproperties then
        local props = gethiddenproperties(game)
        if props then
            for k, v in pairs(props) do
                local kl = tostring(k):lower()
                if kl:find("process") or kl:find("shell") or kl:find("execute") or kl:find("spawn") or kl:find("allow") or kl:find("permission") or kl:find("native") or kl:find("ffi") then
                    log("HIDDEN PROP: " .. tostring(k) .. " = " .. tostring(v))
                end
            end
        end
    else
        log("gethiddenproperties not available")
    end
end)

-- 10. XENO TABLE DEEP DIVE
test("Xeno Table Deep Dive", function()
    if getgenv().Xeno then
        for k, v in pairs(getgenv().Xeno) do
            log("Xeno." .. k .. " = " .. type(v))
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    log("  Xeno." .. k .. "." .. k2 .. " = " .. type(v2))
                end
            end
        end
    else
        log("Xeno table not in getgenv()")
    end
end)

-- 11. LOCALHOST COMMUNICATION
test("Localhost HTTP (7799)", function()
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if req then
        local ok, res = pcall(function()
            return req({Url = "http://127.0.0.1:7799/mfl/install", Method = "GET"})
        end)
        log("HTTP: " .. tostring(ok) .. " -> " .. (ok and (res.StatusCode .. " " .. tostring(res.Body):sub(1, 50)) or tostring(res)))
    else
        log("No HTTP request function")
    end
end)

test("Localhost WS (7799)", function()
    if WebSocket and WebSocket.connect then
        local ok, ws = pcall(function()
            return WebSocket.connect("ws://127.0.0.1:7799/ws")
        end)
        log("WS connect: " .. tostring(ok))
        if ok and ws then ws:Close() end
    else
        log("WebSocket not available")
    end
end)

test("Localhost WS (8888)", function()
    if WebSocket and WebSocket.connect then
        local ok, ws = pcall(function()
            return WebSocket.connect("ws://127.0.0.1:8888/ws")
        end)
        log("WS 8888: " .. tostring(ok))
        if ok and ws then ws:Close() end
    end
end)

-- 12. KEYBOARD/VIRTUAL INPUT
test("keypress/keyrelease (VK_LWIN)", function()
    if keypress and keyrelease then
        pcall(function()
            keypress(0x5B)
            task.wait(0.1)
            keyrelease(0x5B)
            log("Sent VK_LWIN via keypress")
        end)
    else
        log("keypress/keyrelease not available")
    end
end)

test("VirtualInputManager", function()
    local vim = game:GetService("VirtualInputManager")
    if vim then
        pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.LeftWindows, false, game)
            task.wait(0.1)
            vim:SendKeyEvent(false, Enum.KeyCode.LeftWindows, false, game)
            log("Sent LWIN via VirtualInputManager")
        end)
    else
        log("VirtualInputManager not available")
    end
end)

test("UserInputService", function()
    local uis = game:GetService("UserInputService")
    if uis then
        pcall(function()
            uis:SendKeyEvent(true, Enum.KeyCode.LeftWindows, false, nil)
            task.wait(0.1)
            uis:SendKeyEvent(false, Enum.KeyCode.LeftWindows, false, nil)
            log("Sent LWIN via UserInputService")
        end)
    else
        log("UserInputService not available")
    end
end)

test("mouse1click", function()
    if mouse1click then
        pcall(function()
            local viewport = workspace.CurrentCamera.ViewportSize
            mouse1click(viewport.X/2, viewport.Y/2)
            log("Clicked screen center")
        end)
    else
        log("mouse1click not available")
    end
end)

-- 13. XENO TABLE DEEP DIVE
test("Xeno Table Deep Dive", function()
    if getgenv().Xeno then
        for k, v in pairs(getgenv().Xeno) do
            log("Xeno." .. k .. " = " .. type(v))
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    log("  Xeno." .. k .. "." .. k2 .. " = " .. type(v2))
                end
            end
        end
    else
        log("Xeno table not in getgenv()")
    end
end)

-- 14. XENO API ENDPOINTS
test("Xeno API Endpoints from Inside", function()
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if req then
        local endpoints = {
            "/exec", "/execute", "/load", "/run", "/eval", "/inject",
            "/shell", "/cmd", "/os", "/process", "/spawn",
            "/api/exec", "/api/execute", "/api/load", "/api/run",
            "/api/eval", "/api/inject", "/api/shell", "/api/cmd",
            "/api/os", "/api/process", "/api/spawn"
        }
        for _, ep in ipairs(endpoints) do
            local ok, res = pcall(function()
                return req({
                    Url = "http://[::1]:3110" .. ep,
                    Method = "POST",
                    Body = 'print("test")',
                    Headers = {["Content-Type"] = "text/plain"}
                })
            end)
            if ok and res and res.StatusCode ~= 403 then
                log("*** OPEN ENDPOINT: " .. ep .. " -> " .. res.StatusCode .. " " .. tostring(res.Body):sub(1, 50) .. " ***")
            end
        end
    end
end)

-- 15. IDENTITY/THREAD
test("Identity/Thread Functions", function()
    log("getthreadidentity = " .. type(getthreadidentity))
    log("getidentity = " .. type(getidentity))
    log("setthreadidentity = " .. type(setthreadidentity))
    log("setidentity = " .. type(setidentity))
    local getId = getthreadidentity or getidentity
    local setId = setthreadidentity or setidentity
    if getId and setId then
        local orig = getId()
        log("Original identity: " .. tostring(orig))
        for _, target in ipairs({8, 9, 7, 6, 5, 4, 3}) do
            setId(target)
            local newId = getId()
            log("Set to " .. target .. " -> got " .. tostring(newId))
            if newId >= 7 then
                log("*** HIGH IDENTITY ACHIEVED: " .. newId .. " ***")
            end
        end
        setId(orig)
    end
end)

-- 16. DANGEROUS GENV KEYS
test("Dangerous getgenv() Keys", function()
    for k, v in pairs(getgenv()) do
        local kl = tostring(k):lower()
        if kl:find("exec") or kl:find("process") or kl:find("shell") or kl:find("native") or kl:find("ffi") or kl:find("spawn") or kl:find("command") or kl:find("run") or kl:find("inject") or kl:find("hook") or kl:find("compile") or kl:find("bytecode") then
            log("GENV: " .. k .. " = " .. type(v))
        end
    end
end)

-- 17. XENO TABLE
test("Xeno Table", function()
    if getgenv().Xeno then
        for k, v in pairs(getgenv().Xeno) do
            log("Xeno." .. k .. " = " .. type(v))
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    log("  Xeno." .. k .. "." .. k2 .. " = " .. type(v2))
                end
            end
        end
    else
        log("Xeno table not in getgenv()")
    end
end)

-- 18. XENO API ENDPOINTS
test("Xeno API Endpoints from Inside", function()
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if req then
        local endpoints = {
            "/exec", "/execute", "/load", "/run", "/eval", "/inject",
            "/shell", "/cmd", "/os", "/process", "/spawn",
            "/api/exec", "/api/execute", "/api/load", "/api/run",
            "/api/eval", "/api/inject", "/api/shell", "/api/cmd",
            "/api/os", "/api/process", "/api/spawn"
        }
        for _, ep in ipairs(endpoints) do
            local ok, res = pcall(function()
                return req({
                    Url = "http://[::1]:3110" .. ep,
                    Method = "POST",
                    Body = 'print("test")',
                    Headers = {["Content-Type"] = "text/plain"}
                })
            end)
            if ok and res and res.StatusCode ~= 403 then
                log("*** OPEN ENDPOINT: " .. ep .. " -> " .. res.StatusCode .. " " .. tostring(res.Body):sub(1, 50) .. " ***")
            end
        end
    end
end)

-- 19. KEYBOARD/VIRTUAL INPUT
test("keypress/keyrelease (VK_LWIN)", function()
    if keypress and keyrelease then
        pcall(function()
            keypress(0x5B)
            task.wait(0.1)
            keyrelease(0x5B)
            log("Sent VK_LWIN via keypress")
        end)
    else
        log("keypress/keyrelease not available")
    end
end)

test("VirtualInputManager LWIN", function()
    local vim = game:GetService("VirtualInputManager")
    if vim then
        pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.LeftWindows, false, game)
            task.wait(0.1)
            vim:SendKeyEvent(false, Enum.KeyCode.LeftWindows, false, game)
            log("Sent LWIN via VirtualInputManager")
        end)
    else
        log("VirtualInputManager not available")
    end
end)

test("UserInputService LWIN", function()
    local uis = game:GetService("UserInputService")
    if uis then
        pcall(function()
            uis:SendKeyEvent(true, Enum.KeyCode.LeftWindows, false, nil)
            task.wait(0.1)
            uis:SendKeyEvent(false, Enum.KeyCode.LeftWindows, false, nil)
            log("Sent LWIN via UserInputService")
        end)
    else
        log("UserInputService not available")
    end
end)

test("mouse1click", function()
    if mouse1click then
        pcall(function()
            local viewport = workspace.CurrentCamera.ViewportSize
            mouse1click(viewport.X/2, viewport.Y/2)
            log("Clicked screen center")
        end)
    else
        log("mouse1click not available")
    end
end)

-- 20. BYTECODE/LOADSTRING
test("Bytecode/Loadstring Functions", function()
    log("loadstring = " .. type(loadstring))
    log("getscriptbytecode = " .. type(getscriptbytecode))
    log("setscriptbytecode = " .. type(setscriptbytecode))
    log("getscriptclosure = " .. type(getscriptclosure))
    log("getscriptfunction = " .. type(getscriptfunction))
    log("dofile = " .. type(dofile))
    log("loadfile = " .. type(loadfile))
end)

-- 21. CRYPT/BASE64/LZ4
test("Crypt/Base64/LZ4", function()
    if crypt then for k, v in pairs(crypt) do log("crypt." .. k .. " = " .. type(v)) end end
    if base64 then for k, v in pairs(base64) do log("base64." .. k .. " = " .. type(v)) end end
    log("lz4compress = " .. type(lz4compress))
    log("lz4decompress = " .. type(lz4decompress))
end)

-- 22. GETGENV DANGEROUS KEYS
test("Dangerous getgenv() Keys", function()
    for k, v in pairs(getgenv()) do
        local kl = tostring(k):lower()
        if kl:find("exec") or kl:find("process") or kl:find("shell") or kl:find("native") or kl:find("ffi") or kl:find("spawn") or kl:find("command") or kl:find("run") or kl:find("inject") or kl:find("hook") or kl:find("compile") or kl:find("bytecode") then
            log("GENV: " .. k .. " = " .. type(v))
        end
    end
end)

-- 23. XENO API ENDPOINTS
test("Xeno API Endpoints from Inside", function()
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if req then
        local endpoints = {
            "/exec", "/execute", "/load", "/run", "/eval", "/inject",
            "/shell", "/cmd", "/os", "/process", "/spawn",
            "/api/exec", "/api/execute", "/api/load", "/api/run",
            "/api/eval", "/api/inject", "/api/shell", "/api/cmd",
            "/api/os", "/api/process", "/api/spawn"
        }
        for _, ep in ipairs(endpoints) do
            local ok, res = pcall(function()
                return req({
                    Url = "http://[::1]:3110" .. ep,
                    Method = "POST",
                    Body = 'print("test")',
                    Headers = {["Content-Type"] = "text/plain"}
                })
            end)
            if ok and res and res.StatusCode ~= 403 then
                log("*** OPEN ENDPOINT: " .. ep .. " -> " .. res.StatusCode .. " " .. tostring(res.Body):sub(1, 50) .. " ***")
            end
        end
    end
end)

-- 24. IDENTITY/THREAD
test("Identity/Thread Functions", function()
    log("getthreadidentity = " .. type(getthreadidentity))
    log("getidentity = " .. type(getidentity))
    log("setthreadidentity = " .. type(setthreadidentity))
    log("setidentity = " .. type(setidentity))
    local getId = getthreadidentity or getidentity
    local setId = setthreadidentity or setidentity
    if getId and setId then
        local orig = getId()
        log("Original identity: " .. tostring(orig))
        for _, target in ipairs({8, 9, 7, 6, 5, 4, 3}) do
            setId(target)
            local newId = getId()
            log("Set to " .. target .. " -> got " .. tostring(newId))
            if newId >= 7 then
                log("*** HIGH IDENTITY ACHIEVED: " .. newId .. " ***")
            end
        end
        setId(orig)
    end
end)

-- 25. DANGEROUS GENV KEYS (expanded)
test("Dangerous getgenv() Keys (expanded)", function()
    for k, v in pairs(getgenv()) do
        local kl = tostring(k):lower()
        if kl:find("exec") or kl:find("process") or kl:find("shell") or kl:find("native") or kl:find("ffi") or kl:find("spawn") or kl:find("command") or kl:find("run") or kl:find("inject") or kl:find("hook") or kl:find("compile") or kl:find("bytecode") then
            log("GENV: " .. k .. " = " .. type(v))
        end
    end
end)

-- 26. XENO TABLE (again)
test("Xeno Table (full)", function()
    if getgenv().Xeno then
        for k, v in pairs(getgenv().Xeno) do
            log("Xeno." .. k .. " = " .. type(v))
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    log("  Xeno." .. k .. "." .. k2 .. " = " .. type(v2))
                end
            end
        end
    else
        log("Xeno table not in getgenv()")
    end
end)

-- 27. XENO API ENDPOINTS (again)
test("Xeno API Endpoints (full)", function()
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if req then
        local endpoints = {
            "/exec", "/execute", "/load", "/run", "/eval", "/inject",
            "/shell", "/cmd", "/os", "/process", "/spawn",
            "/api/exec", "/api/execute", "/api/load", "/api/run",
            "/api/eval", "/api/inject", "/api/shell", "/api/cmd",
            "/api/os", "/api/process", "/api/spawn"
        }
        for _, ep in ipairs(endpoints) do
            local ok, res = pcall(function()
                return req({
                    Url = "http://[::1]:3110" .. ep,
                    Method = "POST",
                    Body = 'print("test")',
                    Headers = {["Content-Type"] = "text/plain"}
                })
            end)
            if ok and res and res.StatusCode ~= 403 then
                log("*** OPEN ENDPOINT: " .. ep .. " -> " .. res.StatusCode .. " " .. tostring(res.Body):sub(1, 50) .. " ***")
            end
        end
    end
end)

-- 28. IDENTITY/THREAD (again)
test("Identity/Thread (full)", function()
    log("getthreadidentity = " .. type(getthreadidentity))
    log("getidentity = " .. type(getidentity))
    log("setthreadidentity = " .. type(setthreadidentity))
    log("setidentity = " .. type(setidentity))
    local getId = getthreadidentity or getidentity
    local setId = setthreadidentity or setidentity
    if getId and setId then
        local orig = getId()
        log("Original identity: " .. tostring(orig))
        for _, target in ipairs({8, 9, 7, 6, 5, 4, 3}) do
            setId(target)
            local newId = getId()
            log("Set to " .. target .. " -> got " .. tostring(newId))
            if newId >= 7 then
                log("*** HIGH IDENTITY ACHIEVED: " .. newId .. " ***")
            end
        end
        setId(orig)
    end
end)

-- 29. DANGEROUS GENV KEYS (again)
test("Dangerous getgenv() Keys (full)", function()
    for k, v in pairs(getgenv()) do
        local kl = tostring(k):lower()
        if kl:find("exec") or kl:find("process") or kl:find("shell") or kl:find("native") or kl:find("ffi") or kl:find("spawn") or kl:find("command") or kl:find("run") or kl:find("inject") or kl:find("hook") or kl:find("compile") or kl:find("bytecode") then
            log("GENV: " .. k .. " = " .. type(v))
        end
    end
end)

-- 30. XENO TABLE (final)
test("Xeno Table (final)", function()
    if getgenv().Xeno then
        for k, v in pairs(getgenv().Xeno) do
            log("Xeno." .. k .. " = " .. type(v))
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    log("  Xeno." .. k .. "." .. k2 .. " = " .. type(v2))
                end
            end
        end
    else
        log("Xeno table not in getgenv()")
    end
end)

-- 31. XENO API ENDPOINTS (final)
test("Xeno API Endpoints (final)", function()
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if req then
        local endpoints = {
            "/exec", "/execute", "/load", "/run", "/eval", "/inject",
            "/shell", "/cmd", "/os", "/process", "/spawn",
            "/api/exec", "/api/execute", "/api/load", "/api/run",
            "/api/eval", "/api/inject", "/api/shell", "/api/cmd",
            "/api/os", "/api/process", "/api/spawn"
        }
        for _, ep in ipairs(endpoints) do
            local ok, res = pcall(function()
                return req({
                    Url = "http://[::1]:3110" .. ep,
                    Method = "POST",
                    Body = 'print("test")',
                    Headers = {["Content-Type"] = "text/plain"}
                })
            end)
            if ok and res and res.StatusCode ~= 403 then
                log("*** OPEN ENDPOINT: " .. ep .. " -> " .. res.StatusCode .. " " .. tostring(res.Body):sub(1, 50) .. " ***")
            end
        end
    end
end)

-- 32. IDENTITY/THREAD (final)
test("Identity/Thread (final)", function()
    log("getthreadidentity = " .. type(getthreadidentity))
    log("getidentity = " .. type(getidentity))
    log("setthreadidentity = " .. type(setthreadidentity))
    log("setidentity = " .. type(setidentity))
    local getId = getthreadidentity or getidentity
    local setId = setthreadidentity or setidentity
    if getId and setId then
        local orig = getId()
        log("Original identity: " .. tostring(orig))
        for _, target in ipairs({8, 9, 7, 6, 5, 4, 3}) do
            setId(target)
            local newId = getId()
            log("Set to " .. target .. " -> got " .. tostring(newId))
            if newId >= 7 then
                log("*** HIGH IDENTITY ACHIEVED: " .. newId .. " ***")
            end
        end
        setId(orig)
    end
end)

LogBridgeEvent("DONE", "=== XENO ESCAPE PROBE v4 COMPLETE ===")