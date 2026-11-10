local C = {}
C.name = 'Highway brake failure race'
C.description = 'Demonstrates a sustained front left braking force after sustained speed.'
C.pinSchema = {
  {dir='in', type='flow', name='flow'},
  {dir='in', type='flow', name='reset', impulse=true},
  {dir='in', type='table', name='pathData', tableType='pathData'},
  {dir='in', type='number', name='vehId_1'},
  {dir='in', type='number', name='lapCount'},
  {dir='in', type='bool', name='rolling'},
  {dir='in', type='bool', name='autoStartAI'},
  {dir='out', type='flow', name='flow'},
  {dir='out', type='flow', name='active'},
  {dir='out', type='flow', name='complete'},
  {dir='out', type='flow', name='finished', impulse=true},
  {dir='out', type='flow', name='roundReset', impulse=true},
  {dir='out', type='table', name='raceData', tableType='raceData'},
  {dir='out', type='number', name='time'}
}

-- Fraction of the wheel's configured maximum service brake torque. Tune in-game.
local BRAKE_STRENGTH = 0.8

-- Executed in vehicle Lua. Both brake methods are wrapped so ABS mode changes
-- keep the demonstration applied. Original callbacks are retained for cleanup.
local brakeCommand = [=[
local function reply(ok, reason)
  obj:queueGameEngineLua('extensions.hook("onDekraHighwayBrakeReply",'..tostring(objectId)..','..serialize(token)..','..sequence..','..serialize(action)..','..serialize(ok)..','..serialize(reason)..')')
end
local function restore(saved)
  if not saved then return end
  local w = saved.wheel
  if w.updateBrakeNoABS == saved.noABS then w.updateBrakeNoABS = saved.originalNoABS end
  if w.updateBrakeABS == saved.abs then w.updateBrakeABS = saved.originalABS end
  if w.updateBrake == saved.noABS then w.updateBrake = saved.originalNoABS
  elseif w.updateBrake == saved.abs then w.updateBrake = saved.originalABS end
  _G.dekraHighwayBrake = nil
end
local ok, err = pcall(function()
  local saved = _G.dekraHighwayBrake
  if action == 'restore' then
    if saved and saved.token == token then restore(saved); reply(true, 'Bremsfunktionen wiederhergestellt') end
    return
  end
  if action == 'check' then
    if not saved or saved.token ~= token or not wheels.wheels or wheels.wheels[saved.id] ~= saved.wheel or
       saved.wheel.updateBrakeNoABS ~= saved.noABS or saved.wheel.updateBrakeABS ~= saved.abs or
       (saved.wheel.updateBrake ~= saved.noABS and saved.wheel.updateBrake ~= saved.abs) then
      reply(false, 'Bremswirkung unterbrochen oder Fahrzeug zurückgesetzt'); return
    end
    reply(true, 'Bremswirkung aktiv'); return
  end
  if saved then reply(false, 'Vorheriger Bremszustand noch aktiv'); return end
  if not wheels or not wheels.wheels or not v or not v.data or not v.data.wheels then
    reply(false, 'Raddaten nicht verfügbar'); return
  end
  local forward = obj:getDirectionVector()
  local right = forward:cross(obj:getDirectionVectorUp())
  local candidates, meanSide, count = {}, 0, 0
  for id, w in pairs(wheels.wheels) do
    local data = v.data.wheels[id]
    if data and data.node1 then
      local p = obj:getNodePosition(data.node1)
      local f, side = p:dot(forward), p:dot(right)
      candidates[#candidates+1] = {id=id, forward=f, side=side, wheel=w}
      meanSide, count = meanSide + side, count + 1
    end
  end
  if count < 2 then reply(false, 'Keine geeigneten Räder gefunden'); return end
  meanSide = meanSide / count
  local front = -math.huge
  for _, w in ipairs(candidates) do front = math.max(front, w.forward) end
  local selected
  for _, w in ipairs(candidates) do
    if w.forward >= front - 0.3 and w.side < meanSide - 0.05 and (not selected or w.side < selected.side) then selected = w end
  end
  if not selected then reply(false, 'Vorderrad links nicht eindeutig gefunden'); return end
  local w = selected.wheel
  if w.isBroken or type(w.brakeTorque) ~= 'number' or w.brakeTorque <= 0 or
      type(w.updateBrakeNoABS) ~= 'function' or type(w.updateBrakeABS) ~= 'function' or
      (w.updateBrake ~= w.updateBrakeNoABS and w.updateBrake ~= w.updateBrakeABS) then
    reply(false, 'Linke Vorderradbremse wird nicht unterstützt'); return
  end
  saved = {token=token, id=selected.id, wheel=w, originalNoABS=w.updateBrakeNoABS, originalABS=w.updateBrakeABS}
  local minimumTorque = w.brakeTorque * strength
  saved.noABS = function(wd, ...) return math.max(saved.originalNoABS(wd, ...), minimumTorque) end
  saved.abs = function(wd, ...) return math.max(saved.originalABS(wd, ...), minimumTorque) end
  _G.dekraHighwayBrake = saved
  local active = w.updateBrake
  w.updateBrakeNoABS, w.updateBrakeABS = saved.noABS, saved.abs
  w.updateBrake = active == saved.originalNoABS and saved.noABS or saved.abs
  reply(true, 'Bremsdefekt vorne links aktiviert')
end)
if not ok then
  if action == 'begin' and _G.dekraHighwayBrake and _G.dekraHighwayBrake.token == token then restore(_G.dekraHighwayBrake) end
  reply(false, tostring(err))
end
]=]

local function notify(msg)
  guihooks.trigger('Message', {ttl=8, msg=msg, category='dekraHighwayBrake', icon='warning'})
end
function C:init() self.generation = 0 end
function C:send(action)
  local veh = self.vehId and getObjectByID(self.vehId)
  if not veh or not self.token then return false end
  self.sequence = (self.sequence or 0) + 1
  local header = string.format('local token, sequence, action, strength = %q, %d, %q, %.3f\n', self.token, self.sequence, action, BRAKE_STRENGTH)
  veh:queueLuaCommand(header .. brakeCommand)
  if action ~= 'restore' then self.pending, self.timeout = action, 5 end
  return true
end
function C:restoreBrake()
  if self.triggered then self:send('restore') end
  self.pending = false
end
function C:cleanup()
  self:restoreBrake()
  if self.race then self.race:stopRace(); self.race = nil end
  local veh = self.vehId and getObjectByID(self.vehId)
  if veh and self.frozen then core_vehicleBridge.executeAction(veh, 'setFreeze', false) end
  self.frozen = false
  self.token = nil
end
function C:resetState()
  self.generation = self.generation + 1
  self.token = tostring(self.mgr.id)..':'..tostring(self.id)..':'..tostring(self.generation)
  self.state, self.elapsed, self.triggered = 'init', 0, false
  self.pending, self.frozen = false, false
  self.pinOut.active.value, self.pinOut.complete.value = false, false
  self.vehId, self.race = nil, nil
  self.pinOut.raceData.value, self.pinOut.time.value = nil, nil
end
function C:_executionStarted() self:resetState() end
function C:_executionStopped() self:cleanup() end
function C:onDekraHighwayBrakeReply(id, token, sequence, action, ok, reason)
  if id ~= self.vehId or token ~= self.token or sequence ~= self.sequence or self.pending ~= action then return end
  self.pending = false
  if not ok then self:fail('Bremsdefekt: '..tostring(reason)); return end
  if action == 'begin' then
    log('I', 'dekraHighwayBrake', tostring(reason))
    notify('Demonstration: Bremse vorne links blockiert.')
  end
end

function C:fail(reason)
  if self.state == 'failed' then return end
  self.state = 'failed'
  log('E', 'dekraHighwayBrake', reason)
  notify('Highway-Herausforderung abgebrochen: '..reason)
  self:cleanup()
  gameplay_missions_missionManager.stop(self.mgr.activity, {ignoreFade=true})
end
function C:work()
  self.pinOut.finished.value, self.pinOut.roundReset.value = false, false
  self.pinOut.flow.value = self.pinIn.flow.value
  if self.pinIn.reset.value then self:cleanup(); self:resetState() end
  if not self.pinIn.flow.value then return end
  if self.state == 'init' then
    local veh = getPlayerVehicle(0)
    if not veh or veh:getID() ~= self.pinIn.vehId_1.value then self:fail('Spielerfahrzeug nicht verfügbar'); return end
    if not self.pinIn.pathData.value then self:fail('Strecke nicht verfügbar'); return end
    self.vehId = veh:getID()
    core_vehicleBridge.executeAction(veh, 'setFreeze', true)
    self.frozen = true
    self.countdown = core_flowgraphManager.skipCountdowns and 0 or 3
    self.lastCountdown = 4
    self.state = 'countdown'
  end
  if self.state == 'failed' or self.state == 'done' then return end
  local veh, player = getObjectByID(self.vehId), getPlayerVehicle(0)
  if not veh or not player or player:getID() ~= self.vehId then self:fail('Fahrzeug gewechselt oder verloren'); return end
  if self.state == 'countdown' then
    local n = math.ceil(self.countdown)
    if n > 0 and n ~= self.lastCountdown then
      guihooks.trigger('ScenarioFlashMessage', {{tostring(n), 0.95, "Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown1')", true}})
      self.lastCountdown = n
    end
    self.countdown = self.countdown - (self.mgr.dtSim or 0)
    if self.countdown <= 0 then
      self.race = require('/lua/ge/extensions/gameplay/race/race')()
      self.race:setPath(self.pinIn.pathData.value)
      self.race.path.config.rollingStart = false
      self.race.lapCount = 1
      self.race.autoAiMode = false
      self.race.useHotlappingApp = true
      self.race.useDebugDraw = false
      self.race.useWaypointAudio = true
      if self.mgr.activity then self.race.saveFileSuffix = self.mgr.activity.id end
      self.race:setVehicleIds({self.vehId})
      self.race:startRace()
      core_vehicleBridge.executeAction(veh, 'setFreeze', false)
      self.frozen = false
      guihooks.trigger('ScenarioFlashMessage', {{'ui.scenarios.go', 1, "Engine.Audio.playOnce('AudioGui', 'event:UI_CountdownGo')", true}})
      self.pinOut.finished.value = true
      self.state = 'racing'
    end
  elseif self.state == 'racing' then
    self.race:onUpdate(self.mgr.dtSim)
    local state = self.race.states[self.vehId]
    if not state then self:fail('Rennzustand verloren'); return end
    self.pinOut.raceData.value = self.race
    self.pinOut.active.value = state.active
    if state.complete then
      self:restoreBrake()
      self.pinOut.time.value = state.endTime - state.startTime
      self.pinOut.complete.value = true
      self.state = 'done'
      return
    end
    if state.active and not self.triggered then
      local speed = veh:getVelocity():length()
      if speed > 130 / 3.6 then self.elapsed = self.elapsed + (self.mgr.dtSim or 0) else self.elapsed = 0 end
      if self.elapsed > 5 then
        self.triggered = true
        self.checkClock = 1
        if not self:send('begin') then self:fail('Fahrzeug nicht verfügbar'); return end
      end
    end
    if self.pending then
      self.timeout = self.timeout - (self.mgr.dtReal or 0)
      if self.timeout <= 0 then self:fail('Keine Rückmeldung zur Bremswirkung'); return end
    elseif self.triggered then
      self.checkClock = self.checkClock - (self.mgr.dtReal or 0)
      if self.checkClock <= 0 then
        self.checkClock = 1
        if not self:send('check') then self:fail('Fahrzeug nicht verfügbar'); return end
      end
    end
  end
end
return _flowgraph_createNode(C)
