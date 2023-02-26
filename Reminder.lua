local GlobalAddonName, ExRT = ...

local ELib,L = ExRT.lib,ExRT.L
local module = ExRT:New("Reminder","Reminder",nil,true)
if not module then return end

local LibDeflate = LibStub:GetLibrary("LibDeflate")

local VExRT = nil

local GetInstanceInfo, UnitGroupRolesAssigned, UnitPowerMax, GetSpecialization, tonumber, floor, UnitGUID, C_Timer, PlaySoundFile = GetInstanceInfo, UnitGroupRolesAssigned, UnitPowerMax, GetSpecialization, tonumber, floor, UnitGUID, C_Timer, PlaySoundFile
local UnitHealthMax, UnitHealth, UnitIsUnit = UnitHealthMax, UnitHealth, UnitIsUnit
local pairs, bit_band = pairs, bit.band

local senderVersion = 2
local dataVersion = 11

local frame = CreateFrame('Frame',nil,UIParent)
frame:SetSize(30,30)
frame:SetPoint("CENTER",UIParent,"TOP",0,-100)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
	if self:IsMovable() then
		self:StartMoving()
	end
end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	VExRT.Reminder.Left = self:GetLeft()
	VExRT.Reminder.Top = self:GetTop()
end)

frame.text = frame:CreateFontString(nil,"ARTWORK")
frame.text:SetPoint("CENTER")
frame.text:SetFont(ExRT.F.defFont, 40)
frame.text:SetShadowOffset(1,-1)
frame.text:SetTextColor(1,1,1,1)
frame.text:SetText("Test")

local HideDelay,CountdownTimer

frame.dot = frame:CreateTexture(nil, "BACKGROUND",nil,-6)
frame.dot:SetTexture("Interface\\AddOns\\MRT\\media\\circle256")
frame.dot:SetAllPoints()
frame.dot:SetVertexColor(1,0,0,1)

frame:Hide()
frame.dot:Hide()

local FlagMarkToIndex = {
	[0] = 0,
	[0x1] = 1,
	[0x2] = 2,
	[0x4] = 3,
	[0x8] = 4,
	[0x10] = 5,
	[0x20] = 6,
	[0x40] = 7,
	[0x80] = 8,
	[0x100] = 9,
	[0x200] = 10,
	[0x400] = 11,
	[0x800] = 12,
	[0x1000] = 13,
	[0x2000] = 14,
	[0x4000] = 15,
	[0x8000] = 16,
	[0x10000] = 17,
	[0x20000] = 18,
}

local CLEU_SPELL_CAST_SUCCESS = {}
local CLEU_SPELL_CAST_START = {}
local CLEU_BOSS_PHASE = {}
local CLEU_BOSS_START = {}
local CLEU_BOSS_HP = {}
local CLEU_BOSS_MANA = {}
local CLEU_BW_MSG = {}
local CLEU_BW_TIMER = {}
local CLEU_SPELL_AURA_APPLIED = {}
local CLEU_SPELL_AURA_REMOVED = {}
local CLEU_SPELL_AURA_APPLIED_SELF = {}
local CLEU_SPELL_AURA_REMOVED_SELF = {}

local CastNumbers_SUCCESS = {}
local CastNumbers_START = {}
local CastNumbers_PHASE = {}
local CastNumbers_HP = {}
local CastNumbers_MANA,CastNumbers_MANA2 = {},{}
local CastNumbers_BW_MSG = {}
local CastNumbers_BW_TIMER = {}
local CastNumbers_AURA_APPLIED = {}
local CastNumbers_AURA_REMOVED = {}
local CastNumbers_AURA_APPLIED_SELF = {}
local CastNumbers_AURA_REMOVED_SELF = {}

module.db.CLEU_SPELL_CAST_SUCCESS = CLEU_SPELL_CAST_SUCCESS
module.db.CLEU_SPELL_CAST_START = CLEU_SPELL_CAST_START
module.db.CLEU_BOSS_PHASE = CLEU_BOSS_PHASE
module.db.CLEU_BOSS_START = CLEU_BOSS_START
module.db.CLEU_BOSS_HP = CLEU_BOSS_HP
module.db.CLEU_BOSS_MANA = CLEU_BOSS_MANA
module.db.CLEU_BW_MSG = CLEU_BW_MSG
module.db.CLEU_BW_TIMER = CLEU_BW_TIMER
module.db.CLEU_SPELL_AURA_APPLIED = CLEU_SPELL_AURA_APPLIED
module.db.CLEU_SPELL_AURA_REMOVED = CLEU_SPELL_AURA_REMOVED
module.db.CLEU_SPELL_AURA_APPLIED_SELF = CLEU_SPELL_AURA_APPLIED_SELF
module.db.CLEU_SPELL_AURA_REMOVED_SELF = CLEU_SPELL_AURA_REMOVED_SELF

local stopHistory = true
local history = {}
module.db.history = history

local ActiveEncounter = nil
local ActiveEncounterStart = nil
local ActivePhase = 0
local ActiveDelays = {}

local ProcessTextToData

local CLEU = CreateFrame("Frame")
--CLEU:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
CLEU:SetScript("OnEvent",function()
	local timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,spellID,spellName,school,arg1 = CombatLogGetCurrentEventInfo()
	if event == "SPELL_CAST_SUCCESS" then
		local f = CLEU_SPELL_CAST_SUCCESS[spellID]
		if f then
			CastNumbers_SUCCESS[sourceGUID] = CastNumbers_SUCCESS[sourceGUID] or {}
			CastNumbers_SUCCESS[sourceGUID][spellID] = (CastNumbers_SUCCESS[sourceGUID][spellID] or 0) + 1
			CastNumbers_SUCCESS[spellID] = (CastNumbers_SUCCESS[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_SUCCESS[sourceGUID][spellID],sourceGUID,sourceFlags2 or 0,CastNumbers_SUCCESS[spellID])
			end
		end
		if bit_band(sourceFlags,0x000000F0) ~= 0x00000010 and not stopHistory then
			history[#history+1] = {GetTime(),"SPELL_CAST_SUCCESS",spellID,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2}
		end
	elseif event == "SPELL_CAST_START" then
		local f = CLEU_SPELL_CAST_START[spellID]
		if f then
			CastNumbers_START[sourceGUID] = CastNumbers_START[sourceGUID] or {}
			CastNumbers_START[sourceGUID][spellID] = (CastNumbers_START[sourceGUID][spellID] or 0) + 1
			CastNumbers_START[spellID] = (CastNumbers_START[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_START[sourceGUID][spellID],sourceGUID,sourceFlags2 or 0,CastNumbers_START[spellID])
			end
		end		
		if bit_band(sourceFlags,0x000000F0) ~= 0x00000010 and not stopHistory then
			history[#history+1] = {GetTime(),"SPELL_CAST_START",spellID,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2}
		end
	elseif event == "SPELL_AURA_APPLIED" then
		local f = CLEU_SPELL_AURA_APPLIED[spellID]
		if f then
			CastNumbers_AURA_APPLIED[sourceGUID] = CastNumbers_AURA_APPLIED[sourceGUID] or {}
			CastNumbers_AURA_APPLIED[sourceGUID][spellID] = (CastNumbers_AURA_APPLIED[sourceGUID][spellID] or 0) + 1
			CastNumbers_AURA_APPLIED[spellID] = (CastNumbers_AURA_APPLIED[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_AURA_APPLIED[sourceGUID][spellID],sourceGUID,destFlags2 or 0,CastNumbers_AURA_APPLIED[spellID])	
			end
		end
		f = CLEU_SPELL_AURA_APPLIED_SELF[spellID]
		if f and destGUID == UnitGUID'player' then
			CastNumbers_AURA_APPLIED_SELF[sourceGUID] = CastNumbers_AURA_APPLIED_SELF[sourceGUID] or {}
			CastNumbers_AURA_APPLIED_SELF[sourceGUID][spellID] = (CastNumbers_AURA_APPLIED_SELF[sourceGUID][spellID] or 0) + 1
			CastNumbers_AURA_APPLIED_SELF[spellID] = (CastNumbers_AURA_APPLIED_SELF[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_AURA_APPLIED_SELF[sourceGUID][spellID],sourceGUID,sourceFlags2 or 0,CastNumbers_AURA_APPLIED_SELF[spellID])	
			end
		end
		if bit_band(sourceFlags,0x000000F0) ~= 0x00000010 and not stopHistory then
			history[#history+1] = {GetTime(),"SPELL_AURA_APPLIED",spellID,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2}
		end
	elseif event == "SPELL_AURA_REMOVED" then
		local f = CLEU_SPELL_AURA_REMOVED[spellID]
		if f then
			CastNumbers_AURA_REMOVED[sourceGUID] = CastNumbers_AURA_REMOVED[sourceGUID] or {}
			CastNumbers_AURA_REMOVED[sourceGUID][spellID] = (CastNumbers_AURA_REMOVED[sourceGUID][spellID] or 0) + 1
			CastNumbers_AURA_REMOVED[spellID] = (CastNumbers_AURA_REMOVED[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_AURA_REMOVED[sourceGUID][spellID],sourceGUID,destFlags2 or 0,CastNumbers_AURA_REMOVED[spellID])
			end
		end
		f = CLEU_SPELL_AURA_REMOVED_SELF[spellID]
		if f and destGUID == UnitGUID'player' then
			CastNumbers_AURA_REMOVED_SELF[sourceGUID] = CastNumbers_AURA_REMOVED_SELF[sourceGUID] or {}
			CastNumbers_AURA_REMOVED_SELF[sourceGUID][spellID] = (CastNumbers_AURA_REMOVED_SELF[sourceGUID][spellID] or 0) + 1
			CastNumbers_AURA_REMOVED_SELF[spellID] = (CastNumbers_AURA_REMOVED_SELF[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_AURA_REMOVED_SELF[sourceGUID][spellID],sourceGUID,sourceFlags2 or 0,CastNumbers_AURA_REMOVED_SELF[spellID])
			end
		end
		if bit_band(sourceFlags,0x000000F0) ~= 0x00000010 and not stopHistory then
			history[#history+1] = {GetTime(),"SPELL_AURA_REMOVED",spellID,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2}
		end
	end
end)

if false then
	stopHistory = false
	CLEU:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	bit_band = function() return 1 end
end

local BOSSHPFrame = CreateFrame("Frame")
BOSSHPFrame:SetScript("OnEvent",function(self,_,unit)
	local thisUnit = CLEU_BOSS_HP[unit]
	if thisUnit then
		local hpMax = UnitHealthMax(unit)
		if hpMax == 0 then
			return
		end
		local hp = UnitHealth(unit) / hpMax * 100
		if hp == 0 then
			return
		end

		for HP,funcs in pairs(thisUnit) do
			if hp <= HP then
				for i=1,#funcs do
					local f = funcs[i]
					if not CastNumbers_HP[f] then
						CastNumbers_HP[f] = true
						f()
					end
				end
			end
		end
	end
end)

local bossManaPrev = {}

local BOSSManaFrame = CreateFrame("Frame")
BOSSManaFrame:SetScript("OnEvent",function(self,_,unit)
	local thisUnit = CLEU_BOSS_MANA[unit]
	if thisUnit then
		local hpMax = UnitPowerMax(unit)
		if hpMax == 0 then
			return
		end
		
		CastNumbers_MANA2[unit] = CastNumbers_MANA2[unit] or 1
		
		local hp = UnitPower(unit) / hpMax * 100
		if bossManaPrev[unit] and hp < bossManaPrev[unit] then
			CastNumbers_MANA2[unit] = CastNumbers_MANA2[unit] + 1
			for HP,funcs in pairs(thisUnit) do
				for i=1,#funcs do
					CastNumbers_MANA[ funcs[i] ] = nil
				end				
			end
		end
		bossManaPrev[unit] = hp

		for HP,funcs in pairs(thisUnit) do
			if hp >= HP then
				for i=1,#funcs do
					local f = funcs[i]
					if not CastNumbers_MANA[f] then
						CastNumbers_MANA[f] = true
						f(CastNumbers_MANA2[unit])
					end
				end
			end
		end
	end
end)


local bwBars = {}
local bwTextToSpellID = {}
local function bigWigsEventCallback(event, ...)
	if (event == "BigWigs_Message") then
		local addon, spellID, text, name, icon = ...
		local f = CLEU_BW_MSG[spellID]
		if f then
			CastNumbers_BW_MSG[spellID] = (CastNumbers_BW_MSG[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_BW_MSG[spellID],nil,0)
			end
		end
	elseif (event == "BigWigs_StartBar") then
		local addon, spellID, text, duration, icon = ...
		local now = GetTime()
		local expirationTime = now + duration

		local curr_uid = now
		bwBars[text] = curr_uid
		bwTextToSpellID[text] = spellID

		local f = CLEU_BW_TIMER[spellID]
		if f then
			CastNumbers_BW_TIMER[spellID] = (CastNumbers_BW_TIMER[spellID] or 0) + 1
			for i=1,#f do
				f[i](CastNumbers_BW_TIMER[spellID],text,curr_uid,expirationTime)
			end
		end
	elseif (event == "BigWigs_ResumeBar") then
		local addon, text = ...

		if not BigWigs or not BigWigs.modules or not BigWigs.modules.Bosses or not BigWigs.modules.Bosses.modules then
			return
		end

		local duration = 0
		local bars = BigWigs:GetPlugin("Bars")
		if bars then
			for _,mod in pairs(BigWigs.modules.Bosses.modules) do
				duration = mod:BarTimeLeft(text)
				if duration > 0 then
					break
				end
			end
		end
		if duration == 0 then
			return
		end

		local spellID = bwTextToSpellID[text]
		if not spellID then
			return
		end

		local now = GetTime()
		local expirationTime = now + duration

		local curr_uid = now
		bwBars[text] = curr_uid

		local f = CLEU_BW_TIMER[spellID]
		if f then
			CastNumbers_BW_TIMER[spellID] = (CastNumbers_BW_TIMER[spellID] or 0)
			for i=1,#f do
				f[i](CastNumbers_BW_TIMER[spellID],text,curr_uid,expirationTime)
			end
		end
	elseif (event == "BigWigs_StopBar") or (event == "BigWigs_PauseBar") then
		local addon, text = ...
		bwBars[text] = nil
	elseif (event == "BigWigs_StopBars" or event == "BigWigs_OnBossDisable"	or event == "BigWigs_OnPluginDisable") then
		local addon = ...
		for key, bar in pairs(bwBars) do
			bwBars[key] = nil
		end
	end
end

local playerName = UnitName'player'

local GetPlayerRole = ExRT.F.GetPlayerRole

local function FormatMsg(msg)
	msg = msg:gsub("({spell:(%d+)})",function(match,spellID)
		spellID = tonumber(spellID)
		if spellID then
			local _,_,spellTexture = GetSpellInfo( spellID )
			return "|T"..(spellTexture or "Interface\\Icons\\INV_MISC_QUESTIONMARK")..":0|t"
		end
	end):gsub("({rt(%d+)})",function(match,markID)
		return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_"..markID..":0|t"
	end):gsub("||([cr])","|%1")
	return msg
end

local function FindPlayerInNote(pat)
	local reverse = pat:find("^%-")
	pat = "^"..pat:gsub("^%-",""):gsub("([%.%(%)%-%$])","%%%1")
	if not VExRT or not VExRT.Note or not VExRT.Note.Text1 then
		return
	end
	local lines = {strsplit("\n", VExRT.Note.Text1)}
	for i=1,#lines do
		if lines[i]:find(pat) then
			local l = lines[i]:gsub(pat.." *",""):gsub("|c........",""):gsub("|r",""):gsub(" *$",""):gsub("|",""):gsub(" +"," ")
			local list = {strsplit(" ", l)}
			for j=1,#list do
				if list[j] == playerName then
					if reverse then
						return false
					else
						return true
					end
				end
			end
		end
	end
	if reverse then
		return true
	end
end
local function FindPlayersListInNote(pat)
	pat = "^"..pat:gsub("([%.%(%)%-%$])","%%%1")
	if not VExRT or not VExRT.Note or not VExRT.Note.Text1 then
		return
	end
	local lines = {strsplit("\n", VExRT.Note.Text1)}
	local res
	for i=1,#lines do
		if lines[i]:find(pat) then
			local l = lines[i]:gsub(pat.." *",""):gsub("|c........",""):gsub("|r",""):gsub(" *$",""):gsub("|",""):gsub(" +"," ")
			if not res then res = "" end
			res = res..(res ~= "" and " " or "")..l
		end
	end
	return res
end

local function CreateFunctions()
	wipe(CLEU_SPELL_CAST_SUCCESS)
	wipe(CLEU_SPELL_CAST_START)
	wipe(CLEU_BOSS_PHASE)
	wipe(CLEU_BOSS_START)
	wipe(CLEU_BOSS_HP)
	wipe(CLEU_BOSS_MANA)
	wipe(CLEU_BW_MSG)
	wipe(CLEU_BW_TIMER)
	wipe(CLEU_SPELL_AURA_APPLIED)
	wipe(CLEU_SPELL_AURA_REMOVED)
	wipe(CLEU_SPELL_AURA_APPLIED_SELF)
	wipe(CLEU_SPELL_AURA_REMOVED_SELF)
	for token,data in pairs(VExRT.Reminder.data) do
		local funcTable
		if data.event == "SPELL_CAST_SUCCESS" then
			funcTable = CLEU_SPELL_CAST_SUCCESS
		elseif data.event == "SPELL_CAST_START" then
			funcTable = CLEU_SPELL_CAST_START
		elseif data.event == "BOSS_PHASE" then
			funcTable = CLEU_BOSS_PHASE
		elseif data.event == "BOSS_START" then
			funcTable = CLEU_BOSS_START
		elseif data.event == "BOSS_HP" then
			funcTable = CLEU_BOSS_HP
		elseif data.event == "BOSS_MANA" then
			funcTable = CLEU_BOSS_MANA
		elseif data.event == "BW_MSG" then
			funcTable = CLEU_BW_MSG
		elseif data.event == "BW_TIMER" then
			funcTable = CLEU_BW_TIMER
		elseif data.event == "SPELL_AURA_APPLIED" then
			funcTable = CLEU_SPELL_AURA_APPLIED
		elseif data.event == "SPELL_AURA_REMOVED" then
			funcTable = CLEU_SPELL_AURA_REMOVED
		elseif data.event == "SPELL_AURA_APPLIED_SELF" then
			funcTable = CLEU_SPELL_AURA_APPLIED_SELF
		elseif data.event == "SPELL_AURA_REMOVED_SELF" then
			funcTable = CLEU_SPELL_AURA_REMOVED_SELF
		end
		if funcTable and not VExRT.Reminder.disabled[ data.token ] then
			local newFunc
			if data.event == "BW_TIMER" then
				newFunc = function(castNumber,barText,callUID,expirationTime)
					if data.diff then
						local _,_,d = GetInstanceInfo()
						if data.diff ~= d then
							return
						end
					end
					if data.cast then
						local c = data.cast
						if c < 0 then
							c = -c
							local c1,c2 = floor(c),floor((c % 1) * 10)
							if (castNumber % c1) ~= c2 then
								return
							end
						else
							if castNumber ~= data.cast then
								return
							end
						end
					end
					if data.boss and ActiveEncounter ~= data.boss then
						return
					end
					local isNoteOn,isInNote
					if data.notepat then
						isNoteOn = true
						isInNote = FindPlayerInNote(data.notepat)
					end
					if isNoteOn and not isInNote then
						return
					end
					if not isNoteOn and data.units and not data.units:find("#"..playerName.."#") then
						return
					end
					if not isNoteOn and data.roles then
						local role1, role2 = GetPlayerRole()
						if role1 ~= "DAMAGER" then
							if not data.roles:find("#"..role1.."#") then
								return
							end
						else
							local check = false
							if data.roles:find("#"..role1.."#") then
								check = true
							elseif data.roles:find("#"..role2.."#") then
								check = true
							end
							if not check then
								return
							end
						end
					end
					local go = function()
						if bwBars[barText] ~= callUID then
							return
						end
						if HideDelay then HideDelay:Cancel() end
						if CountdownTimer then CountdownTimer:Cancel() end
						frame.text:SetText(FormatMsg(data.msg))
						HideDelay = C_Timer.NewTimer(data.duration,function()
							HideDelay = nil
							if CountdownTimer then CountdownTimer:Cancel() end
							CountdownTimer = nil
							frame:Hide()
						end)
						if data.countdown then
							local exp = GetTime() + data.duration
							local str = FormatMsg(data.msg)
							frame.text:SetFormattedText("%s - %.1f",str,data.duration)
							CountdownTimer = C_Timer.NewTicker(0.05,function()
								local timeLeft = exp - GetTime()
								if timeLeft < 0 then
									frame.text:SetText(timeLeft)
								else
									frame.text:SetFormattedText("%s - %.1f",str,timeLeft)
								end
							end)
						end
						frame:Show()
						if data.sound and not VExRT.Reminder.disableSound then
							pcall(PlaySoundFile,data.sound, "Master")
						end
					end
					if data.delay and data.delay ~= "" then
						local d = data.delay
						if tonumber(d) then
							ActiveDelays[#ActiveDelays+1] = C_Timer.NewTimer((expirationTime - tonumber(d)) - GetTime(),go)
						else
							local dl = {strsplit(",", d)}
							for i=1,#dl do
								local t = tonumber(dl[i] or "?")
								if t and t >= 0 then
									ActiveDelays[#ActiveDelays+1] = C_Timer.NewTimer((expirationTime - t) - GetTime(),go)
								end
							end
						end
					end
				end
			else
				newFunc = function(castNumber,sourceGUID,sourceMark,globalCastNumber)
					if data.diff then
						local _,_,d = GetInstanceInfo()
						if data.diff ~= d then
							return
						end
					end
					if data.cast and data.event ~= "BOSS_HP" and data.event ~= "BOSS_START" then
						local currCastNumber = data.globalCounter and globalCastNumber or castNumber
						local c = data.cast
						if c < 0 then
							c = -c
							local c1,c2 = floor(c),floor((c % 1) * 10)
							if (currCastNumber % c1) ~= c2 then
								return
							end
						else
							if currCastNumber ~= data.cast then
								return
							end
						end
					end
					if data.condition and data.event ~= "BOSS_HP" and data.event ~= "BOSS_MANA" and data.event ~= "BOSS_PHASE" and data.event ~= "BOSS_START" then
						local c = data.condition
						if c == "target" then
							if UnitGUID'target' ~= sourceGUID then
								return
							end
						elseif c == "focus" then
							if UnitGUID'focus' ~= sourceGUID then
								return
							end
						elseif c == "mouseover" then
							if UnitGUID'mouseover' ~= sourceGUID then
								return
							end
						elseif type(c) == 'number' then
							if FlagMarkToIndex[sourceMark] ~= c then
								return
							end
						end
					end
					if data.boss and ActiveEncounter ~= data.boss then
						return
					end
					local isNoteOn,isInNote
					if data.notepat then
						isNoteOn = true
						isInNote = FindPlayerInNote(data.notepat)
					end
					if isNoteOn and not isInNote then
						return
					end
					if not isNoteOn and data.units and not data.units:find("#"..playerName.."#") then
						return
					end
					if not isNoteOn and data.roles then
						local role1, role2 = GetPlayerRole()
						if role1 ~= "DAMAGER" then
							if not data.roles:find("#"..role1.."#") then
								return
							end
						else
							local check = false
							if data.roles:find("#"..role1.."#") then
								check = true
							elseif data.roles:find("#"..role2.."#") then
								check = true
							end
							if not check then
								return
							end
						end
					end
					local go = function()
						if (data.event == "BOSS_PHASE" and (ActivePhase ~= data.spellID or ActiveEncounterStart ~= globalCastNumber)) or
						   (data.event == "BOSS_START" and (ActiveEncounterStart ~= globalCastNumber)) then
							return
						end					
						if HideDelay then HideDelay:Cancel() end
						if CountdownTimer then CountdownTimer:Cancel() end
						frame.text:SetText(FormatMsg(data.msg))
						HideDelay = C_Timer.NewTimer(data.duration,function()
							HideDelay = nil
							if CountdownTimer then CountdownTimer:Cancel() end
							CountdownTimer = nil
							frame:Hide()
						end)
						if data.countdown then
							local exp = GetTime() + data.duration
							local str = FormatMsg(data.msg)
							frame.text:SetFormattedText("%s - %.1f",str,data.duration)
							CountdownTimer = C_Timer.NewTicker(0.05,function()
								local timeLeft = exp - GetTime()
								if timeLeft < 0 then
									frame.text:SetText(timeLeft)
								else
									frame.text:SetFormattedText("%s - %.1f",str,timeLeft)
								end
							end)
						end
						frame:Show()
						if data.sound and not VExRT.Reminder.disableSound then
							pcall(PlaySoundFile,data.sound, "Master")
						end
					end
					if data.delay and data.delay ~= "" then
						local d = data.delay
						if tonumber(d) then
							ActiveDelays[#ActiveDelays+1] = C_Timer.NewTimer(tonumber(d),go)
						else
							local dl = {strsplit(",", d)}
							for i=1,#dl do
								local t = tonumber(dl[i] or "?")
								if t and t >= 0 then
									ActiveDelays[#ActiveDelays+1] = C_Timer.NewTimer(t,go)
								end
							end
						end
					else
						go()
					end
				end
			end
			
			if (data.event == "SPELL_CAST_SUCCESS" or data.event == "SPELL_CAST_START" 
			   or data.event == "SPELL_AURA_APPLIED" or data.event == "SPELL_AURA_REMOVED"
			   or data.event == "SPELL_AURA_APPLIED_SELF" or data.event == "SPELL_AURA_REMOVED_SELF") then
				funcTable[data.spellID] = funcTable[data.spellID] or {}
				funcTable[data.spellID][ #funcTable[data.spellID] + 1 ] = newFunc
			elseif (data.event == "BW_MSG" or data.event == "BW_TIMER") then
				funcTable[data.spellID] = funcTable[data.spellID] or {}
				funcTable[data.spellID][ #funcTable[data.spellID] + 1 ] = newFunc				
			elseif data.event == "BOSS_HP" or data.event == "BOSS_MANA" then
				local condition = type(data.condition) == 'nil' and "boss1" or data.condition
				if type(condition) == 'string' and type(data.spellID) == 'number' then
					funcTable[condition] = funcTable[condition] or {}
					funcTable[condition][data.spellID] = funcTable[condition][data.spellID] or {}
					local ff = funcTable[condition][data.spellID]
					ff[#ff+1] = newFunc
				end
			elseif data.boss and data.event == "BOSS_PHASE" then
				funcTable[data.boss] = funcTable[data.boss] or {}
				funcTable[data.boss][data.spellID] = funcTable[data.boss][data.spellID] or {}
				local ff = funcTable[data.boss][data.spellID]
				ff[#ff+1] = newFunc
			elseif data.boss and data.event == "BOSS_START" then
				funcTable[data.boss] = funcTable[data.boss] or {}
				local ff = funcTable[data.boss]
				ff[#ff+1] = newFunc
			end
		end
	end
end

function module.options:Load()
	self:CreateTilte()
	
	ExRT.lib:Text(self,"v."..dataVersion,11):Point("BOTTOMLEFT",self.title,"BOTTOMRIGHT",5,2)
	
	
	local encountersList = ExRT.F.GetEncountersList(true,nil,true)

	local eventsList = {
		{"SPELL_CAST_SUCCESS","Cast Finished"},
		{"SPELL_CAST_START","Cast Started"},
		{"BOSS_PHASE","Boss Phase"},
		{"BOSS_START","Pull"},
		{"BOSS_HP","Boss %hp"},
		{"BOSS_MANA","Boss %energy"},
		{"BW_MSG","BigWigs Message"},
		{"BW_TIMER","BigWigs Timer"},
		{"SPELL_AURA_APPLIED","aura applied"},
		{"SPELL_AURA_REMOVED","aura removed"},
		{"SPELL_AURA_APPLIED_SELF","aura applied [personal]"},
		{"SPELL_AURA_REMOVED_SELF","aura removed [personal]"},
	}
	local castsList = {
		{nil,"All"},
		{1,"1"},
		{2,"2"},
		{3,"3"},
		{4,"4"},
		{5,"5"},
		{6,"6"},
		{7,"7"},
		{8,"8"},
		{9,"9"},
		{10,"10"},
		{-2.1,"every 2 [1,3]"},
		{-2.0,"every 2 [2,4]"},
		{-3.1,"every 3 [1,4,7]"},
		{-3.2,"every 3 [2,5,8]"},
		{-3.0,"every 3 [3,6,9]"},
		{-4.1,"every 4 [1,5,9,13]"},
		{-4.2,"every 4 [2,6,10,14]"},
		{-4.3,"every 4 [3,7,11,15]"},
		{-4.0,"every 4 [4,8,12,16]"},
		{11,"11"},
		{12,"12"},
		{13,"13"},
		{14,"14"},
		{15,"15"},
		{16,"16"},
		{17,"17"},
		{18,"18"},
		{19,"19"},
		{20,"20"},
	}
	local conditionsList = {
		{nil,"-"},
		{"target","Current Target"},
		{"focus","Focus"},
		{"mouseover","Mouseover"},
		{1,ExRT.F.GetRaidTargetText(1,20)},
		{2,ExRT.F.GetRaidTargetText(2,20)},
		{3,ExRT.F.GetRaidTargetText(3,20)},
		{4,ExRT.F.GetRaidTargetText(4,20)},
		{5,ExRT.F.GetRaidTargetText(5,20)},
		{6,ExRT.F.GetRaidTargetText(6,20)},
		{7,ExRT.F.GetRaidTargetText(7,20)},
		{8,ExRT.F.GetRaidTargetText(8,20)},
		{0,"No Mark"},
		{"boss1","boss1"},
		{"boss2","boss2"},
		{"boss3","boss3"},
		{"boss4","boss4"},
		{"boss5","boss5"},
	}
	if RAID_TARGET_USE_EXTRA then
		for i=16,9,-1 do
			tinsert(conditionsList,13,{i,ExRT.F.GetRaidTargetText(i,20)})
		end
	end
	local rolesList = {
		{"TANK","Tanks"},
		{"HEALER","Healers"},
		{"DAMAGER","DPS"},
		{"RDD","Ranged"},
		{"MDD","Melee"},
	}
	local soundsList = {
		--{nil,"-"},
	}
	do 
		for name, path in ExRT.F.IterateMediaData("sound") do
			soundsList[#soundsList + 1] = {
				path,
				name,
			}
		end

		sort(soundsList,function(a,b) return a[2]<b[2] end)
		tinsert(soundsList,1,{nil,"-"})
	end
	local diffsList = {
		{nil,"All"},
		{15,"Heroic"},
		{16,"Mythic"},
	}
	
	local function GetEncounterSortIndex(id,unk)
		for i=1,#encountersList do
			local dung = encountersList[i]
			for j=2,#dung do
				if id == dung[j] then
					return i * 100 + (#dung - j)
				end
			end
		end
		return unk
	end
	
	local ExpandedBosses = {}

	local SetupFrame
	local SetupFrameUpdate
	local SetupFrameData

	--local decorationLine = ELib:Frame(self):Point("TOPLEFT",self,0,-25):Point("BOTTOMRIGHT",self,"TOPRIGHT",0,-45):Texture(1,1,1,1):TexturePoint('x')
	--decorationLine.texture:SetGradientAlpha("VERTICAL",.24,.25,.30,1,.27,.28,.33,1)

	local chkEnable = ELib:Check(self,L.Enable,VExRT.Reminder.enabled):Point(560,-26):Size(18,18):AddColorState():OnClick(function(self) 
		VExRT.Reminder.enabled = self:GetChecked() 
		module:Update()
	end)
	
	self.tab = ELib:Tabs(self,0,L.cd2Spells,L.cd2Appearance):Point(0,-45):Size(698,570):SetTo(1)
	self.tab:SetBackdropBorderColor(0,0,0,0)
	self.tab:SetBackdropColor(0,0,0,0)

	local ListFrame = ELib:ScrollFrame(self.tab.tabs[1]):Size(690,530):Point("TOP",0,0)
	ELib:Border(ListFrame,0)
	ELib:DecorationLine(self):Point("TOP",ListFrame,"BOTTOM",0,0):Point("LEFT",self):Point("RIGHT",self):Size(0,1)
	
	local AddButton = ELib:Button(self.tab.tabs[1],"Add"):Point("TOPLEFT",ListFrame,"BOTTOMLEFT",2,-5):Size(100,20):OnClick(function()
		SetupFrameData = {}
		SetupFrame:Show()
	end)
	
	local SyncButton = ELib:Button(self.tab.tabs[1],"Send"):Point("TOPLEFT",AddButton,"BOTTOMLEFT",0,-5):Size(100,20):OnClick(function()
		module:Sync()
	end)
	
	SetupFrame = ELib:Popup(" "):Size(510,565):OnShow(function()
		if not SetupFrameData then
			SetupFrameData = {}
		end
		if SetupFrameUpdate then
			SetupFrameUpdate()
		end
	end)

	local function GetMapNameByID(mapID)
		return (C_Map.GetMapInfo(mapID or 0) or {}).name or ("Map ID "..mapID)
	end
	
	local bossList = ELib:DropDown(SetupFrame,200,15):AddText("Boss:"):Size(200):Point("TOPLEFT",150,-25)
	do
		local function bossList_SetValue(_,encounterID)
			SetupFrameData.boss = encounterID
			ELib:DropDownClose()
			SetupFrameUpdate()
		end
	
		local List = bossList.List
		for i=1,#encountersList do
			local instance = encountersList[i]
			List[#List+1] = {
				text = type(instance[1])=='string' and instance[1] or GetMapNameByID(instance[1]) or "???",
				isTitle = true,
			}
			for j=2,#instance do
				List[#List+1] = {
					text = L.bossName[ instance[j] ],
					arg1 = instance[j],
					func = bossList_SetValue,
				}
			end
		end
		List[#List+1] = {
			text = "Other",
			isTitle = true,
		}
		List[#List+1] = {
			text = "Other (always)",
			func = bossList_SetValue,
		}
	end
	
	local diffList = ELib:DropDown(SetupFrame,200,3):Size(100):Point("LEFT",bossList,"RIGHT",5,0)
	do
		local function diffList_SetValue(_,diff)
			SetupFrameData.diff = diff
			ELib:DropDownClose()
			SetupFrameUpdate()
		end
	
		local List = diffList.List
		for i=1,#diffsList do
			List[#List+1] = {
				text = diffsList[i][2],
				arg1 = diffsList[i][1],
				func = diffList_SetValue,
			}
		end
	end
	
	local nameEdit = ELib:Edit(SetupFrame):Size(200,20):Point("TOPLEFT",150,-50):OnChange(function(self,isUser)
		if not isUser then
			return
		end
		local text = self:GetText()
		if text == "" then
			text = nil
		end
		SetupFrameData.name = text
		SetupFrameUpdate()
	end)
	ELib:Text(nameEdit,"Name:",12):Point("RIGHT",nameEdit,"LEFT",-5,0):Right():Middle():Color():Shadow()
	
	local eventList = ELib:DropDown(SetupFrame,200,#eventsList):AddText("Event:"):Size(200):Point("TOPLEFT",150,-75)
	do
		local function eventList_SetValue(_,event)
			SetupFrameData.event = event
			ELib:DropDownClose()
			SetupFrameUpdate()
		end
		
		local List = eventList.List
		for i=1,#eventsList do
			List[#List+1] = {
				text = eventsList[i][2],
				arg1 = eventsList[i][1],
				func = eventList_SetValue,
			}
		end
	end
	
	local eventSIDSpellNameText
	local eventSIDEdit = ELib:Edit(SetupFrame,nil,true):Size(200,20):Point("TOPLEFT",150,-100):OnChange(function(self,isUser)
		local text = self:GetText()
		local sid = tonumber(text or "?")
		if sid and (SetupFrameData.event ~= "BOSS_PHASE" and SetupFrameData.event ~= "BOSS_HP" and SetupFrameData.event ~= "BOSS_MANA" and SetupFrameData.event ~= "BOSS_START") then
			local spellName,_,spellTexture = GetSpellInfo(sid)
			eventSIDSpellNameText:SetText((spellTexture and "|T"..spellTexture..":20|t " or "")..(spellName or ""))
		else
			eventSIDSpellNameText:SetText("")
		end
		if not isUser then
			return
		end
		if SetupFrameData.event == "BOSS_HP" and text:find("%.+$") then
			return
		end
		SetupFrameData.spellID = tonumber(text)
		SetupFrameUpdate()
	end)
	local eventSIDEditText = ELib:Text(eventSIDEdit,"Spell ID:",12):Point("RIGHT",eventSIDEdit,"LEFT",-5,0):Right():Middle():Color():Shadow()
	eventSIDSpellNameText = ELib:Text(eventSIDEdit,"",12):Point("LEFT",eventSIDEdit,"RIGHT",5,0):Size(0,20):Point("RIGHT",SetupFrame,"RIGHT",-5,0):Middle():Color():Shadow()
	
	local castList = ELib:DropDown(SetupFrame,200,#castsList-10):AddText("Cast #:"):Size(200):Point("TOPLEFT",150,-125)
	do
		local function castsList_SetValue(_,event)
			SetupFrameData.cast = event
			ELib:DropDownClose()
			SetupFrameUpdate()
		end
		
		local List = castList.List
		for i=1,#castsList do
			List[#List+1] = {
				text = castsList[i][2],
				arg1 = castsList[i][1],
				func = castsList_SetValue,
			}
		end
	end

	local useGlobalCounterCheck = ELib:Check(SetupFrame,"Global Counter"):Point("LEFT",castList,"RIGHT",5,0):Tooltip("Cast since the beginning of the fight, regardless of the actor"):OnClick(function(self)
		SetupFrameData.globalCounter = not SetupFrameData.globalCounter
		SetupFrameUpdate()
	end)

	local delayEdit = ELib:Edit(SetupFrame):Size(200,20):Point("TOPLEFT",150,-150):Tooltip("Comma separated"):OnChange(function(self,isUser)
		if not isUser then
			return
		end
		SetupFrameData.delay = self:GetText()
		SetupFrameUpdate()
	end)
	local delayEditText = ELib:Text(delayEdit,"Show after, seconds:",12):Point("RIGHT",delayEdit,"LEFT",-5,0):Right():Middle():Color():Shadow()
	
	local durationEdit = ELib:Edit(SetupFrame,nil,true):Size(200,20):Point("TOPLEFT",150,-175):OnChange(function(self,isUser)
		if not isUser then
			return
		end
		SetupFrameData.duration = tonumber(self:GetText())
		SetupFrameUpdate()
	end)
	ELib:Text(durationEdit,"Duration, seconds:",12):Point("RIGHT",durationEdit,"LEFT",-5,0):Right():Middle():Color():Shadow()

	local countdownCheck = ELib:Check(SetupFrame,"Countdown"):Point("LEFT",durationEdit,"RIGHT",5,0):OnClick(function(self)
		SetupFrameData.countdown = not SetupFrameData.countdown
		SetupFrameUpdate()
	end)

	local msgEdit = ELib:Edit(SetupFrame):Size(200,20):Point("TOPLEFT",150,-200):OnChange(function(self,isUser)
		if not isUser then
			return
		end
		local text = self:GetText()
		if text == "" then
			text = nil
		end
		SetupFrameData.msg = text
		SetupFrameUpdate()
	end)
	ELib:Text(msgEdit,"Message:",12):Point("RIGHT",msgEdit,"LEFT",-5,0):Right():Middle():Color():Shadow()

	local conditionList = ELib:DropDown(SetupFrame,200,#conditionsList):AddText("Condition:"):Size(200):Point("TOPLEFT",150,-225)
	do
		local function conditionList_SetValue(_,arg1)
			SetupFrameData.condition = arg1
			ELib:DropDownClose()
			SetupFrameUpdate()
		end
		
		local List = conditionList.List
		for i=1,#conditionsList do
			List[#List+1] = {
				text = conditionsList[i][2],
				arg1 = conditionsList[i][1],
				func = conditionList_SetValue,
			}
		end
	end

	local soundList = ELib:DropDown(SetupFrame,200,15):AddText("Sound:"):Size(200):Point("TOPLEFT",150,-250)
	do
		local function soundList_SetValue(_,arg1)
			SetupFrameData.sound = arg1
			ELib:DropDownClose()
			SetupFrameUpdate()
			if arg1 then
				PlaySoundFile(arg1, "Master")
			end
		end
		
		local List = soundList.List
		for i=1,#soundsList do
			List[#List+1] = {
				text = soundsList[i][2],
				arg1 = soundsList[i][1],
				func = soundList_SetValue,
			}
		end
	end

	
	local topPos = 275
	local playersChecks = {}
	local otherUnitsEdit
	local function CheckPlayerClick(self)
		local r = "#"
		local tmp = {}
		for i=1,6 do
			for j=1,5 do
				local cFrame = playersChecks[i][j]
				if cFrame.name and cFrame:GetChecked() then
					r = r .. cFrame.name .. "#"
					tmp[ cFrame.name ] = true
				end
			end
		end
		local allUnits = {strsplit(" ",otherUnitsEdit:GetText())}
		for i=1,#allUnits do
			local name = allUnits[i]
			if name ~= "" and not tmp[ name ] then
				r = r .. name .. "#"
				tmp[ name ] = true
			end
		end
		if r == "#" then
			r = nil
		end
		SetupFrameData.units = r
		SetupFrameUpdate()
	end
	for i=1,6 do
		playersChecks[i] = {}
		for j=1,5 do
			playersChecks[i][j] = ELib:Check(SetupFrame,"Player "..((i-1)*5+j)):Point("TOPLEFT",10+(j-1)*100,-topPos - (i-1)*25):OnClick(CheckPlayerClick)
			playersChecks[i][j].text:SetWidth(80)
			playersChecks[i][j].text:SetJustifyH("LEFT")
		end
	end
	
	local function CheckPlayerRole()
		local r = "#"
		for j=1,5 do
			local cFrame = playersChecks[7][j]
			if cFrame:GetChecked() then
				r = r .. cFrame.token .. "#"
			end
		end
		if r == "#" then
			r = nil
		end
		SetupFrameData.roles = r
		SetupFrameUpdate()  
	end
	
	playersChecks[7] = {}
	for i=1,#rolesList do
		playersChecks[7][i] = ELib:Check(SetupFrame,rolesList[i][2]):Point("TOPLEFT",10+(i-1)*100,-topPos - (7-1)*25):OnClick(CheckPlayerRole)
		playersChecks[7][i].text:SetWidth(80)
		playersChecks[7][i].text:SetJustifyH("LEFT")
		
		playersChecks[7][i].token = rolesList[i][1]
	end
	
	playersChecks[8] = ELib:Check(SetupFrame,"All players"):Point("TOPLEFT",10+(1-1)*100,-topPos - (8-1)*25):OnClick(function(self)
		self:SetChecked(true)
		SetupFrameData.roles = nil
		SetupFrameData.units = nil
		SetupFrameUpdate()
	end)
	playersChecks[8].text:SetWidth(80)
	playersChecks[8].text:SetJustifyH("LEFT")
	
	otherUnitsEdit = ELib:Edit(SetupFrame):Size(490,20):Point("TOP",0,-topPos - (9-1)*25):Tooltip("Custom players")


	topPos = topPos + 9 * 25

	local notePatternEdit = ELib:Edit(SetupFrame):Size(200,20):Point("TOPLEFT",150,-topPos):Tooltip('Start of the note; all players in this line will be displayed, e.g.: "|cff00ff001. |r"'):OnChange(function(self,isUser)
		if not isUser then
			return
		end
		local text = self:GetText()
		if text == "" then
			text = nil
		else
			text = text:gsub("%^","")
		end
		SetupFrameData.notepat = text
		SetupFrameUpdate()
	end)
	ELib:Text(notePatternEdit,"Note template:",12):Point("RIGHT",notePatternEdit,"LEFT",-5,0):Right():Middle():Color():Shadow()
	local notePatternCurr = ELib:Text(notePatternEdit,"",12):Point("LEFT",notePatternEdit,"RIGHT",5,0):Size(0,20):Point("RIGHT",SetupFrame,"RIGHT",-5,0):Middle():Color():Shadow():Tooltip()

	local SaveButton = ELib:Button(SetupFrame,"Save"):Point("BOTTOM",0,10):Size(200,20):OnClick(function()
		SetupFrame:Hide()
		
		CheckPlayerClick()
		
		if not SetupFrameData.token then
			SetupFrameData.token = time() + GetTime() % 1
		end
		
		SetupFrameData.notSync = true

		if SetupFrameData.event == "BOSS_START" then
			SetupFrameData.spellID = 0
		end
		
		VExRT.Reminder.data[ SetupFrameData.token ] = SetupFrameData
		
		CreateFunctions()
		
		ExpandedBosses[SetupFrameData.boss or -1] = true
		
		SetupFrameData = nil
		module.options:Hide()
		module.options:Show()
	end)
	
	local function RemoveFromList(table,val)
		for i=#table,1,-1 do
			if table[i]==val then
				tremove(table,i)
			end
		end	
	end

	SetupFrame.QuickList = ELib:ScrollTableList(SetupFrame,90,50,0,40,65,25,90,90):Size(580,500):Point("LEFT",SetupFrame,"RIGHT",0,0):FontSize(11)
	function SetupFrame.QuickList:UpdateAdditional()
		for i=1,#self.List do
			self.List[i].text3:SetWordWrap(false)
			self.List[i].text6:SetWordWrap(false)
			self.List[i].text7:SetWordWrap(false)
		end
	end
	SetupFrame.QuickList.Background = SetupFrame.QuickList:CreateTexture(nil,"BACKGROUND")
	SetupFrame.QuickList.Background:SetColorTexture(0,0,0,.9)
	SetupFrame.QuickList.Background:SetPoint("TOPLEFT")
	SetupFrame.QuickList.Background:SetPoint("BOTTOMRIGHT")

	SetupFrame.QuickList.additionalLineFunctions = true
	function SetupFrame.QuickList:HoverMultitableListValue(isEnter,index,obj)
		if not isEnter then
			local line = obj.parent:GetParent()
			--line:GetScript("OnLeave")(line)
			line.HighlightTexture2:Hide()

			GameTooltip_Hide()
		else
			local line = obj.parent:GetParent()
			--line:GetScript("OnEnter")(line)
			if not line.HighlightTexture2 then
				line.HighlightTexture2 = line:CreateTexture()
				line.HighlightTexture2:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
				line.HighlightTexture2:SetBlendMode("ADD")
				line.HighlightTexture2:SetPoint("LEFT",0,0)
				line.HighlightTexture2:SetPoint("RIGHT",0,0)
				line.HighlightTexture2:SetHeight(15)
				line.HighlightTexture2:SetVertexColor(1,1,1,1)
			end
			line.HighlightTexture2:Show()

			local data = line.table
			if index == 3 then
				if data.notspell then
					return
				end
				GameTooltip:SetOwner(obj,"ANCHOR_CURSOR")
				GameTooltip:SetHyperlink("spell:"..data[2] )
				GameTooltip:Show()
			elseif index == 4 or index == 5 then
				GameTooltip:SetOwner(obj,"ANCHOR_CURSOR")
				GameTooltip:AddLine(index == 4 and "Time since pull" or "Time since phase start")
				local text = obj.parent:GetText()
				if text then
					local min,sec = text:match("(%d+):(%d+)")
					local insec = tonumber(min)*60 + tonumber(sec)
					GameTooltip:AddLine("Seconds: "..insec)
				end
				GameTooltip:Show()
			elseif index == 6 then
				GameTooltip:SetOwner(obj,"ANCHOR_CURSOR")
				GameTooltip:AddLine("Time since previous such event")
				GameTooltip:Show()
			elseif index == 2 then
				GameTooltip:SetOwner(obj,"ANCHOR_CURSOR")
				GameTooltip:AddLine("Spell ID")
				GameTooltip:Show()
			else
				if obj.parent:IsTruncated() then
					GameTooltip:SetOwner(obj,"ANCHOR_CURSOR")
					GameTooltip:AddLine(obj.parent:GetText() )
					GameTooltip:Show()
				end
			end
		end
	end
	function SetupFrame.QuickList:ClickMultitableListValue(index,obj)
		local data = obj:GetParent().table
		if not data then
			return
		end
		local spellID = data[2]
		local event = data.event
		if event == "PHASE" then event = "BOSS_PHASE" end

		SetupFrameData.spellID = tonumber(spellID)
		SetupFrameData.event = event

		if index == 4 then
			SetupFrameData.event = "BOSS_START"
			SetupFrameData.delay = floor(data.timeFromStart)
		elseif index == 5 then
			SetupFrameData.event = "BOSS_PHASE"
			SetupFrameData.delay = floor(data.timeFromStart)
			SetupFrameData.spellID = data.phase
		elseif index == 6 and data.timeFromPrev then
			SetupFrameData.delay = floor(data.timeFromPrev[1])
			SetupFrameData.cast = data.timeFromPrev[2]
		end

		SetupFrameUpdate()
	end

	SetupFrame.QuickList.AurasChk = ELib:Check(SetupFrame.QuickList,"Add aura events"):Point("BOTTOMLEFT",'x',"TOPLEFT",5,4):Scale(.7):OnClick(function()
		SetupFrameUpdate()
	end)

	SetupFrame.QuickList.AllEventsChk = ELib:Check(SetupFrame.QuickList,"All events (ignore current)"):Point("BOTTOMLEFT",'x',"TOPLEFT",205,4):Scale(.7):OnClick(function()
		SetupFrameUpdate()
	end)


	local function FormatTime(t)
		return format("%d:%02d",t/60,t%60)
	end
	local function FormatName(name,flags)
		if not name and not flags then
			return
		elseif name and flags then
			if UnitClass(name) then
				name = "|c" .. RAID_CLASS_COLORS[select(2,UnitClass(name))].colorStr .. name
			end
			local mark = FlagMarkToIndex[flags]
			if mark and mark > 0 then
				name = ExRT.F.GetRaidTargetText(mark).." " .. name
			end	
			return name		
		elseif flags then
			local mark = FlagMarkToIndex[flags]
			if mark and mark > 0 then
				return ExRT.F.GetRaidTargetText(mark)
			end
		else
			if UnitClass(name) then
				name = "|c" .. RAID_CLASS_COLORS[select(2,UnitClass(name))].colorStr .. name
			end
			return name
		end
	end
	local function UpdateHistory()
		local phaseNow = 1
		local startTime = history[1] and history[1][1] or 0
		local phaseTime = startTime
		local counter = {cs={},ce={},aa={},ar={}}
		local prev = {cs={},ce={},aa={},ar={}}

		local result = {}

		local line, prevNow
		for i=2,#history do
			line = history[i]

			prevNow = nil

			if line[2] == "SPELL_CAST_START" then
				counter.cs[ line[4] ] = counter.cs[ line[4] ] or {}
				counter.cs[ line[4] ][ line[3] ] = (counter.cs[ line[4] ][ line[3] ] or 0) + 1

				prev.cs[ line[4] ] = prev.cs[ line[4] ] or {}
				prevNow = prev.cs[ line[4] ][ line[3] ]
				prev.cs[ line[4] ][ line[3] ] = line[1]
			elseif line[2] == "SPELL_CAST_SUCCESS" then
				counter.ce[ line[4] ] = counter.ce[ line[4] ] or {}
				counter.ce[ line[4] ][ line[3] ] = (counter.ce[ line[4] ][ line[3] ] or 0) + 1

				prev.ce[ line[4] ] = prev.ce[ line[4] ] or {}
				prevNow = prev.ce[ line[4] ][ line[3] ]
				prev.ce[ line[4] ][ line[3] ] = line[1]
			elseif line[2] == "SPELL_AURA_APPLIED" then
				counter.aa[ line[4] ] = counter.aa[ line[4] ] or {}
				counter.aa[ line[4] ][ line[3] ] = (counter.aa[ line[4] ][ line[3] ] or 0) + 1

				prev.aa[ line[4] ] = prev.aa[ line[4] ] or {}
				prevNow = prev.aa[ line[4] ][ line[3] ]
				prev.aa[ line[4] ][ line[3] ] = line[1]
			elseif line[2] == "SPELL_AURA_REMOVED" then
				counter.ar[ line[4] ] = counter.ar[ line[4] ] or {}
				counter.ar[ line[4] ][ line[3] ] = (counter.ar[ line[4] ][ line[3] ] or 0) + 1

				prev.ar[ line[4] ] = prev.ar[ line[4] ] or {}
				prevNow = prev.ar[ line[4] ][ line[3] ]
				prev.ar[ line[4] ][ line[3] ] = line[1]
			end

			if line[2] == "PHASE" then
				phaseTime = line[1]
				phaseNow = line[3]

				result[#result+1] = {"Boss phase",line[3],nil,FormatTime(line[1]-startTime),notspell=true,event=line[2]}
			elseif line[2] == "SPELL_CAST_START" and (SetupFrameData.event == "SPELL_CAST_START" or (SetupFrameData.event == "BOSS_PHASE" and tostring(phaseNow) == tostring(SetupFrameData.spellID)) or SetupFrameData.event == "BOSS_START" or not SetupFrameData.event or SetupFrame.QuickList.AllEventsChk:GetChecked()) then
				local spellName,_,spellTexture = GetSpellInfo(line[3])
				result[#result+1] = {"Cast start",line[3],counter.cs[ line[4] ][ line[3] ].." |T"..spellTexture..":0|t "..spellName,FormatTime(line[1]-startTime),"["..phaseNow.."] "..FormatTime(line[1]-phaseTime),prevNow and format("%d",line[1]-prevNow),FormatName(line[5],line[7]),FormatName(line[9],line[11]),
					event=line[2],timeFromStart=line[1]-startTime,timeFromPhase=line[1]-phaseTime,phase=phaseNow,timeFromPrev=prevNow and {line[1]-prevNow,counter.cs[ line[4] ][ line[3] ]-1}
				}
			elseif line[2] == "SPELL_CAST_SUCCESS" and (SetupFrameData.event == "SPELL_CAST_SUCCESS" or (SetupFrameData.event == "BOSS_PHASE" and tostring(phaseNow) == tostring(SetupFrameData.spellID)) or SetupFrameData.event == "BOSS_START" or not SetupFrameData.event or SetupFrame.QuickList.AllEventsChk:GetChecked()) then
				local spellName,_,spellTexture = GetSpellInfo(line[3])
				result[#result+1] = {"Cast success",line[3],counter.ce[ line[4] ][ line[3] ].." |T"..spellTexture..":0|t "..spellName,FormatTime(line[1]-startTime),"["..phaseNow.."] "..FormatTime(line[1]-phaseTime),prevNow and format("%d",line[1]-prevNow),FormatName(line[5],line[7]),FormatName(line[9],line[11]),
					event=line[2],timeFromStart=line[1]-startTime,timeFromPhase=line[1]-phaseTime,phase=phaseNow,timeFromPrev=prevNow and {line[1]-prevNow,counter.ce[ line[4] ][ line[3] ]-1}
				}
			elseif line[2] == "SPELL_AURA_APPLIED" and (SetupFrameData.event == "SPELL_AURA_APPLIED" or (SetupFrame.QuickList.AurasChk:GetChecked() and SetupFrameData.event == "BOSS_PHASE" and tostring(phaseNow) == tostring(SetupFrameData.spellID)) or (SetupFrame.QuickList.AurasChk:GetChecked() and (SetupFrameData.event == "BOSS_START" or not SetupFrameData.event)) or (SetupFrame.QuickList.AurasChk:GetChecked() and SetupFrame.QuickList.AllEventsChk:GetChecked())) then
				local spellName,_,spellTexture = GetSpellInfo(line[3])
				result[#result+1] = {"Aura applied",line[3],counter.aa[ line[4] ][ line[3] ].." |T"..spellTexture..":0|t "..spellName,FormatTime(line[1]-startTime),"["..phaseNow.."] "..FormatTime(line[1]-phaseTime),prevNow and format("%d",line[1]-prevNow),FormatName(line[5],line[7]),FormatName(line[9],line[11]),
					event=line[2],timeFromStart=line[1]-startTime,timeFromPhase=line[1]-phaseTime,phase=phaseNow,timeFromPrev=prevNow and {line[1]-prevNow,counter.aa[ line[4] ][ line[3] ]-1}
				}
			elseif line[2] == "SPELL_AURA_REMOVED" and (SetupFrameData.event == "SPELL_AURA_REMOVED" or (SetupFrame.QuickList.AurasChk:GetChecked() and SetupFrameData.event == "BOSS_PHASE" and tostring(phaseNow) == tostring(SetupFrameData.spellID)) or (SetupFrame.QuickList.AurasChk:GetChecked() and (SetupFrameData.event == "BOSS_START" or not SetupFrameData.event)) or (SetupFrame.QuickList.AurasChk:GetChecked() and SetupFrame.QuickList.AllEventsChk:GetChecked())) then
				local spellName,_,spellTexture = GetSpellInfo(line[3])
				result[#result+1] = {"Aura removed",line[3],counter.ar[ line[4] ][ line[3] ].." |T"..spellTexture..":0|t "..spellName,FormatTime(line[1]-startTime),"["..phaseNow.."] "..FormatTime(line[1]-phaseTime),prevNow and format("%d",line[1]-prevNow),FormatName(line[5],line[7]),FormatName(line[9],line[11]),
					event=line[2],timeFromStart=line[1]-startTime,timeFromPhase=line[1]-phaseTime,phase=phaseNow,timeFromPrev=prevNow and {line[1]-prevNow,counter.ar[ line[4] ][ line[3] ]-1}
				}
			end
		end

		SetupFrame.QuickList.L = result
		SetupFrame.QuickList:Update()
	end
	
	function SetupFrameUpdate()
		bossList:SetText(SetupFrameData.boss and L.bossName[ SetupFrameData.boss ] or "Always")
		
		eventList:SetText("")
		local anyEvent
		for i=1,#eventsList do
			if eventsList[i][1] == SetupFrameData.event then
				eventList:SetText(eventsList[i][2])
				anyEvent = true
				break
			end
		end
		eventSIDEdit:SetNumeric(true)
		if SetupFrameData.event == "BOSS_PHASE" then
			eventSIDEditText:SetText("Phase number:")
			eventSIDEdit:Show()
			useGlobalCounterCheck:Hide()
		elseif SetupFrameData.event == "BOSS_START" then
			eventSIDEditText:SetText("")
			eventSIDEdit:Hide()
			useGlobalCounterCheck:Hide()
		elseif SetupFrameData.event == "BOSS_HP" then			
			eventSIDEditText:SetText("Less than %boss hp:")
			eventSIDEdit:Show()
			eventSIDEdit:SetNumeric(false)
			useGlobalCounterCheck:Hide()
		elseif SetupFrameData.event == "BOSS_MANA" then			
			eventSIDEditText:SetText("More than %boss energy:")
			eventSIDEdit:Show()
			eventSIDEdit:SetNumeric(false)
			useGlobalCounterCheck:Hide()
		else
			eventSIDEditText:SetText("Spell ID:")
			eventSIDEdit:Show()
			useGlobalCounterCheck:Show()
		end

		if SetupFrameData.event == "BW_TIMER" then
			delayEditText:SetText("Remaining timer:")
		else
			delayEditText:SetText("Display in, seconds:")
		end
		
		diffList:SetText("All")
		for i=1,#diffsList do
			if diffsList[i][1] == SetupFrameData.diff then
				diffList:SetText(diffsList[i][2])
				break
			end
		end
		
		castList:SetText("All")
		for i=1,#castsList do
			if castsList[i][1] == SetupFrameData.cast then
				castList:SetText(castsList[i][2])
				break
			end
		end
		
		conditionList:SetText("-")
		for i=1,#conditionsList do
			if conditionsList[i][1] == SetupFrameData.condition then
				conditionList:SetText(conditionsList[i][2])
				break
			end
		end
		
		soundList:SetText("-")
		for i=1,#soundsList do
			if soundsList[i][1] == SetupFrameData.sound then
				soundList:SetText(soundsList[i][2])
				break
			end
		end
		
		eventSIDEdit:SetText(SetupFrameData.spellID or "")
		delayEdit:SetText(SetupFrameData.delay or "")
		durationEdit:SetText(SetupFrameData.duration or "")
		msgEdit:SetText(SetupFrameData.msg or "")
		nameEdit:SetText(SetupFrameData.name or "")

		countdownCheck:SetChecked(SetupFrameData.countdown)
		useGlobalCounterCheck:SetChecked(SetupFrameData.globalCounter)

		for i=1,6 do
			playersChecks[i].c = 0
		end
		
		local allUnits = {strsplit("#",SetupFrameData.units or "")}
		RemoveFromList(allUnits,"")
		sort(allUnits)

		for _, name, subgroup, class in ExRT.F.IterateRoster, 6 do
			playersChecks[subgroup].c = playersChecks[subgroup].c + 1
			local cFrame = playersChecks[subgroup][ playersChecks[subgroup].c ]
			
			name = ExRT.F.delUnitNameServer(name)
			
			cFrame:SetText("|c"..ExRT.F.classColor(class)..name)
			local isChecked = SetupFrameData.units and SetupFrameData.units:find("#"..name.."#")
			cFrame:SetChecked(isChecked)
			
			RemoveFromList(allUnits,name)
			
			cFrame.name = name
			cFrame:Show()
		end
		
		otherUnitsEdit:SetText(strjoin(" ",unpack(allUnits)))
		
		for i=1,6 do
			for j=playersChecks[i].c+1,5 do
				local cFrame = playersChecks[i][j]
				cFrame.name = nil
				cFrame:Hide()
			end
		end
		
		for i=1,#rolesList do
			local cFrame = playersChecks[7][i]
			
			local isChecked = SetupFrameData.roles and SetupFrameData.roles:find("#"..cFrame.token.."#")
			cFrame:SetChecked(isChecked)
		end

		playersChecks[8]:SetChecked(not SetupFrameData.units and not SetupFrameData.roles)

		notePatternEdit:SetText(SetupFrameData.notepat or "")
		if SetupFrameData.notepat then
			local isOkay,list = pcall(FindPlayersListInNote,SetupFrameData.notepat)
			if isOkay and list then
				list = list:gsub("([%S]+)",function(name)
					if not UnitName(name) then
						return "|cffaaaaaa"..name.."|r"
					end
				end)
			end
			notePatternCurr:SetText(isOkay and list or "---")
		else
			notePatternCurr:SetText("")
		end
		
		if not SetupFrameData.duration then
			durationEdit:ColorBorder(true)
		else
			durationEdit:ColorBorder()
		end

		if not SetupFrameData.msg then
			msgEdit:ColorBorder(true)
		else
			msgEdit:ColorBorder()
		end

		if not SetupFrameData.spellID and SetupFrameData.event ~= "BOSS_START" then
			eventSIDEdit:ColorBorder(true)
		else
			eventSIDEdit:ColorBorder()
		end
		
		if not anyEvent or (not SetupFrameData.spellID and SetupFrameData.event ~= "BOSS_START") or not SetupFrameData.duration or not SetupFrameData.msg then
			SaveButton:Disable()
		else
			SaveButton:Enable()
		end

		UpdateHistory()
	end
	
	local function DeleteData(self)
		local parent = self:GetParent()
		if not parent.data then
			return
		end
		local token = parent.data.token
		VExRT.Reminder.data[ token ] = nil
		module.options:Hide()
		module.options:Show()
		
		ExRT.F.SendExMsg("reminder","R\t"..token)
		
		CreateFunctions()
	end
	local function EditData(self)
		local parent = self:GetParent()
		if not parent.data then
			return
		end
		SetupFrameData = ExRT.F.table_copy2(parent.data)
		SetupFrame:Show()
	end
	local function CheckData(self)
		local parent = self:GetParent()
		if not parent.data then
			return
		end
		VExRT.Reminder.disabled[ parent.data.token ] = not self:GetChecked()
		
		CreateFunctions()
	end
	local function DuplicateData(self)
		local parent = self:GetParent()
		if not parent.data then
			return
		end
		local token = time() + GetTime() % 1
		VExRT.Reminder.data[ token ] = ExRT.F.table_copy2(parent.data)
		VExRT.Reminder.data[ token ].token = token
		VExRT.Reminder.data[ token ].notSync = true
		module.options:Hide()
		module.options:Show()
		
		CreateFunctions()
	end
	local function CheckLock(self)
		local parent = self:GetParent()
		if not parent.data then
			return
		end
		VExRT.Reminder.locked[ parent.data.token ] = self:GetChecked()
	end
		
	local function ListFrameLineMode(self,mode)
		local isExpandMode = mode == 2
		self.chk:SetShown(not isExpandMode)
		self.boss:SetShown(not isExpandMode)
		self.boss.TooltipFrame:SetShown(not isExpandMode)
		self.name:SetShown(not isExpandMode)
		self.name.TooltipFrame:SetShown(not isExpandMode)
		self.msg:SetShown(not isExpandMode)
		self.msg.TooltipFrame:SetShown(not isExpandMode)
		self.edit:SetShown(not isExpandMode)
		self.duplicate:SetShown(not isExpandMode)
		self.delete:SetShown(not isExpandMode)
		self.notSync:SetShown(not isExpandMode)
		self.chk_lock:SetShown(not isExpandMode)

		self.expandIcon:SetShown(isExpandMode)
		self.expandBoss:SetShown(isExpandMode)
		self.bossImg:SetShown(isExpandMode)
		
		self.isExpandMode = isExpandMode
	end
	
	local function ListFrameLine_OnClick(self)
		if not self.data then return end
		ExpandedBosses[self.data] = not ExpandedBosses[self.data]
		module.options:Hide()
		module.options:Show()
	end
	local function ListFrameLine_OnEnter(self)
		if not self.isExpandMode then return end
		self.back:SetColorTexture(.5,.5,.5,.3)
	end
	local function ListFrameLine_OnLeave(self)
		if not self.isExpandMode then return end
		if self.index % 2 == 0 then
			self.back:SetColorTexture(.4,.4,.4,.07)
		else
			self.back:SetColorTexture(.4,.4,.4,0)
		end
	end
	
	ListFrame.lines = {}
	local function GetListFrameLine(i)
		local line = ListFrame.lines[i]
		if not line then
			line = CreateFrame("Button",nil,ListFrame.C)
			ListFrame.lines[i] = line
			line:SetPoint("TOPLEFT",0,-20*(i-1))
			line:SetPoint("BOTTOMRIGHT",ListFrame.C,"TOPRIGHT",0,-20*i)
			
			line.chk = ELib:Check(line):Point("LEFT",5,0):OnClick(CheckData):Tooltip("In disabled state the Reminder will not be shown.\nThis setting affects only you; is not displayed when syncing")
			line.chk:defSetSize(14,14)
			line.boss = ELib:Text(line):Point("LEFT",30,0):Size(110,20):Tooltip("ANCHOR_LEFT")
			line.name = ELib:Text(line):Point("LEFT",line.boss,"RIGHT",5,0):Size(125,20):Tooltip("ANCHOR_LEFT")
			line.msg = ELib:Text(line):Point("LEFT",line.name,"RIGHT",5,0):Size(155,20):Tooltip("ANCHOR_LEFT")
			
			line.chk_lock = ELib:Check(line):Point("LEFT",line.msg,"RIGHT",5,0):OnClick(CheckLock):Tooltip("Lock\nAny incoming updates will be ignored for this reminder")
			line.chk_lock:defSetSize(14,14)

			line.edit = ELib:Button(line,"Edit"):FontSize(10):Point("LEFT",line.chk_lock,"RIGHT",5,0):Size(52,16):OnClick(EditData)
			line.duplicate = ELib:Button(line,"Duplicate"):FontSize(10):Point("LEFT",line.edit,"RIGHT",5,0):Size(52,16):OnClick(DuplicateData)
			line.delete = ELib:Button(line,"Delete"):FontSize(10):Point("LEFT",line.duplicate,"RIGHT",5,0):Size(52,16):OnClick(DeleteData)
			
			line.notSync = ELib:Text(line,"***",18):Point("LEFT",line.delete,"RIGHT",5,0):Size(160,20)
			
			line.expandIcon = ELib:Icon(line,"Interface\\AddOns\\MRT\\media\\DiesalGUIcons16x256x128",18):Point("LEFT",5,0)
			line.expandIcon.texture:SetTexCoord(0.25,0.3125,0.5,0.625)
			line.expandBoss = ELib:Text(line):Point("LEFT",30,0):Size(0,20)
			
			line.back = line:CreateTexture(nil,"BACKGROUND")
			line.back:SetAllPoints()
			if i % 2 == 0 then
				line.back:SetColorTexture(1,1,1,.07)
			end

			line.bossImg = line:CreateTexture(nil, "ARTWORK")
			line.bossImg:SetSize(22,22)
			line.bossImg:SetPoint("LEFT",line.expandBoss,"RIGHT",10,0)
			
			line.index = i
			line.SetMode = ListFrameLineMode
			line:SetScript("OnClick",ListFrameLine_OnClick)
			line:SetScript("OnEnter",ListFrameLine_OnEnter)
			line:SetScript("OnLeave",ListFrameLine_OnLeave)
		end
		
		return line
	end
	
	local function CheckRole(roles,role1, role2)
		if role1 ~= "DAMAGER" then
			if roles:find("#"..role1.."#") then
				return true
			end
		else
			if roles:find("#"..role1.."#") then
				return true
			elseif roles:find("#"..role2.."#") then
				return true
			end
		end
	end
	
	ListFrame:OnShow(function()
		local list = {}
		for token,data in pairs(VExRT.Reminder.data) do
			list[#list+1] = {
				data = data,
				token = token,
				msg = data.msg,
				boss = data.boss,
				name = data.name,
				sort = data.name or data.msg,
			}
		end
		sort(list,function(a,b)
			if (a.boss ~= b.boss) then 
				return GetEncounterSortIndex(a.boss,a.token) < GetEncounterSortIndex(b.boss,b.token)		
			elseif (a.sort ~= b.sort) then
				return (a.sort) < (b.sort)
			else
				return (a.token) < (b.token)
			end
		end)
		local prevBoss = nil
		local listIndex = 1
		while list[listIndex] do
			if list[listIndex].boss ~= prevBoss then
				tinsert(list,listIndex,{
					boss = list[listIndex].boss,
					isExpand = true,
				})
			end
			prevBoss = list[listIndex].boss
			listIndex = listIndex + 1
		end

		local role1, role2 = GetPlayerRole()
		listIndex = 0
		for i=1,#list do
			if list[i].isExpand or ExpandedBosses[ list[i].boss or -1 ] then
				listIndex = listIndex + 1
				local line = GetListFrameLine(listIndex)
				local data = list[i].data
				
				if list[i].isExpand then
					line:SetMode(2)
					
					local bossID = list[i].boss or -1
					line.data = bossID
					if ExpandedBosses[bossID] then
						line.expandIcon.texture:SetTexCoord(0.25,0.3125,0.5,0.625)	--Down
					else
						line.expandIcon.texture:SetTexCoord(0.375,0.4375,0.5,0.625)	--Right
					end
					
					line.expandBoss:SetText(list[i].boss and L.bossName[ list[i].boss ] or "Всегда")
					
					if line.index % 2 == 0 then
						line.back:SetColorTexture(.4,.4,.4,.07)
					else
						line.back:SetColorTexture(.4,.4,.4,0)
					end

					if ExRT.GDB.encounterIDtoEJ[bossID] then
						local displayInfo = select(4, EJ_GetCreatureInfo(1, ExRT.GDB.encounterIDtoEJ[bossID]))
						if displayInfo then
							SetPortraitTextureFromCreatureDisplayID(line.bossImg, displayInfo)
						else
							line.bossImg:SetTexture("")
						end
					else
						line.bossImg:SetTexture("")
					end
				else
					line:SetMode(1)
					
					line.chk:SetChecked(not VExRT.Reminder.disabled[ data.token ])
					
					line.chk_lock:SetChecked(VExRT.Reminder.locked[ data.token ])
					line.boss:SetText(data.boss and L.bossName[ data.boss ] or "Always")
					line.msg:SetText(FormatMsg(data.msg))
					line.name:SetText(data.name or "")
					line.data = data
					
					if data.notSync then
						line.notSync:Show()
					else
						line.notSync:Hide()
					end
					
					local isNoteOn,isInNote
					if data.notepat then
						isNoteOn = true
						isInNote = FindPlayerInNote(data.notepat)
					end
					if 
						(isNoteOn and isInNote) or
						(not isNoteOn and 
							(not data.units or data.units:find("#"..playerName.."#")) and
							(not data.roles or CheckRole(data.roles, role1, role2))
						)
					then
						if line.index % 2 == 0 then
							line.back:SetColorTexture(0,1,0,.11)
						else
							line.back:SetColorTexture(0,1,0,.07)
						end			
					else
						if line.index % 2 == 0 then
							line.back:SetColorTexture(1,0,0,.11)
						else
							line.back:SetColorTexture(1,0,0,.07)
						end
					end			
				end
				
				line:Show()
			end
		end
		for i=listIndex+1,#ListFrame.lines do
			ListFrame.lines[i]:Hide()
		end
		ListFrame:Height(listIndex*20)
	end)
	
	self.lastUpdate = ELib:Text(self.tab.tabs[1],"",11):Point("LEFT",AddButton,"RIGHT",10,0):Color()
	self.lastUpdate.Update = function()
		if VExRT.Reminder.LastUpdateName and VExRT.Reminder.LastUpdateTime then
			self.lastUpdate:SetText( L.NoteLastUpdate..": "..VExRT.Reminder.LastUpdateName.." ("..date("%H:%M:%S %d.%m.%Y",VExRT.Reminder.LastUpdateTime)..")" )
		end
	end
	self.lastUpdate:Update()

	local ResetForAllButton = ELib:Button(self.tab.tabs[1],"Delete all"):Point("TOPRIGHT",ListFrame,"BOTTOMRIGHT",-2,-30):Size(120,20):OnClick(function()
		wipe(VExRT.Reminder.data)

		module.options:Hide()
		module.options:Show()
	end)
	
	local ExportButton = ELib:Button(self.tab.tabs[1],"Export"):Point("RIGHT",ResetForAllButton,"LEFT",-5,0):Size(80,20):OnClick(function()
		local export = module:Sync(true)
		ExRT.F:Export(export)
	end)
	
	local exportWindow
	local ImportButton = ELib:Button(self.tab.tabs[1],"Import"):Point("RIGHT",ExportButton,"LEFT",-5,0):Size(80,20):OnClick(function()
		if not exportWindow then
			exportWindow = ELib:Popup("Import"):Size(650,615)
			exportWindow.Edit = ELib:MultiEdit(exportWindow):Point("TOP",0,-20):Size(640,570)
			exportWindow.Save = ELib:Button(exportWindow,"Import"):Point("BOTTOM",0,5):Size(100,20):OnClick(function()
				exportWindow:Hide()
				if IsShiftKeyDown() then
					wipe(VExRT.Reminder.data)
				end
				ProcessTextToData(exportWindow.Edit:GetText(),true)
			end)
		end
		exportWindow.Edit:SetText("")
		exportWindow:NewPoint("CENTER",UIParent,0,0)
		exportWindow:Show()
		exportWindow.Edit.EditBox:SetFocus()
	end)
	
	self.chkLock = ELib:Check(self.tab.tabs[2],L.cd2fix,not VExRT.Reminder.lock):Point(10,-10):OnClick(function(self) 
		VExRT.Reminder.lock = not self:GetChecked()
		module:UpdateVisual()
	end)
	
	self.disableSound = ELib:Check(self.tab.tabs[2],"Disable sound",VExRT.Reminder.disableSound):Point(10,-35):OnClick(function(self) 
		VExRT.Reminder.disableSound = self:GetChecked()
	end)
	
	self.sliderFontSize = ELib:Slider(self.tab.tabs[2],L.NoteFontSize):Size(300):Point(10,-70):Range(12,200):SetTo(VExRT.Reminder.FontSize or 72):OnChange(function(self,event) 
		event = floor(event + .5)
		VExRT.Reminder.FontSize = event
		module:UpdateVisual()
		self.tooltipText = event
		self:tooltipReload(self)
	end)

	local function dropDownFontSetValue(_,arg1)
		ELib:DropDownClose()
		VExRT.Reminder.Font = arg1
		self.dropDownFont:SetText(arg1)
		module:UpdateVisual()
	end

	self.dropDownFont = ELib:DropDown(self.tab.tabs[2],350,10):Size(320):Point(40,-100):SetText(VExRT.Reminder.Font or ExRT.F.defFont):AddText("Font:")
	for i=1,#ExRT.F.fontList do
		local info = {}
		self.dropDownFont.List[i] = info
		info.text = ExRT.F.fontList[i]
		info.arg1 = ExRT.F.fontList[i]
		info.func = dropDownFontSetValue
		info.font = ExRT.F.fontList[i]
		info.justifyH = "CENTER" 
	end
	for key,font in ExRT.F.IterateMediaData("font") do
		local info = {}
		self.dropDownFont.List[#self.dropDownFont.List+1] = info
		
		info.text = key
		info.arg1 = font
		info.func = dropDownFontSetValue
		info.font = font
		info.justifyH = "CENTER" 
	end
end

function module.main:ADDON_LOADED()
	VExRT = _G.VExRT
	VExRT.Reminder = VExRT.Reminder or {enabled=true}
	VExRT.Reminder.data = VExRT.Reminder.data or {}
	VExRT.Reminder.disabled = VExRT.Reminder.disabled or {}
	VExRT.Reminder.locked = VExRT.Reminder.locked or {}

	if VExRT.Reminder.Left and VExRT.Reminder.Top then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",VExRT.Reminder.Left,VExRT.Reminder.Top)
	end
	
	module:Update()
	module:UpdateVisual()
	module:RegisterAddonMessage()
end

local function BossPhaseCheck(phase,phaseCount)
	if not ActiveEncounter or not CLEU_BOSS_PHASE[ActiveEncounter] or not CLEU_BOSS_PHASE[ActiveEncounter][phase] then
		return
	end
	ActivePhase = phase
	local ff = CLEU_BOSS_PHASE[ActiveEncounter][phase]
	for i=1,#ff do
		local f = ff[i]
		f(phaseCount or 0,"",0,ActiveEncounterStart)
	end
end
local function BossPullCheck()
	if not ActiveEncounter or not CLEU_BOSS_START[ActiveEncounter] or not CLEU_BOSS_START[ActiveEncounter] then
		return
	end
	local ff = CLEU_BOSS_START[ActiveEncounter]
	for i=1,#ff do
		local f = ff[i]
		f(1,"",0,ActiveEncounterStart)
	end
end

local BossModsLink, BossModsRefresh
do
	local isAdded = nil
	local prevPhase = nil
	function BossModsLink()
		if isAdded then
			return
		end
		if (BigWigsLoader) and BigWigsLoader.RegisterMessage then
			local r = {}
			function r:BigWigs_Message (event, module, key, text, ...)
				
				if (key == "stages") then
					local phase = text:gsub (".*%s", "")
					phase = tonumber (phase)
					
					if (phase and type (phase) == "number" and prevPhase ~= phase) then
						prevPhase = phase
						
						CastNumbers_PHASE[phase] = (CastNumbers_PHASE[phase] or 0)+1
						BossPhaseCheck(phase,CastNumbers_PHASE[phase])

						history[#history+1] = {GetTime(),"PHASE",phase}
					end
					
				end
			end
			
			BigWigsLoader.RegisterMessage (r, "BigWigs_Message")
			
			isAdded = true
		end  
	end
	function BossModsRefresh()
		prevPhase = nil
	end
end

function module.main:ENCOUNTER_START(encounterID, encounterName, difficultyID, groupSize)
	module:Update()
	wipe(CastNumbers_SUCCESS)
	wipe(CastNumbers_START)
	wipe(CastNumbers_HP)
	wipe(CastNumbers_MANA)
	wipe(CastNumbers_MANA2)
	wipe(CastNumbers_PHASE)
	wipe(CastNumbers_BW_MSG)
	wipe(CastNumbers_BW_TIMER)
	wipe(CastNumbers_AURA_APPLIED)
	wipe(CastNumbers_AURA_REMOVED)
	wipe(CastNumbers_AURA_APPLIED_SELF)
	wipe(CastNumbers_AURA_REMOVED_SELF)
	wipe(bossManaPrev)
	ActiveEncounter = encounterID
	BossModsRefresh()
	BossModsLink()
	CastNumbers_PHASE[1] = 1
	ActivePhase = 1
	ActiveEncounterStart = GetTime()
	BossPhaseCheck(1,1)
	BossPullCheck()
	
	BOSSHPFrame:RegisterEvent("UNIT_HEALTH")
	BOSSManaFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT","boss1","boss2")

	stopHistory = false
	wipe(history)
	history[1] = {ActiveEncounterStart,"START_FIGHT"}
end
function module.main:ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize)
	ActiveEncounter = nil
	ActiveEncounterStart = GetTime()
	for i=1,#ActiveDelays do
		ActiveDelays[i]:Cancel()
	end
	wipe(ActiveDelays)
	
	BOSSHPFrame:UnregisterAllEvents()
	BOSSManaFrame:UnregisterAllEvents()

	stopHistory = true
end

local registeredBigWigsEvents = {}
function module:RegisterBigWigsCallback(event)
	if (registeredBigWigsEvents[event]) then
		return
	end
	if (BigWigsLoader) then
		BigWigsLoader.RegisterMessage(module, event, bigWigsEventCallback)
		registeredBigWigsEvents[event] = true
	end
end
function module:UnregisterBigWigsCallback(event)
	if not (registeredBigWigsEvents[event]) then
		return
	end
	if (BigWigsLoader) then
		BigWigsLoader.UnregisterMessage(module, event)
		registeredBigWigsEvents[event] = nil
	end
end

function module:Update()
	if VExRT.Reminder.enabled then
		module:RegisterEvents('ENCOUNTER_START','ENCOUNTER_END')
		CLEU:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		module:RegisterBigWigsCallback("BigWigs_StartBar")
		module:RegisterBigWigsCallback("BigWigs_StopBar")
		module:RegisterBigWigsCallback("BigWigs_PauseBar")
		module:RegisterBigWigsCallback("BigWigs_ResumeBar")
		module:RegisterBigWigsCallback("BigWigs_StopBars")
		module:RegisterBigWigsCallback("BigWigs_OnBossDisable")
		CreateFunctions()
	else
		module:UnregisterEvents('ENCOUNTER_START','ENCOUNTER_END')
		CLEU:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		module:UnregisterBigWigsCallback("BigWigs_StartBar")
		module:UnregisterBigWigsCallback("BigWigs_StopBar")
		module:UnregisterBigWigsCallback("BigWigs_PauseBar")
		module:UnregisterBigWigsCallback("BigWigs_ResumeBar")
		module:UnregisterBigWigsCallback("BigWigs_StopBars")
		module:UnregisterBigWigsCallback("BigWigs_OnBossDisable")
	end
end
function module:UpdateVisual(onlyFont)
	if not onlyFont then
		if VExRT.Reminder.lock then
			frame.dot:Show()
			frame:EnableMouse(true)
			frame:SetMovable(true)	
			frame.text:SetText("Test message Test")
			frame:Show()
		else
			frame.dot:Hide()
			frame:EnableMouse(false)
			frame:SetMovable(false)	
			frame.text:SetText("")
			frame:Hide()		
		end
	end
	frame.text:SetFont(VExRT.Reminder.Font or ExRT.F.defFont, VExRT.Reminder.FontSize or 72)
end

ELib:FixPreloadFont(frame,function() 
	if VExRT then
		frame.text:SetFont(GameFontWhite:GetFont(),11)
		module:UpdateVisual(true)
		return true
	end
end)

--[[
ver^token^boss^event^spellID^delay^duration^conditions^players^roles^text^sound^castnum^name^diff^countdown

]]

local prevIndex = nil

function module:Sync(isExport)
	local r = ""
	local rc = 0
	for token,data in pairs(VExRT.Reminder.data) do
		if data.event and data.spellID and data.duration and data.msg then
			r = r .. senderVersion .. "^" .. data.token .. "^" .. (data.boss or "") .. "^" .. data.event .. "^" .. data.spellID .. "^" .. (data.delay or "")  .. "^" .. data.duration .. "^" .. (data.condition or "") .. "^" ..
				(data.units or "") .. "^" .. (data.roles or "") .. "^" .. (data.msg:gsub("%^","")) .. "^" .. (data.sound or "") .. "^" .. (data.cast or "") .. "^" .. (data.name or "")  .. "^" .. (data.diff or "") .. "^" ..
				(data.countdown and "1" or "") .. "^" .. (data.notepat or "").. "^" .. (data.globalCounter and "1" or "") .. "\n"
			rc = rc + 1
		end
	end
	r = r:gsub("\n$","")
	if isExport then
		return r
	end

	local compressed = LibDeflate:CompressDeflate(r,{level = 9})
	local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

	encoded = encoded .. "##F##"

	--print("Reminder data length:",#encoded,#r,rc,#encoded/rc,#r/rc)

	local newIndex
	while prevIndex == newIndex do
		newIndex = math.random(100,999)
	end
	prevIndex = newIndex

	newIndex = tostring(newIndex)
	local parts = ceil(#encoded / 240)
	for i=1,parts do
		local msg = encoded:sub( (i-1)*240+1 , i*240 )
		ExRT.F.SendExMsg("reminder","D\t"..newIndex.."\t"..msg)
	end
end

function ProcessTextToData(text,isImport)
	local data = {strsplit("\n",text)}
	for i=1,#data do
		local ver,token,boss,event,spellID,delay,duration,conditions,players,roles,text,sound,cast,name,diff,countdown,notepat,globalCounter = strsplit("^",data[i])
		if tonumber(ver or "?") == senderVersion then
			token = tonumber(token)
			local new = {
				token = token,
				event = event,
				boss = tonumber(boss),
				spellID = tonumber(spellID),
				delay = delay~="" and delay or nil,
				duration = tonumber(duration),
				condition = conditions~="" and (tonumber(conditions) or conditions) or nil,
				units = players~="" and players or nil,
				roles = roles~="" and roles or nil,
				msg = text,
				sound = sound~="" and sound or nil,
				cast = tonumber(cast),
				name = name~="" and name or nil,
				diff = tonumber(diff),
				countdown = countdown == "1",
				notepat = notepat ~= "" and notepat or nil,
				globalCounter = globalCounter == "1",
			}
			if isImport then
				new.notSync = true
			end
			if not VExRT.Reminder.data[token] or not VExRT.Reminder.locked[token] then
				VExRT.Reminder.data[token] = new
			end
		end
	end

	if module.options.lastUpdate then
		module.options.lastUpdate:Update()
		if module.options:IsVisible() then
			module.options:Hide()
			module.options:Show()
		end
	end
	
	CreateFunctions()
end

function module:addonMessage(sender, prefix, prefix2, token, ...)
	if prefix == "reminder" then
		if prefix2 == "D" then
			if not IsInRaid() or not ExRT.F.IsPlayerRLorOfficer(sender) then
				return
			end
			VExRT.Reminder.LastUpdateName = sender
			VExRT.Reminder.LastUpdateTime = time()
		
			local currMsg = table.concat({...}, "\t")
			if tostring(token) == tostring(module.db.msgindex) and type(module.db.lasttext)=='string' then
				module.db.lasttext = module.db.lasttext .. currMsg
			else
				module.db.lasttext = currMsg
			end
			module.db.msgindex = token

			if type(module.db.lasttext)=='string' and module.db.lasttext:find("##F##$") then
				local str = module.db.lasttext:sub(1,-6)
				local decoded = LibDeflate:DecodeForWoWAddonChannel(str)
				local decompressed = LibDeflate:DecompressDeflate(decoded)

				for _,data in pairs(VExRT.Reminder.data) do
					data.notSync = true
				end
				ProcessTextToData(decompressed)
				module.db.lasttext = nil
			end
		elseif prefix2 == "R" then
			if not IsInRaid() or not ExRT.F.IsPlayerRLorOfficer(sender) then
				return
			end
			token = tonumber(token)
			
			VExRT.Reminder.data[token] = nil
			if module.options:IsVisible() then
				module.options:Hide()
				module.options:Show()
			end
			CreateFunctions()
		end
	end
end