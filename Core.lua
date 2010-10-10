if select(2,UnitClass("player")) ~= "SHAMAN" then return end

local ICON_HEIGHT = 20
local MAX_SPELLS = 3
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

local function updateCycle()
	local usedSpells = {}
	local order = {}
	local function queue(spell)
		if usedSpells[spell] then return end
		usedSpells[spell] = true
		table.insert(order, spell)
	end
	-- local GCD = 1.5 / (1 + GetCombatRatingBonus(18) / 100);
	local GCD = GetSpellCooldownRemaining("Healing Wave")
	local ssCD = GetSpellCooldownRemaining("Stormstrike")
	local shockCD = GetSpellCooldownRemaining("Earth Shock")
	-- LS_0 - Cast Lightning Shield if there are no orbs left on you.
	local name, _, icon, count = UnitAura("player", "Lightning Shield")
	if not name then
		queue("Lightning Shield")
	end
	--[[
	-- skip: SW - Cast Feral Spirit if the ability is off CD. (Use your own judgement for timing with Bloodlust/Heroism)
	--]]

	--SS_0 - Cast a Stormstrike if there are no charges left on the target.
	local name, _ icon, count = UnitDebuff("target", "Stormstrike")
	if not name and ssCD <= GCD then
		queue("Stormstrike")
	end


	-- MW5_LB - Cast a Lightning Bolt when you have 5 Maelstrom weapon stacks
	local name, _, icon, count = UnitAura("player", "Maelstrom Weapon")
	if name and count == 5 then
		queue("Lightning bolt")
	end

	--[[
	skip: FE - Cast your Fire Elemental if it is off CD (This will also free up GCDs for other abilities making it very useful during Bloodlust/Heroism).
	skip: MT_0 - Refresh your Magma Totem if it has expired.
	--]]

	-- FS - Cast a Flame Shock if there is no Flame Shock debuff on target.
	local name, _, icon, _, _, duration, expirationTime, unitCaster = UnitDebuff("target", "Flame Shock")

	if name and unitCaster == "player" then
		local remaining = expirationTime - GetTime()
		local cooldown = GetSpellCooldownRemaining("Flame Shock")
		if remaining <= GCD and cooldown <= GCD then
			queue("Flame Shock")
		end
	elseif shockCD <= GCD then
		queue("Flame Shock")
	end

	local llCD = GetSpellCooldownRemaining("Lava Lash")
	-- ES - Cast an Earth shock whenever its off cooldown and the above are not available.
	if shockCD == 0 and not usedSpells["Flame Shock"] then
		queue("Earth Shock")
	end

	-- SS - Cast a Stormstrike whenever its off cooldown and MW hasn't got 5 stacks
	if ssCD == 0 then
		queue("Stormstrike")
	end

	-- LL - Cast a lava lash whenever its off cooldown and none of the above abilities are available.
	if llCD == 0 then
		queue("Lava Lash")
	end

	-- ES - Cast an Earth shock whenever its off cooldown and the above are not available.
	if shockCD <= GCD and not usedSpells["Flame Shock"] then
		queue("Earth Shock")
	end

	-- SS - Cast a Stormstrike whenever its off cooldown and MW hasn't got 5 stacks

	if ssCD <= GCD then
		queue("Stormstrike")
	end

	-- LL - Cast a lava lash whenever its off cooldown and none of the above abilities are available.
	if llCD <= GCD then
		queue("Lava Lash")
	end

	local _, firetotemname, starttime, duration = GetTotemInfo(1)
	local firetotemRemaining = 99
	if not firetotemname or firetotemname == "" then
		queue("Magma Totem")
	else
		firetotemRemaining = starttime + duration - GetTime()
	end

	-- !!!!!missing comment
	if GetSpellCooldownRemaining("Fire Nova") <= GCD then
		queue("Fire Nova")
	end

	-- MT - Refresh your Magma Totem if there are 2 secs or less left.
	if firetotemRemaining <= 2 then
		queue("Magma Totem")
	end

	-- LS - Refresh your Lightning Shield if low number of orbs remaining (2 or less).
	local name, _, icon, count = UnitAura("player", "Lightning Shield")
	if count and count < 3 then
		queue("Lightning Shield")
	end

	-- Totem refresh - if all else is on cooldown take the opportunity, if required, to refresh your totems.
	if #order == 0 then
		queue("Call of the Elements")
	end
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