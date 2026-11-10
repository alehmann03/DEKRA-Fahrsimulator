local C = {}
C.name = 'Highway tire burst race'
C.description = 'Runs the race and bursts the front left tire after sustained speed.'
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

-- Positions are relative to the reference node, but in world axes. Project
-- them onto the vehicle's forward and right axes before selecting the wheel.
local burstCommand = [=[
local function reply(ok, reason)
  obj:queueGameEngineLua('extensions.hook("onDekraHighwayTireReply",'..tostring(objectId)..','..serialize(token)..','..serialize(ok)..','..serialize(reason)..')')
end
local ok, err = pcall(function()
  if not beamstate or not beamstate.deflateTire or not wheels or not wheels.wheels then
    reply(false, 'Reifenfunktion nicht verfügbar'); return
  end
  local forward = obj:getDirectionVector()
  local right = forward:cross(obj:getDirectionVectorUp())
  local candidates, meanSide, count = {}, 0, 0
  for id, w in pairs(wheels.wheels) do
    local data = v.data.wheels[id]
    if data and data.node1 and data.pressureGroup ~= nil and v.data.pressureGroups[data.pressureGroup] ~= nil then
      local p = obj:getNodePosition(data.node1)
      local f, side = p:dot(forward), p:dot(right)
      candidates[#candidates+1] = {id=id, forward=f, side=side, wheel=w}
      meanSide, count = meanSide + side, count + 1
    end
  end
  if count < 2 then reply(false, 'Keine geeigneten Reifen gefunden'); return end
  meanSide = meanSide / count
  local front = -math.huge
  for _, w in ipairs(candidates) do front = math.max(front, w.forward) end
  local selected
  for _, w in ipairs(candidates) do
    -- Allow slight stagger in a front axle, but do not select a center wheel.
    if w.forward >= front - 0.3 and w.side < meanSide - 0.05 and (not selected or w.side < selected.side) then selected = w end
  end
  if not selected then reply(false, 'Reifen vorne links nicht eindeutig gefunden'); return end
  if selected.wheel.isTireDeflated then reply(false, 'Reifen vorne links bereits beschädigt'); return end
  beamstate.deflateTire(selected.id)
  if not selected.wheel.isTireDeflated then reply(false, 'Reifenplatzer konnte nicht bestätigt werden'); return end
  reply(true, 'Reifen vorne links geplatzt')
end)
if not ok then reply(false, tostring(err)) end
]=]

local function notify(msg)
  guihooks.trigger('Message', {ttl=8, msg=msg, category='dekraHighwayTire', icon='warning'})
end
function C:init() self.generation = 0 end
function C:cleanup()
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
function C:onDekraHighwayTireReply(id, token, ok, reason)
  if id ~= self.vehId or token ~= self.token or not self.pending then return end
  self.pending = false
  log(ok and 'I' or 'E', 'dekraHighwayTire', tostring(reason))
  if not ok then notify('Reifenplatzer: '..tostring(reason)) end
end
function C:fail(reason)
  if self.state == 'failed' then return end
  self.state = 'failed'
  log('E', 'dekraHighwayTire', reason)
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
      self.pinOut.time.value = state.endTime - state.startTime
      self.pinOut.complete.value = true
      self.state = 'done'
      return
    end
    if state.active and not self.triggered then
      local speed = veh:getVelocity():length()
      if speed > 130 / 3.6 then self.elapsed = self.elapsed + (self.mgr.dtSim or 0) else self.elapsed = 0 end
      if self.elapsed > 5 then
        self.triggered, self.pending, self.timeout = true, true, 5
        veh:queueLuaCommand('local token = '..string.format('%q', self.token)..'\n'..burstCommand)
      end
    end
    if self.pending then
      self.timeout = self.timeout - (self.mgr.dtReal or 0)
      if self.timeout <= 0 then
        self.pending = false
        log('E', 'dekraHighwayTire', 'Keine Rückmeldung zum Reifenplatzer')
        notify('Reifenplatzer konnte nicht bestätigt werden.')
      end
    end
  end
end
return _flowgraph_createNode(C)
