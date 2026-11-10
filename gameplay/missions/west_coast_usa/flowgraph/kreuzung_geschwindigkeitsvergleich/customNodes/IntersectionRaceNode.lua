local C = {}
C.name = 'Intersection comparison race'
C.description = 'Runs the original race and starts a scripted crossing vehicle.'
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

local function notify(msg)
  guihooks.trigger('Message', {ttl=8, msg=msg, category='dekraIntersection', icon='warning'})
end
function C:init() self.generation = 0 end
function C:cleanupTraffic()
  local traffic = self.trafficId and getObjectByID(self.trafficId)
  if traffic then traffic:delete() end
  self.trafficId = nil
end
function C:cleanup()
  self:cleanupTraffic()
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
  self.trafficId, self.trafficStarted, self.warning, self.collisionStopped = nil, false, false, false
  self.pinOut.active.value, self.pinOut.complete.value = false, false
  self.vehId, self.race = nil, nil
  self.pinOut.raceData.value, self.pinOut.time.value = nil, nil
end
function C:_executionStarted() self:resetState() end
function C:_executionStopped() self:cleanup() end
function C:fail(reason)
  if self.state == 'failed' then return end
  self.state = 'failed'
  log('E', 'dekraIntersection', reason)
  notify('Kreuzungs-Herausforderung abgebrochen: '..reason)
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
      -- Initial geometry is derived from the level's decal roads and needs an in-game calibration.
      local cross = core_vehicles.spawnNewVehicle('etk800', {pos=vec3(-260.5, 620, 75.2), rot=quatFromDir(vec3(0,1,0), vec3(0,0,1)), autoEnterVehicle=false})
      if not cross then self:fail('Querverkehr konnte nicht erstellt werden'); return end
      self.trafficId = cross:getID()
      self.mgr.modules.vehicle:addVehicle(cross, {dontDelete=false})
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
    local p = veh:getPosition()
    local cross = self.trafficId and getObjectByID(self.trafficId)
    if not cross then self:fail('Querverkehr nicht verfügbar'); return end
    -- Match arrival times at constant approach speed. The 5.8 s estimate includes
    -- a provisional run-up; both geometry and acceleration require a game test.
    local speed = veh:getVelocity():length()
    local distance = p.x - (-260.5)
    local eta = speed > 3 and distance / speed or math.huge
    if state.active and not self.trafficStarted and distance > 35 and math.abs(p.y - 675) < 45 and eta <= 5.8 then
      local registered = self.mgr.modules.vehicle:getVehicle(self.trafficId)
      if not registered or not registered.ready then self:fail('Querverkehr noch nicht bereit'); return end
      local path = {}
      for i=0,12 do path[#path+1] = {x=-260.5, y=620+i*10, z=74.8, t=i*10/(40/3.6)} end
      cross:queueLuaCommand('ai.startFollowing('..serialize({path=path})..', nil, 0, "neverReset")')
      self.trafficStarted = true
      log('I','dekraIntersection',string.format('Querverkehr gestartet: Spieler %.1f %.1f; %.1f km/h', p.x,p.y,veh:getVelocity():length()*3.6))
    end
    -- Use BeamNG's vehicle-to-vehicle contact data, as in its touching node.
    local playerData = map.objects and map.objects[self.vehId]
    local trafficData = map.objects and map.objects[self.trafficId]
    local touched = (playerData and playerData.objectCollisions and playerData.objectCollisions[self.trafficId] == 1)
      or (trafficData and trafficData.objectCollisions and trafficData.objectCollisions[self.vehId] == 1)
    if self.trafficStarted and not self.collisionStopped and touched then
      self.collisionStopped = true
      -- Stop the AI, not physics: the impact and momentum remain simulated.
      cross:queueLuaCommand('ai.scriptStop(true, true)')
      log('I', 'dekraIntersection', string.format('Kontakt: Spieler %.1f km/h, Querverkehr %.1f km/h', speed*3.6, cross:getVelocity():length()*3.6))
    end
    if state.active and self.trafficStarted and not self.warning and p.x < -225 then
      self.warning = true
      notify('Achtung: Querverkehr von links!')
      local cp = cross:getPosition()
      log('I','dekraIntersection',string.format('Warnung: Spieler %.1f %.1f %.1f km/h; Querverkehr %.1f %.1f %.1f km/h', p.x,p.y,veh:getVelocity():length()*3.6,cp.x,cp.y,cross:getVelocity():length()*3.6))
    end
  end
end
return _flowgraph_createNode(C)
