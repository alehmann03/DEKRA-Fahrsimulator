-- test_scenario.lua
local M = {}

local thresholdSpeed = 50 / 3.6 -- 50 km/h umgerechnet in m/s
local eventTriggered = false

-- 1. Skriptstart: Meldung im BeamNG-Kontext ausgeben
local function onExtensionLoaded()
    guihooks.trigger('Message', {
        msg = "Test-Szenario erfolgreich geladen!",
        category = "info",
        icon = "flag"
    })
end

-- Wird in jedem Frame der Game Engine aufgerufen
local function onUpdate(dt)
    -- 2. Fahrzeuggröße auslesen (Geschwindigkeit des Spielerfahrzeugs)
    local playerVehicle = be:getPlayerVehicle(0)
    if not playerVehicle then return end

    local speedMs = playerVehicle:getVelocity():length() -- m/s
    local speedKmh = math.floor(speedMs * 3.6)

    -- 3. Bedingung prüfen
    if speedMs > thresholdSpeed and not eventTriggered then
        eventTriggered = true
        
        -- 4. Ereignis auslösen (Meldung im HUD anzeigen)
        guihooks.trigger('Message', {
            msg = "Ziel erreicht! Geschwindigkeit über 50 km/h: " .. speedKmh .. " km/h",
            category = "warning",
            icon = "speed"
        })
    end
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M