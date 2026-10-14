-- testscenario.lua
local M = {}

local thresholdSpeed = 50 / 3.6 -- 50 km/h in m/s
local eventTriggered = false

local function onExtensionLoaded()
    eventTriggered = false
    print("=== TESTSCENARIO GELADEN ===")
    ui_message("Test-Szenario erfolgreich geladen!", 5, "info", "flag")
end

local function onUpdate(dt)
    local playerVehicle = be:getPlayerVehicle(0)
    if not playerVehicle then return end

    local speedMs = playerVehicle:getVelocity():length()
    local speedKmh = math.floor(speedMs * 3.6)

    if speedMs > thresholdSpeed and not eventTriggered then
        eventTriggered = true
        print("=== 50 KM/H ERREICHT: " .. speedKmh .. " km/h ===")
        ui_message("Ziel erreicht! Geschwindigkeit über 50 km/h: " .. speedKmh .. " km/h", 5, "warning", "speed")
    end
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M