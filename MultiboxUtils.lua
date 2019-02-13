local name,addon = ...

-- GUI Library
StdUi = LibStub('StdUi')

-- Locals
local realmName, charName, charDb, team
local MUtil = {} -- addon obj for functions
local focusMacro, mountTargetMacro = '!focus', '!mount'

-- Events Frame
local frame, events = CreateFrame("FRAME"), {}

-------------------------------------------------------------------------------
function events:ADDON_LOADED(name)
	if name == 'MultiboxUtils' then
		MultiboxUtilsDB = MultiboxUtilsDB or defaultDB
	end
end

function events:PLAYER_LOGIN()
    MUtil:Initialise()
end

-- Accepts group invite if the name is in the charDb
function events:PARTY_INVITE_REQUEST(sender)
	sender = MUtil:AddRealmName(sender)
	if charDb[sender] then
		AcceptGroup()
		StaticPopup_Hide("PARTY_INVITE")
	end
end

-- Accepts resurrections
function events:RESURRECT_REQUEST()
	AcceptResurrect()
	StaticPopup_Hide( "RESURRECT")
end

-- Accepts summons
function events:CONFIRM_SUMMON()
	ConfirmSummon()
	StaticPopup_Hide("CONFIRM_SUMMON")
end

-------------------------------------------------------------------------------
-- IMPORTANT! Must be placed after declaring the 'events:EVENT_NAME' functions
-- Call functions in the events table for events
frame:SetScript("OnEvent", function(self, event, ...)
    events[event](self, ...)
end)

-- Register every event in the events table
for k, v in pairs(events) do
    frame:RegisterEvent(k)
end

-------------------------------------------------------------------------------
function MUtil:Initialise()
	realmName = GetRealmName()
	realmNameStripped = realmName:gsub('%s+', '')
	charName = UnitName('player')
	charDb = addon.charDb
	team = addon.team

	MUtil:UpdateFocusMacro()
	--test
end

-- Sends Invite to character / group of characters
function MUtil:SendInvite(arg)
	argInt = tonumber(arg)
	if arg == 'all' then
		for i = 0, 9 do
			if team[i]['name'] then
				if not IsInRaid() then
					ConvertToRaid()	
				end
				local unit = MUtil:StripRealmName(team[i]['name'])
				InviteUnit(unit)
			end
		end
	elseif argInt <= 9 and argInt >= 0 then
		local unit = MUtil:StripRealmName(team[argInt]['name'])
		InviteUnit(unit)
	end
end

-- Macro that focuses team master
function MUtil:UpdateFocusMacro()
	-- Can't change macros during combat so we return
	if InCombatLockdown() then
		print('combat')
		return
	end
	-- If macro doesnt exist create it and call this func again
	macroSlot = MUtil:FindMacroSlot(focusMacro)
	if not macroSlot then 
		MUtil:CreateDefaultMacro('!focus')
		MUtil:UpdateFocusMacro()
		return
	end

	-- Focus will be the first character in order from 0-9 that won't ride another's mount
	-- and will also not serve as a mount for another char from the team
	local focus
	for i = 0, 10 do
		if not team[i]['mount'] then
			focus = MUtil:StripRealmName(team[i]['name'])
			break
		end
	end
	-- mountTarget is the name of the character that will be mounted by this character
	local mountTarget = nil
	for k,v in pairs(team) do
		if MUtil:StripRealmName(v['name']) == charName then
			if v['mount'] then
				mountTarget = MUtil:StripRealmName(team[v['mount']]['name'])
			end
			break
		end
	end

	if focus == charName then
		EditMacro(macroSlot, focusMacro, "ABILITY_ROGUE_FINDWEAKNESS", 
			"/mutils focus\n/cleartarget")
	elseif mountTarget then
		EditMacro(macroSlot, focusMacro, "ABILITY_ROGUE_FINDWEAKNESS", 
			"/mutils focus\n/tar "..focus.."\n/focus\n/tar "..mountTarget)
	else
		EditMacro(macroSlot, focusMacro, "ABILITY_ROGUE_FINDWEAKNESS", 
			"/mutils focus\n/tar "..focus.."\n/focus\n/cleartarget")
	end
end

-- Finds global macro position based on name
function MUtil:FindMacroSlot(macroName)
	local global, character = GetNumMacros()
	for i = 1, global do
		local name = GetMacroInfo(i)
		if name == macroName then
			return i
		end
	end
	return nil
end

-- Creates an empty macro with just the given name
function MUtil:CreateDefaultMacro(macroName)
	CreateMacro(macroName, "INV_Misc_QuestionMark", "", nil, nil)
end

-- If fullName (charName-realmName) is from the same server removes realmName
function MUtil:StripRealmName(fullName)
	if string.find(fullName, realmName) or string.find(fullName, realmNameStripped) then
		return string.match(fullName, '%a+')
	end
	return fullName
end

-- Add realmName to fullName if it doesn't contain '-realmName' (used to validate charDb)
function MUtil:AddRealmName(name)
	if not string.find(name, '-') then
		return name .. '-' .. realmNameStripped
	else
		return name
	end
end

-------------------------------------------------------------------------------
-- Slash Command List
SLASH_MultiboxUtils1 = '/mutils'
SLASH_MultiboxUtils2 = '/mu'
SlashCmdList['MultiboxUtils'] = function(argString) MUtil:SlashCommand(argString) end

function MUtil:SlashCommand(argString)
	local args = {strsplit(" ",argString)}
	local cmd = table.remove(args, 1)

	if cmd == 'inv' then
		MUtil:SendInvite(args[1])
	elseif cmd == 'focus' then
		MUtil:UpdateFocusMacro()
	else
		print('MultiboxUtils:')
		print('  /mutils inv')
		print('    all')
		print('    0-9')
	end
end
