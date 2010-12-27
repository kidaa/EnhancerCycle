if select(2,UnitClass("player")) ~= "SHAMAN" then return end

local ICON_HEIGHT = 20
local MAX_SPELLS = 8
local display = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(display, "visibility", "[spec:1]show;hide")
display:SetPoint("CENTER", UIParent, "CENTER", -80, -50)
display:SetHeight(ICON_HEIGHT)
display:SetWidth(ICON_HEIGHT)
display:Show()

local function GetSpellCooldownRemaining(spell)
	local start, duration, enabled = GetSpellCooldown(spell)
	if enabled == 0 then
		return -1
	end
	if not start or start == 0 then
		return 0
	end
	return start + duration - GetTime()
end

local function GetItemCooldownRemaining(index)
	local start, duration, enabled =  GetInventoryItemCooldown("player", index)
	if enabled == 0 then
		return -1
	end
	if start == 0 then
		return 0
	end
	return start + duration - GetTime()
end

local usedSpells = {}
local order = {}
local rest = {}

local function updateCycle()
	wipe(usedSpells)
	wipe(order)
	local function queue(spell)
		if usedSpells[spell] then return end
		usedSpells[spell] = true
		table.insert(order, spell)
	end

	local GCD = GetSpellCooldownRemaining("Healing Wave")
	local ssCD = GetSpellCooldownRemaining("Stormstrike")
	local shockCD = GetSpellCooldownRemaining("Earth Shock")

	local function queueReadySpells(list)
		for i,v in ipairs(list) do
			if GetSpellCooldownRemaining(v) <= GCD then
				queue(v)
			end
		end
	end

	local function queueSortedSpells(list)
		table.sort(list, function(a,b) return GetSpellCooldownRemaining(a) < GetSpellCooldownRemaining(b) end)
		for i,v in ipairs(list) do
			queue(v)
		end
	end

	-- LS_0 - Cast Lightning Shield if there are no orbs left on you.
	local name, _, icon, count = UnitAura("player", "Lightning Shield")
	if not name then
		queue("Lightning Shield")
	end
	--[[
	-- skip: SW - Cast Feral Spirit if the ability is off CD. (Use your own judgement for timing with Bloodlust/Heroism)
	--]]

	local _, firetotemname, starttime, duration = GetTotemInfo(1)
	local firetotemRemaining = starttime + duration - GetTime()
	if not firetotemname or firetotemname == "" then
		queue("Searing Totem")
	end

	local llCD = GetSpellCooldownRemaining("Lava Lash")
	if llCD <= GCD and llCD <= shockCD then
		queue("Lava Lash")
	end

	-- FS if UE is present
	local ufname, _, _, _, _, _, endTime = UnitAura("player", "Unleash Flame")
	local ufremaining = 0
	if ufname then
		ufremaining = endTime - GetTime()
	end
	if ufname and shockCD <= GCD and ufremaining >= shockCD then
		queue("Flame Shock")
	end

	-- MW5_LB - Cast a Lightning Bolt when you have 5 Maelstrom weapon stacks
	local name, _, icon, count = UnitAura("player", "Maelstrom Weapon")
	if name and count == 5 then
		queue("Lightning bolt")
	end

	wipe(rest)
	table.insert(rest, "Lava Lash")
	table.insert(rest, "Unleash Elements")
	table.insert(rest, "Stormstrike")
	if ufname and ufremaining >= shockCD then
		table.insert(rest, "Flame Shock")
	else
		table.insert(rest, "Earth Shock")
	end

	queueReadySpells(rest)

	-- LS - Refresh your Lightning Shield if low number of orbs remaining (2 or less).
	local name, _, icon, count = UnitAura("player", "Lightning Shield")
	if count and count < 3 then
		queue("Lightning Shield")
	end

	-- Totem refresh - if all else is on cooldown take the opportunity, if required, to refresh your totems.
	if #order == 0 then
		queue("Call of the Elements")
	end

	queueSortedSpells(rest)

	return order
end

local firstIcon = display:CreateTexture(nil, "BORDER")
firstIcon:SetAllPoints(display)

local secondIcon = display:CreateTexture(nil, "BORDER")
secondIcon:SetPoint("BOTTOM", firstIcon, "TOP", 0, 4)
secondIcon:SetWidth(ICON_HEIGHT - 4)
secondIcon:SetHeight(ICON_HEIGHT - 4)

local primaryTextureCache = {
	[1] = firstIcon,
	[2] = secondIcon,
}

local function getPrimaryTexture(num)
	local texture = primaryTextureCache[num]
	if not texture then
		texture = display:CreateTexture(nil, "BORDER")
		local parent = getPrimaryTexture(num - 1)
		texture:SetPoint("BOTTOM", parent, "TOP", 0, 5)
		texture:SetHeight(parent:GetHeight())
		texture:SetWidth(parent:GetHeight())
		primaryTextureCache[num] = texture
	end
	return texture
end

local function updateIcon()
	local order = updateCycle()
	for i = 1,MAX_SPELLS do
		local texture = getPrimaryTexture(i)
		if not order[i] then
			texture:Hide()
		else
			local nextSpell = order[i]
			local _, _, icon = GetSpellInfo(nextSpell)
			texture:SetTexture(icon)
			texture:Show()
		end
	end
end
display:SetScript("OnUpdate", updateIcon)
_G.display = display

local aoeDisplay = CreateFrame('Frame', nil, UIParent, "SecureHandlerStateTemplate")
RegisterStateDriver(aoeDisplay, "visibility", "[spec:1]show;hide")
aoeDisplay:SetPoint("CENTER", UIParent, "CENTER", -110, -50)
aoeDisplay:SetHeight(ICON_HEIGHT)
aoeDisplay:SetWidth(ICON_HEIGHT)
aoeDisplay:Show()

local aoeIcon = aoeDisplay:CreateTexture(nil, "BORDER")
aoeIcon:SetTexture([[Interface\Icons\Spell_Shaman_MaelstromWeapon]])
aoeIcon:SetAllPoints(aoeDisplay)

local function getNextAoESpell()
	local GCD = GetSpellCooldownRemaining("Healing Wave")
	local name, _, icon, count = UnitAura("player", "Maelstrom Weapon")
	if name and count == 5 and GetSpellCooldownRemaining("Chain Lightning") <= GCD then
		return "Chain Lightning"
	end

	local _, firetotemname, starttime, duration = GetTotemInfo(1)
	if not firetotemname or firetotemname == "" then
		return "Magma Totem"
	end
	local cd = GetSpellCooldownRemaining("Fire Nova")
	--print(cd)
	--print(GCD)
	if GetSpellCooldownRemaining("Fire Nova") <= GCD then
		return "Fire Nova"
	end
	local firetotemRemaining = starttime + duration - GetTime()
	if firetotemRemaining < 3 then
		return "Magma Totem"
	end
	return ""
end

local function updateAoEDisplay(self)
	local nextspell = getNextAoESpell()
	local icon
	if nextspell then
		_, _, icon = GetSpellInfo(nextspell)
	end
	aoeIcon:SetTexture(icon)
end
aoeDisplay:SetScript("OnUpdate", updateAoEDisplay)

display:EnableMouse(true)
display:SetScript("OnMouseUp", function()
		if aoeDisplay:IsShown() then
			UnregisterStateDriver(aoeDisplay, "visibility")
			aoeDisplay:Hide()
		else
			RegisterStateDriver(aoeDisplay, "visibility", "[spec:1]show;hide")
		end
	end)