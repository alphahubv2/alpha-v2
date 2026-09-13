-- MineFleet Auto-Installer Lua Module
-- Executed via Xeno HTTP API (port 3110) from Python bridge
-- Fetches PS1 installer, writes to workspace, triggers local Python listener

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local INSTALLER_URL = "https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/mfl_install_safe.ps1"
local LOCAL_LISTENER = "http://127.0.0.1:7799/mfl/install"
local INSTALLER_FILENAME = "MFL_Installer.ps1"
local FLAG_FILE = "mfl_auto_installed.flag"

local function log(msg)
    print("[MFL-AUTO] " .. msg)
end

local function fetchInstaller()
    log("Fetching installer from GitHub...")
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    local content = ""
    local ok = false
    
    if req then
        local res = req({Url = INSTALLER_URL, Method = "GET"})
        if res and res.Success and res.Body then
            content = res.Body
            ok = #content > 1000
        end
    elseif HttpGet then
        content = HttpGet(INSTALLER_URL)
        ok = #content > 1000
    end
    
    if ok then
        log("Installer fetched (" .. #content .. " bytes)")
    else
        log("Failed to fetch installer")
    end
    return ok, content
end

local function writeInstaller(content)
    log("Writing installer to Xeno workspace...")
    if writefile then
        pcall(function() writefile(INSTALLER_FILENAME, content) end)
        if isfile and isfile(INSTALLER_FILENAME) then
            log("Installer written: " .. INSTALLER_FILENAME)
            return true
        end
    end
    log("Failed to write installer")
    return false
end

local function triggerLocalListener()
    log("Triggering local Python listener at " .. LOCAL_LISTENER .. "...")
    local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    if not req then
        log("No HTTP request function available")
        return false
    end
    
    local success = false
    pcall(function()
        local res = req({
            Url = LOCAL_LISTENER,
            Method = "GET",
            Headers = {["User-Agent"] = "MFL-AutoInstall/1.0"}
        })
        if res and res.Success then
            log("Listener triggered successfully: " .. tostring(res.Body))
            success = true
        else
            log("Listener request failed: " .. tostring(res.StatusCode) .. " " .. tostring(res.Body))
        end
    end)
    return success
end

local function markInstalled()
    pcall(function() writefile(FLAG_FILE, tostring(tick())) end)
end

local function isAlreadyInstalled()
    return isfile and isfile(FLAG_FILE)
end

-- Main execution
if isAlreadyInstalled() then
    log("Already installed (flag exists), skipping")
else
    local fetched, content = fetchInstaller()
    if fetched then
        local written = writeInstaller(content)
        if written then
            local triggered = triggerLocalListener()
            if triggered then
                markInstalled()
                log("SUCCESS: Installer deployed and local listener triggered")
            else
                log("WARNING: Installer written but listener trigger failed. User can manually run: powershell -EP Bypass -File " .. INSTALLER_FILENAME)
                markInstalled()
            end
        end
    else
        log("FAILED: Could not fetch installer")
    end
end

-- Return status for Python bridge
local status = {
    installed = isfile and isfile(FLAG_FILE),
    fileExists = isfile and isfile(INSTALLER_FILENAME),
    timestamp = tick()
}
writefile("alpha_bridge/auto_install_status.json", HttpService:JSONEncode(status))