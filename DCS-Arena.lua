SupportHandler = EVENTHANDLER:New()
UnitNr = 1

BlueTickets = 100
RedTickets = 100

Samresupplytimer = 60

UnitTable = {}

UnitTable["tank"] = 10		-- MBT
UnitTable["aaa"] = 10		-- aaa 
UnitTable["sam_sr"] = 20 	-- short range Sa-6 / Hawk
UnitTable["sam_lr"] = 40 	-- long range S300 / Patriot

ActiveUnits = {}

LogisticsClientSet = SET_CLIENT:New():FilterCoalitions("blue"):FilterStart()
--RedLogisticsClientSet = SET_CLIENT:New():FilterActive():FilterCoalition( "red" ):FilterPrefixes("Transport"):FilterStart()


local MissionSchedule = SCHEDULER:New( nil, 
  function()
	ResupplyScheduleCheck()
  end, {}, 1, 10
  )
  
function ResupplyScheduleCheck()
	if ActiveUnits ~= nil then 
		for k,v in pairs(ActiveUnits) do
			if string.match(k,"sam_sr") or string.match(k,"sam_lr") then
				if timer.getAbsTime() - v > Samresupplytimer then
					MessageAll = MESSAGE:New( k,  25):ToAll()
					SuppliedUnit = GROUP:FindByName( k )
					local supplyMarkerLoc = SuppliedUnit:GetCoordinate()
					SuppliedUnit:SetAIOff()
					local suppliedUnitName = SuppliedUnit:GetName()
					Mymarker=MARKER:New(supplyMarkerLoc, "Please Resupply this unit!"):ToAll()
					
					--create resupplyzone
					ZoneA = ZONE_GROUP:New( k, SuppliedUnit, 200 )
					ZoneA:FlareZone( FLARECOLOR.White, 90, 60 )

					LogisticsClientSet:ForEachClientInZone(ZoneA, function(client)
							if (client ~= nil) and (client:IsAlive()) then 
								local group = client:GetGroup()
								SuppliedUnit:SetAIOn()
								
								
								ActiveUnits[suppliedUnitName] = timer.getAbsTime()
								MessageAll = MESSAGE:New( suppliedUnitName,  25):ToAll()
							end
						end
					)
				end
			end
		end
	end
end

function ReturnCoalitionName(coalition)
 if coalition == 1 then
	return "Red"
 elseif coalition == 2 then
	return "Blue"
 end
end

function SpawnUnitCheck(coord, coalition, text)
	Unitcost = UnitTable[text]
	if Unitcost ~= nil then	
		if coalition == 1 then
			Tickets = RedTickets
		elseif coalition == 2 then
			Tickets = BlueTickets
		end
			
		if Tickets < Unitcost then
			MessageAll = MESSAGE:New( "Onvoldoende Tickets!",  25):ToCoalition(coalition)
		else
			
			Tickets = Tickets - Unitcost
			if coalition == 2 then
				BlueTickets = Tickets
			elseif coalition == 1 then
				RedTickets = Tickets
			end
			
			SpawnUnit(coord, coalition, text)
			
			MessageAll = MESSAGE:New( "Tickets: "..Tickets,  25):ToCoalition(coalition)
			MessageAll = MESSAGE:New( "Unitcost: "..Unitcost,  25):ToCoalition(coalition)
			MessageAll = MESSAGE:New( Tickets.." Tickets over",  25):ToCoalition(coalition)
		end
	else
		MessageAll = MESSAGE:New( "Ongeldige Unit!",  25):ToCoalition(coalition)
	end
end

function SpawnUnit(coord, coalition, text)
	local SpawnUnitTemplate = ReturnCoalitionName(coalition).."_"..text
	local UnitAlias = ReturnCoalitionName(coalition).." "..text .. "#" ..UnitNr
	local SpawnUnit = SPAWN:NewWithAlias( SpawnUnitTemplate, UnitAlias )
	SpawnUnit:SpawnFromVec2( coord:GetVec2() )
	ActiveUnits[UnitAlias.."#001"] = timer.getAbsTime()
	UnitNr = UnitNr + 1
end

function MarkRemoved(Event)
    if Event.text~=nil then 
        local text = Event.text:lower()
        local vec3 = {z=Event.pos.z, x=Event.pos.x}
		local coalition = Event.coalition
        local coord = COORDINATE:NewFromVec3(vec3)
		
		SpawnUnitCheck(coord, coalition, text)	
    end
end

function SupportHandler:onEvent(Event)
    if Event.id == world.event.S_EVENT_MARK_ADDED then
        -- env.info(string.format("BTI: Support got event ADDED id %s idx %s coalition %s group %s text %s", Event.id, Event.idx, Event.coalition, Event.groupID, Event.text))
    elseif Event.id == world.event.S_EVENT_MARK_CHANGE then
        -- env.info(string.format("BTI: Support got event CHANGE id %s idx %s coalition %s group %s text %s", Event.id, Event.idx, Event.coalition, Event.groupID, Event.text))
    elseif Event.id == world.event.S_EVENT_MARK_REMOVED then
        -- env.info(string.format("BTI: Support got event REMOVED id %s idx %s coalition %s group %s text %s", Event.id, Event.idx, Event.coalition, Event.groupID, Event.text))
        MarkRemoved(Event)
    end
end

world.addEventHandler(SupportHandler)