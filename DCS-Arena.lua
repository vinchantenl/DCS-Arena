SupportHandler = EVENTHANDLER:New()

UnitNr = 1

BlueTickets = 200
RedTickets = 200

Samresupplytimer = 60

UnitTable = {}

UnitTable["tank"] = 10		-- MBT
UnitTable["aaa"] = 10		-- aaa 
UnitTable["samsr"] = 20 	-- short range Sa-6 / Hawk
UnitTable["sampd"] = 20	-- sam-point defence Sa-15 / Roland
UnitTable["samlr"] = 40 	-- long range S300 / Patriot

ClientCost = {}

ClientCost["A-10C_2"] = 5
ClientCost["FA-18C_hornet"] = 5
ClientCost["L-39ZA"] = 2
ClientCost["M-2000C"] = 5
ClientCost["TF-51D"] = 1
ClientCost["AJS37"] = 5
ClientCost["AV8BNA"] = 5
ClientCost["C-101CC"] = 2
ClientCost["F-14A-135-GR"] = 5
ClientCost["F-14B"] = 5
ClientCost["F-15C"] = 4
ClientCost["F-16C_50"] = 5
ClientCost["F-5E-3"] = 3
ClientCost["UH-1H"] = 2
ClientCost["Mi-8MT"] = 2
	

ActiveUnits = {}

LogisticsTable = {}

LogisticsClientSet = SET_CLIENT:New():FilterPrefixes("Transport"):FilterStart()
--RedLogisticsClientSet = SET_CLIENT:New():FilterActive():FilterCoalition( "red" ):FilterPrefixes("Transport"):FilterStart()


local MissionSchedule = SCHEDULER:New( nil, 
  function()
	ResupplyScheduleCheck()
	SupplyCrateLoad(2)
	MessageAll = MESSAGE:New( BlueTickets,  25):ToAll()
	MessageAll = MESSAGE:New( RedTickets,  25):ToAll()
  end, {}, 1, 10
  )

--supply funtions
function ResupplyScheduleCheck()
	if ActiveUnits ~= nil then 
		for k,v in pairs(ActiveUnits) do
			--changed to more generic "sam" selectors
			if string.match(k,"sam") then
				if timer.getAbsTime() - v > Samresupplytimer then
					MessageAll = MESSAGE:New( k,  25):ToAll()
					SuppliedUnit = GROUP:FindByName( k )
					local suppliedUnitName = SuppliedUnit:GetName()

					-- disable SAM site to simulate out of resources
					SuppliedUnit:SetAIOff()

					-- create marker for resupply
					local supplyMarkerLoc = SuppliedUnit:GetCoordinate()
					Mymarker=MARKER:New(supplyMarkerLoc, "Please Resupply this unit!"):ToAll()
					
					--create resupplyzone
					ZoneA = ZONE_GROUP:New( k, SuppliedUnit, 200 )
					--debug flares
					ZoneA:FlareZone( FLARECOLOR.White, 90, 60 )

					LogisticsClientSet:ForEachClientInZone(ZoneA, function(client)
							if (client ~= nil) and (client:IsAlive()) then 
								if (client:InAir() == false) and (LogisticsTable[client:Name()] == "logistics") then
									LogisticsTable[client:Name()] = nil
									-- re-enable sam to simulate resupply
									SuppliedUnit:SetAIOn()

									-- reset resuppoly timer
									ActiveUnits[suppliedUnitName] = timer.getAbsTime()
									MessageAll = MESSAGE:New( "Sam Resupplied",  25):ToAll()
								end
							end
						end
					)
				end
			end
		end
	end
end

function SupplyCrateLoad()
	for i = 1, 2, 1
		do
			local SupplyCrateName = ReturnCoalitionName(i).." Supply Crate"

			local SupplyCrate = STATIC:FindByName(SupplyCrateName, false)
			if SupplyCrate ~= nil then
				local SupplyCrateCoords = SupplyCrate:GetCoordinate()
				
				ZoneCrate = ZONE_GROUP:New( SupplyCrateName, SupplyCrate, 50 )
				ZoneCrate:FlareZone( FLARECOLOR.Red, 90, 60 )

				LogisticsClientSet:ForEachClientInZone(ZoneCrate, function(client)
					if (client ~= nil) and (client:IsAlive()) then 
						if client:InAir() == false then
							if LogisticsTable[client:Name()] == nil then
								--pick up logistics crate
								MessageAll = MESSAGE:New( client:Name(),  25):ToAll()
								LogisticsTable[client:Name()] = "logistics"
							else
								MessageAll = MESSAGE:New( client:Name().. "heeft al een krat aan boord van type: "..LogisticsTable[client:Name()],  25):ToAll()
							end
						end
					end
				end
				)
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

function BirthDetected(Event)
	env.info("Birth Detected")
	if Event.IniPlayerName ~= nil then
		local initiator = Event.IniPlayerName
		local initiator_type = Event.IniTypeName
		local initiator_coalition = Event.IniCoalition
		local initiator_cost = ClientCost[initiator_type]
		if initiator_coalition == 1 then
			RedTickets = RedTickets - initiator_cost
		elseif initiator_coalition ==2 then
			BlueTickets = BlueTickets - initiator_cost
		end
		env.info("New Player: " .. initiator .. ", Type: ".. initiator_type.. ", Cost: ".. initiator_cost.. ", Coalition: ".. initiator_coalition)
		MessageAll = MESSAGE:New( "Tickets remaining: " .. BlueTickets,  25):ToAll()
	end
end

function KillDetected(Event)
		local targetType = Event.TgtTypeName
		local targetCoalition = Event.TgtCoalition

		if ClientCost[targetType] ~= nil then
			local TicketsEarned = ClientCost[targetType]
			if targetCoalition == 1 then
				RedTickets = RedTickets + TicketsEarned
			elseif targetCoalition ==2 then
				BlueTickets = BlueTickets + TicketsEarned
			end
		else
			if targetCoalition == 1 then
				RedTickets = RedTickets + 2
			elseif targetCoalition ==2 then
				BlueTickets = BlueTickets + 2
			end
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
	elseif Event.id == world.event.S_EVENT_BIRTH then
		--birth detected
		BirthDetected(Event)
	elseif Event.id == world.event.S_EVENT_KILL then
		--death detected
		--needs fixing
		--KillDetected()
	elseif Event.id == world.event.S_EVENT_LAND then
		--landing detected
    end
end

world.addEventHandler(SupportHandler)