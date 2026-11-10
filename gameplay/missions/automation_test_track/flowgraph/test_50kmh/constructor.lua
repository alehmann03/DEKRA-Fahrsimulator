-- Add the limiter to the original time-trial lifecycle; the race flowgraph is unchanged.
local serial = 0
local missionId = 'automation_test_track/flowgraph/test_50kmh'
local vehicleCode = [=[
local function reportFailure()
  local command = 'local m = gameplay_missions_missions.getMissionById('..serialize(missionId)..'); '..
    'if m and m._dekraSpeedToken == '..serialize(token)..' and gameplay_missions_missionManager.getForegroundMissionId() == '..serialize(missionId)..' then '..
    'ui_message("50-km/h-Begrenzer in diesem Fahrzeug nicht verfuegbar. Mission abgebrochen.", 10, "dekraSpeedLimit"); '..
    'gameplay_missions_missionManager.stop(m, {ignoreFade=true}) end'
  obj:queueGameEngineLua(command)
end
local function upvalue(fn, wanted)
  if not debug or not debug.getupvalue or type(fn) ~= 'function' then return false end
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return true, value end
  end
  return false
end
local ok = pcall(function()
  local c = controller and controller.mainController
  local saved = _G.dekraTest50SpeedState
  if action == 'restore' then
    if saved and saved.token == token then
      if c == saved.controller and c.setTopSpeedLimitTemporary and c.setTopSpeedLimitTemporaryActive then
        c.setTopSpeedLimitTemporary(saved.limit)
        c.setTopSpeedLimitTemporaryActive(saved.active)
      end
      _G.dekraTest50SpeedState = nil
    end
    return
  end
  if not c or type(c.setTopSpeedLimitTemporary) ~= 'function' or type(c.setTopSpeedLimitTemporaryActive) ~= 'function' then
    reportFailure(); return
  end
  if not saved or saved.token ~= token or saved.controller ~= c then
    local hasLimit, limit = upvalue(c.setTopSpeedLimitTemporary, 'topSpeedLimitTemporary')
    local hasActive, active = upvalue(c.setTopSpeedLimitTemporaryActive, 'topSpeedLimitTemporaryActive')
    if not hasLimit or not hasActive then reportFailure(); return end
    saved = {token=token, controller=c, limit=limit, active=active}
    _G.dekraTest50SpeedState = saved
  end
  local limit = 50 / 3.6
  if saved.active and type(saved.limit) == 'number' and saved.limit > 0 then limit = math.min(limit, saved.limit) end
  c.setTopSpeedLimitTemporary(limit)
  c.setTopSpeedLimitTemporaryActive(true)
end)
if not ok and action ~= 'restore' then reportFailure() end
]=]

local function send(vehicle, token, action)
  if not vehicle then return end
  local header = string.format('local missionId, token, action = %q, %q, %q\n', missionId, token, action)
  vehicle:queueLuaCommand(header .. vehicleCode)
end

local C = {
  -- flowMission:init overwrites the label from info.json, so restore it here.
  missionTypeLabel = 'DEKRA',
  defaultPreviewFile = '/gameplay/dekra/kategorie.png'
}

function C:onPreStart()
  serial = serial + 1
  self._dekraSpeedToken = tostring(serial)
  self._dekraSpeedVehicle = nil
  self._dekraSpeedClock = 0
end

function C:onUpdate(dtReal, dtSim, dtRaw)
  -- Preserve the base implementation, including script hooks and wind updates.
  local base = getmetatable(self)
  if base and base.onUpdate then base.onUpdate(self, dtReal, dtSim, dtRaw) end
  if not self._dekraSpeedToken then return end
  local vehicle = getPlayerVehicle(0)
  if vehicle and not vehicle:isReady() then vehicle = nil end
  local id = vehicle and vehicle:getID()
  if id ~= self._dekraSpeedVehicle then
    if self._dekraSpeedVehicle then send(getObjectByID(self._dekraSpeedVehicle), self._dekraSpeedToken, 'restore') end
    self._dekraSpeedVehicle = id
    self._dekraSpeedClock = 0
  end
  self._dekraSpeedClock = self._dekraSpeedClock - (dtReal or 0)
  if vehicle and self._dekraSpeedClock <= 0 then
    send(vehicle, self._dekraSpeedToken, 'apply')
    self._dekraSpeedClock = 0.25
  end
end

function C:onPostStop()
  local token = self._dekraSpeedToken
  self._dekraSpeedToken = nil
  if token and self._dekraSpeedVehicle then send(getObjectByID(self._dekraSpeedVehicle), token, 'restore') end
  self._dekraSpeedVehicle = nil
end

return function() return C end
