-- Two standing-start runs using the standard BeamNG race implementation.
local C = {}
C.name = 'ABS comparison race'
C.description = 'Runs the same path twice and waits for vehicle-side ABS confirmation.'
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

-- Runs entirely inside the target vehicle.  The reply identifies both the node
-- session and request, so late replies cannot advance a restarted mission.
local vehicleCommand = [=[
local function reply(ok, reason)
  obj:queueGameEngineLua('extensions.hook("onDekraAbsReply",'..tostring(objectId)..','..serialize(token)..','..sequence..','..serialize(ok)..','..serialize(reason)..')')
end
local function mode()
  if not debug or not debug.getupvalue or not wheels or not wheels.setABSBehavior then return nil end
  for i=1,100 do
    local n,v = debug.getupvalue(wheels.setABSBehavior,i)
    if not n then break end
    if n == 'absBehavior' then return v end
  end
end
local function verify(expected)
  if mode() ~= expected then return false end
  for i=0,wheels.wheelRotatorCount-1 do
    local w=wheels.wheelRotators[i]
    local expectedMethod=(w.hasABS and expected ~= 'off') or expected == 'arcade'
    if w.updateBrake ~= (expectedMethod and w.updateBrakeABS or w.updateBrakeNoABS) then return false end
  end
  return true
end
local function knownBrakeMethod(fn)
  if type(fn) ~= 'function' or not debug or not debug.getinfo then return false end
  local info = debug.getinfo(fn, 'S')
  local source = info and info.source and info.source:gsub('\\', '/') or ''
  return source:match('/vehicle/wheels%.lua$') ~= nil or
    source:match('/drivingDynamics/supervisors/components/brakeControl%.lua$') ~= nil
end
local ok, err = pcall(function()
  if action == 'begin' then
    local original=mode()
    if original ~= 'realistic' and original ~= 'off' and original ~= 'arcade' then reply(false,'ABS-Ausgangszustand nicht lesbar'); return end
    local count=0
    for i=0,wheels.wheelRotatorCount-1 do
      local w=wheels.wheelRotators[i]
      if w.hasABS then
        count=count+1
        if not knownBrakeMethod(w.updateBrakeABS) or not knownBrakeMethod(w.updateBrakeNoABS) then
          reply(false,'Fahrzeug-Bremscontroller wird nicht unterstützt'); return
        end
      end
    end
    if count == 0 then reply(false,'Fahrzeug besitzt kein unterstütztes Rad-ABS'); return end
    _G.dekraAbsComparison = {token=token, original=original}
    wheels.setABSBehavior('realistic')
    reply(verify('realistic'), 'ABS aktiviert: Prüfung fehlgeschlagen')
  elseif action == 'off' then
    if not _G.dekraAbsComparison or _G.dekraAbsComparison.token ~= token then reply(false,'Fahrzeugzustand verloren'); return end
    wheels.setABSBehavior('off')
    reply(verify('off'), 'ABS deaktiviert: Prüfung fehlgeschlagen')
  elseif action == 'checkOn' or action == 'checkOff' then
    local expected = action == 'checkOn' and 'realistic' or 'off'
    reply(verify(expected), 'ABS-Zustand während der Fahrt verändert')
  elseif action == 'restore' then
    local saved=_G.dekraAbsComparison
    if not saved or saved.token ~= token then reply(false,'ABS-Ausgangszustand nicht mehr verfügbar'); return end
    wheels.setABSBehavior(saved.original)
    local restored=verify(saved.original)
    if restored then _G.dekraAbsComparison=nil end
    reply(restored, 'ABS-Ausgangszustand konnte nicht wiederhergestellt werden')
  end
end)
if not ok then reply(false, tostring(err)) end
]=]

local function message(text, duration)
  guihooks.trigger('Message', {ttl=duration or 8, msg=text, category='dekraAbsVergleich', icon='timer'})
end

function C:init()
  self.sequence = 0
  self.generation = 0
end

function C:send(action)
  local veh = self.vehId and getObjectByID(self.vehId)
  if not veh then return false end
  self.sequence = self.sequence + 1
  self.pending = action
  self.timeout = 5
  -- Only format the argument header: the vehicle script contains Lua patterns
  -- with percent signs, which must not be parsed as string.format directives.
  local header = string.format('local token, sequence, action = %q, %d, %q\n', self.token, self.sequence, action)
  veh:queueLuaCommand(header .. vehicleCommand)
  return true
end

function C:onDekraAbsReply(id, token, sequence, ok, reason)
  if id ~= self.vehId or token ~= self.token or sequence ~= self.sequence or not self.pending then return end
  self.reply = {action=self.pending, ok=ok, reason=reason}
  self.pending = nil
end

function C:cleanup()
  if self.race then self.race:stopRace(); self.race=nil end
  local veh = self.vehId and getObjectByID(self.vehId)
  if veh then
    core_vehicleBridge.executeAction(veh, 'setFreeze', false)
    if self.changed then self:send('restore') end
  end
  self.changed = false
end

function C:resetState()
  self.generation = self.generation + 1
  self.token = tostring(self.mgr.id) .. ':' .. tostring(self.id) .. ':' .. tostring(self.generation)
  self.state = 'init'
  self.vehId = nil
  self.pending, self.reply, self.race = nil, nil, nil
  self.timeABSOn, self.timeABSOff = nil, nil
  self.changed = false
  self.pinOut.raceData.value = nil
  self.pinOut.time.value = nil
end

function C:_executionStarted()
  self:resetState()
end

function C:_executionStopped()
  self:cleanup()
end

function C:fail(reason)
  if self.state == 'failed' then return end
  self.state = 'failed'
  message('ABS-Vergleich abgebrochen: ' .. tostring(reason), 15)
  self:cleanup()
  gameplay_missions_missionManager.stop(self.mgr.activity, {ignoreFade=true})
end

function C:startCountdown()
  local veh = getObjectByID(self.vehId)
  core_vehicleBridge.executeAction(veh, 'setFreeze', true)
  self.countdown = core_flowgraphManager.skipCountdowns and 0 or 3
  self.lastCountdown = 4
  self.state = 'countdown'
end

function C:startRace()
  local path = self.pinIn.pathData.value
  self.race = require('/lua/ge/extensions/gameplay/race/race')()
  self.race:setPath(path)
  self.race.path.config.rollingStart = false
  self.race.lapCount = 1
  self.race.autoAiMode = false
  self.race.useHotlappingApp = true
  self.race.useDebugDraw = false
  self.race.useWaypointAudio = true
  if self.mgr.activity then self.race.saveFileSuffix = self.mgr.activity.id end
  self.race:setVehicleIds({self.vehId})
  self.race:startRace()
  core_vehicleBridge.executeAction(getObjectByID(self.vehId), 'setFreeze', false)
  guihooks.trigger('ScenarioFlashMessage', {{'ui.scenarios.go', 1, "Engine.Audio.playOnce('AudioGui', 'event:UI_CountdownGo')", true}})
  self.pinOut.finished.value = true
  self.checkClock = 1
  self.state = 'racing'
end

function C:work()
  self.pinOut.finished.value = false
  self.pinOut.roundReset.value = false
  self.pinOut.active.value = false
  self.pinOut.complete.value = false
  self.pinOut.flow.value = self.pinIn.flow.value
  if self.pinIn.reset.value then
    self:cleanup()
    self:resetState()
  end
  if not self.pinIn.flow.value then return end
  if self.state == 'init' then
    local veh = getPlayerVehicle(0)
    if not veh or not self.pinIn.vehId_1.value or veh:getID() ~= self.pinIn.vehId_1.value then self:fail('Spielerfahrzeug nicht verfügbar'); return end
    if not self.pinIn.pathData.value then self:fail('Strecke nicht verfügbar'); return end
    self.vehId = veh:getID()
    self.changed = true -- restore even if the reply is lost after the command runs
    self.state = 'waitingOn'
    if not self:send('begin') then self:fail('Fahrzeug nicht verfügbar') end
    return
  end
  if self.state == 'failed' then return end
  local veh = getObjectByID(self.vehId)
  local player = getPlayerVehicle(0)
  if not veh or not player or player:getID() ~= self.vehId then self:fail('Fahrzeug gewechselt oder verloren'); return end
  if self.pending then
    self.timeout = self.timeout - (self.mgr.dtReal or 0)
    if self.timeout <= 0 then self:fail('ABS-Rückmeldung ausgeblieben'); return end
  end
  if self.reply then
    local reply = self.reply
    self.reply = nil
    if not reply.ok then self:fail(reply.reason); return end
    if reply.action == 'begin' then
      message('Runde 1 – ABS aktiviert', 4)
      self.round = 1
      self:startCountdown()
    elseif reply.action == 'off' then
      message('Runde 2 – ABS deaktiviert', 4)
      self.round = 2
      self:startCountdown()
    elseif reply.action == 'restore' then
      self.changed = false
      self.state = 'results'
      self.resultDelay = 12
      local diff = self.timeABSOff - self.timeABSOn
      local ms = math.floor(math.abs(diff) * 1000 + 0.5)
      local interpretation = ms == 0 and 'Beide Runden waren gleich schnell.' or
        string.format('%s ABS warst du %.3f Sekunden schneller.', diff > 0 and 'Mit' or 'Ohne', math.abs(diff))
      message(string.format('ABS-Vergleich – Ergebnis\nRunde 1 – ABS aktiviert: %.3f s\nRunde 2 – ABS deaktiviert: %.3f s\nZeitdifferenz (ohne − mit): %+.3f s\n%s', self.timeABSOn, self.timeABSOff, diff, interpretation), 12)
    end
  end
  if self.state == 'countdown' then
    local old = math.ceil(self.countdown)
    if old > 0 and old ~= self.lastCountdown then
      guihooks.trigger('ScenarioFlashMessage', {{tostring(old), 0.95, "Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown1')", true}})
      self.lastCountdown = old
    end
    self.countdown = self.countdown - (self.mgr.dtSim or 0)
    if self.countdown <= 0 then self:startRace() end
  elseif self.state == 'racing' then
    self.checkClock = self.checkClock - (self.mgr.dtReal or 0)
    if self.checkClock <= 0 and not self.pending then
      self.checkClock = 1
      if not self:send(self.round == 1 and 'checkOn' or 'checkOff') then self:fail('Fahrzeug nicht verfügbar'); return end
    end
    self.race:onUpdate(self.mgr.dtSim)
    local state = self.race.states[self.vehId]
    if not state then self:fail('Rennzustand verloren'); return end
    self.pinOut.raceData.value = self.race
    self.pinOut.active.value = state.active
    if state.complete then
      local time = state.endTime - state.startTime
      if self.round == 1 then
        self.timeABSOn = time
        self.race:stopRace()
        self.race = nil
        self.pinOut.roundReset.value = true
        self.pinOut.raceData.value = nil
        message(string.format('Runde 1 abgeschlossen – ABS aktiviert: %.3f s', time), 5)
        local path = self.pinIn.pathData.value
        local start = path.startPositions.objects[path.defaultStartPosition]
        if not start then self:fail('Startposition nicht verfügbar'); return end
        core_vehicleBridge.executeAction(veh, 'setFreeze', true)
        local pos = start:moveResetVehicleTo(self.vehId, false, false)
        if not pos then self:fail('Fahrzeug konnte nicht zurückgesetzt werden'); return end
        self.state = 'waitingOff'
        if not self:send('off') then self:fail('Fahrzeug nicht verfügbar') end
      else
        self.timeABSOff = time
        self.pinOut.time.value = time
        self.state = 'waitingRestore'
        if not self:send('restore') then self:fail('Fahrzeug nicht verfügbar') end
      end
    end
  elseif self.state == 'results' then
    self.resultDelay = self.resultDelay - (self.mgr.dtReal or 0)
    if self.resultDelay <= 0 then
      self.pinOut.raceData.value = self.race
      self.pinOut.time.value = self.timeABSOff
      self.pinOut.complete.value = true
      self.state = 'done'
    end
  end
end

return _flowgraph_createNode(C)
