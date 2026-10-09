---@diagnostic disable: duplicate-set-field

local ADDON_NAME, ns = ...
local L = ns.L
local locale = GetLocale()

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "1.1.4"

local Elib = LibStub and LibStub("Elib-4.0", true)
if not Elib then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000TitanWeaponSkills:|r Elib-4.0 library not found!")
    return
end

local Color = {}
Color.WHITE = "|cFFFFFFFF"
Color.RED = "|cFFDC2924"
Color.YELLOW = "|cFFFFF244"
Color.GREEN = "|cFF3DDC53"
Color.ORANGE = "|cFFFFA500"
Color.GRAY = "|cFF888888"

-- Project detection (Classic Era vs TBC Classic vs WoW Forever)
-- WoW Forever reports interface 16xxx (beta: 16001); treated like TBC+ (Shaman Dual Wield).
local isTBC = false
do
    local projectId = WOW_PROJECT_ID
    if projectId and WOW_PROJECT_BURNING_CRUSADE_CLASSIC and projectId == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        isTBC = true
    else
        local build = select(4, GetBuildInfo())
        if build and ((build >= 20000 and build < 30000) or (build >= 16000 and build < 17000)) then
            isTBC = true
        end
    end
end

--[[
    Stable weapon definitions.
    names: exact localized skill line names (must be exact to avoid Axes vs Two-Handed Axes).
    classes: English class tokens that can learn this skill.
    spellIds: optional proficiency / passive spell IDs (spellbook / IsPlayerSpell fallback).
    binary: no progressive skill ranks (e.g. Dual Wield).
]]
local WEAPON_DEFS = {
    {
        id = "AXES",
        icon = "Interface\\Icons\\INV_Axe_06",
        names = {
            enUS = "Axes", deDE = "Äxte", frFR = "Haches", esES = "Hachas", esMX = "Hachas",
            ruRU = "Топоры", zhCN = "斧", zhTW = "斧", koKR = "도끼",
        },
        -- Rogues cannot train Axes until WotLK; not available in Classic Era / TBC.
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true },
    },
    {
        id = "TWO_HANDED_AXES",
        icon = "Interface\\Icons\\INV_Axe_09",
        names = {
            enUS = "Two-Handed Axes", deDE = "Zweihandäxte", frFR = "Haches à deux mains",
            esES = "Hachas de dos manos", esMX = "Hachas de dos manos",
            ruRU = "Двуручные топоры", zhCN = "双手斧", zhTW = "雙手斧", koKR = "양손 도끼",
        },
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true },
    },
    {
        id = "SWORDS",
        icon = "Interface\\Icons\\INV_Sword_04",
        names = {
            enUS = "Swords", deDE = "Schwerter", frFR = "Épées", esES = "Espadas", esMX = "Espadas",
            ruRU = "Мечи", zhCN = "剑", zhTW = "劍", koKR = "도검",
        },
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, MAGE = true, WARLOCK = true },
    },
    {
        id = "TWO_HANDED_SWORDS",
        icon = "Interface\\Icons\\INV_Sword_04",
        names = {
            enUS = "Two-Handed Swords", deDE = "Zweihandschwerter", frFR = "Épées à deux mains",
            esES = "Espadas de dos manos", esMX = "Espadas de dos manos",
            ruRU = "Двуручные мечи", zhCN = "双手剑", zhTW = "雙手劍", koKR = "양손 도검",
        },
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true },
    },
    {
        id = "MACES",
        icon = "Interface\\Icons\\INV_Mace_01",
        names = {
            enUS = "Maces", deDE = "Streitkolben", frFR = "Masses", esES = "Mazas", esMX = "Mazas",
            ruRU = "Дробящее оружие", zhCN = "锤", zhTW = "錘", koKR = "둔기",
        },
        classes = { WARRIOR = true, PALADIN = true, ROGUE = true, PRIEST = true, SHAMAN = true, DRUID = true },
    },
    {
        id = "TWO_HANDED_MACES",
        icon = "Interface\\Icons\\INV_Hammer_01",
        names = {
            enUS = "Two-Handed Maces", deDE = "Zweihandstreitkolben", frFR = "Masses à deux mains",
            esES = "Mazas de dos manos", esMX = "Mazas de dos manos",
            ruRU = "Двуручное дробящее оружие", zhCN = "双手锤", zhTW = "雙手錘", koKR = "양손 둔기",
        },
        classes = { WARRIOR = true, PALADIN = true, SHAMAN = true, DRUID = true },
    },
    {
        id = "POLEARMS",
        icon = "Interface\\Icons\\INV_Spear_01",
        names = {
            enUS = "Polearms", deDE = "Stangenwaffen", frFR = "Armes d'hast",
            esES = "Armas de asta", esMX = "Armas de asta",
            ruRU = "Древковое оружие", zhCN = "长柄武器", zhTW = "長柄武器", koKR = "장창류",
        },
        -- Druids cannot use Polearms in Classic Era or TBC (briefly added then reverted on Era).
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true },
    },
    {
        id = "STAVES",
        icon = "Interface\\Icons\\INV_Staff_08",
        names = {
            enUS = "Staves", deDE = "Stäbe", frFR = "Bâtons", esES = "Bastones", esMX = "Bastones",
            ruRU = "Посохи", zhCN = "法杖", zhTW = "法杖", koKR = "지팡이",
        },
        classes = { WARRIOR = true, HUNTER = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true },
    },
    {
        id = "DAGGERS",
        icon = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
        names = {
            enUS = "Daggers", deDE = "Dolche", frFR = "Dagues", esES = "Dagas", esMX = "Dagas",
            ruRU = "Кинжалы", zhCN = "匕首", zhTW = "匕首", koKR = "단검",
        },
        classes = { WARRIOR = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true },
    },
    {
        id = "FIST_WEAPONS",
        icon = "Interface\\Icons\\INV_Gauntlets_04",
        names = {
            enUS = "Fist Weapons", deDE = "Faustwaffen", frFR = "Armes de pugilat",
            esES = "Armas de puño", esMX = "Armas de puño",
            ruRU = "Кистевое оружие", zhCN = "拳套", zhTW = "拳套", koKR = "장착 무기류",
        },
        -- Hunters cannot use Fist Weapons in Classic Era or TBC.
        classes = { WARRIOR = true, ROGUE = true, SHAMAN = true, DRUID = true },
        -- Proficiency only; combat skill ranks are tracked via Unarmed.
        spellIds = { 15590 },
        rankFromId = "UNARMED",
    },
    {
        id = "UNARMED",
        icon = "Interface\\Icons\\INV_Gauntlets_04",
        names = {
            enUS = "Unarmed", deDE = "Unbewaffnet", frFR = "Mains nues", esES = "Sin armas", esMX = "Sin armas",
            ruRU = "Рукопашный бой", zhCN = "徒手战斗", zhTW = "徒手戰鬥", koKR = "맨손 전투",
        },
        classes = {
            WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
            SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
        },
    },
    {
        id = "BOWS",
        icon = "Interface\\Icons\\INV_Weapon_Bow_04",
        names = {
            enUS = "Bows", deDE = "Bogen", deDE_alt = "Bögen", frFR = "Arcs", esES = "Arcos", esMX = "Arcos",
            ruRU = "Луки", zhCN = "弓", zhTW = "弓", koKR = "활",
        },
        classes = { WARRIOR = true, HUNTER = true, ROGUE = true },
    },
    {
        id = "CROSSBOWS",
        icon = "Interface\\Icons\\INV_Weapon_Crossbow_01",
        names = {
            enUS = "Crossbows", deDE = "Armbrüste", frFR = "Arbalètes", esES = "Ballestas", esMX = "Ballestas",
            ruRU = "Арбалеты", zhCN = "弩", zhTW = "弩", koKR = "석궁",
        },
        classes = { WARRIOR = true, HUNTER = true, ROGUE = true },
    },
    {
        id = "GUNS",
        icon = "Interface\\Icons\\INV_Weapon_Rifle_01",
        names = {
            enUS = "Guns", deDE = "Schusswaffen", frFR = "Fusils", esES = "Armas de fuego", esMX = "Armas de fuego",
            ruRU = "Огнестрельное оружие", zhCN = "枪械", zhTW = "槍械", koKR = "총",
        },
        classes = { WARRIOR = true, HUNTER = true, ROGUE = true },
    },
    {
        id = "THROWN",
        icon = "Interface\\Icons\\INV_ThrowingKnife_01",
        names = {
            enUS = "Thrown", deDE = "Wurfwaffen", frFR = "Armes de jet", esES = "Armas arrojadizas", esMX = "Armas arrojadizas",
            ruRU = "Метательное оружие", zhCN = "投掷武器", zhTW = "投擲武器", koKR = "투척 무기",
        },
        classes = { WARRIOR = true, HUNTER = true, ROGUE = true },
    },
    {
        id = "WANDS",
        icon = "Interface\\Icons\\INV_Wand_01",
        names = {
            enUS = "Wands", deDE = "Zauberstäbe", frFR = "Baguettes", esES = "Varitas", esMX = "Varitas",
            ruRU = "Жезлы", zhCN = "魔杖", zhTW = "魔杖", koKR = "마법봉",
        },
        classes = { PRIEST = true, MAGE = true, WARLOCK = true },
    },
    {
        id = "DEFENSE",
        icon = "Interface\\Icons\\INV_Shield_06",
        names = {
            enUS = "Defense", deDE = "Verteidigung", frFR = "Défense", esES = "Defensa", esMX = "Defensa",
            ruRU = "Защита", zhCN = "防御", zhTW = "防禦", koKR = "방어",
        },
        classes = {
            WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
            SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
        },
    },
    {
        id = "DUAL_WIELD",
        icon = "Interface\\Icons\\Ability_DualWield",
        names = {
            enUS = "Dual Wield", deDE = "Beidhändigkeit", frFR = "Ambidextrie",
            esES = "Doble empuñadura", esMX = "Doble empuñadura",
            ruRU = "Бой двумя оружиями", zhCN = "双武器", zhTW = "雙武器", koKR = "쌍수 무기",
        },
        -- Dual Wield: Warrior/Hunter/Rogue in both; Shaman only via TBC Enhancement talent.
        classes = isTBC
            and { WARRIOR = true, HUNTER = true, ROGUE = true, SHAMAN = true }
            or { WARRIOR = true, HUNTER = true, ROGUE = true },
        spellIds = { 674 },
        binary = true,
        checkCanDualWield = true,
    },
}

local sessionGains = {}
local skillCache = {}
local cacheDirty = true
local refreshingCache = false
local tooltipDebug = false -- toggled by /tws tooltip

local function GetDisplayName(weaponDef)
    return weaponDef.names[locale] or weaponDef.names.enUS or weaponDef.id
end

local function BuildNameLookup(weaponDef)
    local lookup = {}
    for _, name in pairs(weaponDef.names) do
        lookup[name] = true
    end
    return lookup
end

-- Classic skill line IDs, used for direct lookup where the skill list cannot be expanded (WoW Forever).
local SKILL_IDS = {
    SWORDS = 43, AXES = 44, BOWS = 45, GUNS = 46, MACES = 54, TWO_HANDED_SWORDS = 55,
    DEFENSE = 95, DUAL_WIELD = 118, STAVES = 136, TWO_HANDED_MACES = 160, UNARMED = 162,
    TWO_HANDED_AXES = 172, DAGGERS = 173, THROWN = 176, CROSSBOWS = 226, WANDS = 228,
    POLEARMS = 229, FIST_WEAPONS = 473,
}

local weaponDefsById = {}
for _, def in ipairs(WEAPON_DEFS) do
    def.skillId = SKILL_IDS[def.id]
    def.nameLookup = BuildNameLookup(def)
    def.displayName = GetDisplayName(def)
    weaponDefsById[def.id] = def
end

local function IsSpellProficiencyKnown(spellIds)
    if not spellIds then
        return false
    end

    for _, spellId in ipairs(spellIds) do
        if IsPlayerSpell and IsPlayerSpell(spellId) then
            return true
        end
        if IsSpellKnown and IsSpellKnown(spellId) then
            return true
        end
    end

    return false
end

local function IsWeaponProficiencyKnown(weaponDef)
    if weaponDef.checkCanDualWield and CanDualWield and CanDualWield() then
        return true
    end
    return IsSpellProficiencyKnown(weaponDef.spellIds)
end

-- Forever moved the skill API into C_SkillInfo; Classic Era/TBC still use the globals.
local API_GetNumSkillLines = GetNumSkillLines or (C_SkillInfo and C_SkillInfo.GetNumSkillLines)
local API_ExpandSkillHeader = ExpandSkillHeader or (C_SkillInfo and C_SkillInfo.ExpandSkillHeader)
local API_CollapseSkillHeader = CollapseSkillHeader or (C_SkillInfo and C_SkillInfo.CollapseSkillHeader)
local RawGetSkillLineInfo = GetSkillLineInfo or (C_SkillInfo and C_SkillInfo.GetSkillLineInfo)

-- Forever has no global skill API and ignores ExpandSkillHeader, so weapon skills
-- (children of the collapsed "Weapon Skills" header) are looked up by skill line ID instead.
local API_GetSkillLineInfoByID = not GetNumSkillLines and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID or nil

local function API_GetSkillLineInfo(index)
    local first = RawGetSkillLineInfo(index)
    if type(first) == "table" then
        -- Table-style return (retail-like field names); Forever reports isCollapsed, not isExpanded.
        local isExpanded = first.isExpanded
        if isExpanded == nil and first.isCollapsed ~= nil then
            isExpanded = not first.isCollapsed
        end
        return first.skillName or first.name, first.isHeader, isExpanded, first.skillRank or first.rank,
            first.numTempPoints, first.skillModifier, first.skillMaxRank or first.maxRank
    end
    return RawGetSkillLineInfo(index)
end

local function IsSkillFrameOpen()
    return (SkillFrame and SkillFrame:IsShown()) or false
end

local function RefreshSkillCache()
    if refreshingCache then
        return
    end
    refreshingCache = true

    local ok = pcall(function()
        local newCache = {}

        if API_GetSkillLineInfoByID then
            for _, def in ipairs(WEAPON_DEFS) do
                local info = def.skillId and API_GetSkillLineInfoByID(def.skillId)
                if type(info) == "table" and info.name and not info.isHeader then
                    -- Keyed by weapon id, not name: localized names differ between clients.
                    newCache[def.id] = { name = info.name, rank = info.rank or 0, maxRank = info.maxRank or 0 }
                end
            end

            wipe(skillCache)
            for name, data in pairs(newCache) do
                skillCache[name] = data
            end
            -- Empty result usually means skill data was not loaded yet; retry on next access.
            cacheDirty = next(newCache) == nil
            return
        end

        local collapsedHeaders = {}
        -- Expanding/collapsing while the skill UI is open re-enters SkillFrame and can stack-overflow.
        local canToggleHeaders = not IsSkillFrameOpen()

        if canToggleHeaders then
            -- Expand collapsed headers backwards so inserted rows do not shift unread indices.
            for i = API_GetNumSkillLines() or 0, 1, -1 do
                local skillName, isHeader, isExpanded = API_GetSkillLineInfo(i)
                if isHeader and not isExpanded and skillName then
                    collapsedHeaders[skillName] = true
                    API_ExpandSkillHeader(i)
                end
            end
        end

        for i = 1, API_GetNumSkillLines() or 0 do
            local skillName, isHeader, _, skillRank, _, _, skillMaxRank = API_GetSkillLineInfo(i)
            if skillName and not isHeader and skillRank and skillRank > 0 then
                newCache[skillName] = {
                    rank = skillRank,
                    maxRank = skillMaxRank or 0,
                }
            end
        end

        if canToggleHeaders then
            -- Restore previously collapsed headers (backwards again).
            for i = API_GetNumSkillLines() or 0, 1, -1 do
                local skillName, isHeader = API_GetSkillLineInfo(i)
                if isHeader and skillName and collapsedHeaders[skillName] then
                    API_CollapseSkillHeader(i)
                end
            end
        end

        wipe(skillCache)
        for name, data in pairs(newCache) do
            skillCache[name] = data
        end

        cacheDirty = false
    end)

    refreshingCache = false
    if not ok then
        cacheDirty = true
    end
end

local function GetCachedSkill(weaponDef)
    if cacheDirty and not refreshingCache then
        RefreshSkillCache()
    end

    if API_GetSkillLineInfoByID then
        local data = skillCache[weaponDef.id]
        if data then
            return data.name, data.rank, data.maxRank
        end
        return nil, nil, nil
    end

    for name in pairs(weaponDef.nameLookup) do
        local data = skillCache[name]
        if data then
            return name, data.rank, data.maxRank
        end
    end
    return nil, nil, nil
end

local function GetSkillLevelColor(rank, maxRank)
    if not rank or not maxRank or maxRank == 0 then
        return Color.WHITE
    end

    local ratio = rank / maxRank
    if rank >= maxRank then
        return Color.GREEN
    elseif ratio >= 0.90 then
        return Color.YELLOW
    elseif ratio >= 0.80 then
        return Color.ORANGE
    else
        return Color.RED
    end
end

local menus = {
    { type = "toggle", text = L["SHOW_MAX"], var = "ShowMax", def = true },
    { type = "toggle", text = L["SHOW_SESSION"], var = "ShowSession", def = true },
    { type = "toggle", text = L["SHOW_UNLEARNED"], var = "ShowUnlearned", def = true },
    { type = "toggle", text = L["MARK_LEARNED"], var = "MarkLearned", def = false },
    { type = "rightSideToggle" },
}

local function CreateWeaponPlugin(weaponDef)
    local titanId = "TITAN_WEAPONSKILL_" .. weaponDef.id
    local displayName = weaponDef.displayName

    local function UpdateVars(registry)
        local proficiencyKnown = IsWeaponProficiencyKnown(weaponDef)
        if not proficiencyKnown and weaponDef.rankFromId and GetCachedSkill(weaponDef) then
            proficiencyKnown = true
        end
        local markedLearned = TitanGetVar and TitanGetVar(titanId, "MarkLearned")

        -- Fist Weapons etc.: proficiency is binary, ranks come from another skill (Unarmed).
        if weaponDef.rankFromId then
            local rankSource = weaponDefsById[weaponDef.rankFromId]
            local rank, maxRank
            if rankSource then
                _, rank, maxRank = GetCachedSkill(rankSource)
            end
            local learned = proficiencyKnown or markedLearned
            local hasRanks = learned and rank and maxRank and maxRank > 0

            if learned then
                if registry then
                    registry.icon = weaponDef.icon
                    registry.tooltipTitle = displayName
                    registry.menuText = Color.GREEN .. displayName .. "|r"
                end

                if hasRanks then
                    if not sessionGains[displayName] then
                        sessionGains[displayName] = rank
                    end
                    return displayName, weaponDef.icon, rank, maxRank, true, true
                end

                return displayName, weaponDef.icon, 0, 0, true, false
            end

            if registry then
                registry.icon = weaponDef.icon
                registry.tooltipTitle = displayName
                registry.menuText = displayName .. " [" .. Color.YELLOW .. L["NOT_LEARNED"] .. "|r]"
            end

            return displayName, weaponDef.icon, 0, 0, false, false
        end

        local skillName, rank, maxRank = GetCachedSkill(weaponDef)
        local learned = skillName ~= nil or proficiencyKnown or markedLearned
        local hasRanks = skillName ~= nil and rank and maxRank and maxRank > 0 and not weaponDef.binary

        if learned then
            local title = skillName or displayName
            if registry then
                registry.icon = weaponDef.icon
                registry.tooltipTitle = title
                registry.menuText = Color.GREEN .. title .. "|r"
            end

            if skillName then
                if not sessionGains[skillName] then
                    sessionGains[skillName] = rank
                end
                return skillName, weaponDef.icon, rank, maxRank, true, hasRanks
            end

            -- Binary skills / spell-only / manual mark: no progressive ranks.
            return displayName, weaponDef.icon, 0, 0, true, false
        end

        if registry then
            registry.icon = weaponDef.icon
            registry.tooltipTitle = displayName
            registry.menuText = displayName .. " [" .. Color.YELLOW .. L["NOT_LEARNED"] .. "|r]"
        end

        return displayName, weaponDef.icon, 0, 0, false, false
    end

    local function ReloadPlugin()
        -- Ignore SKILL_LINES_CHANGED fired by our own Expand/CollapseSkillHeader calls.
        if refreshingCache then
            return
        end
        cacheDirty = true
        TitanPanelButton_UpdateButton(titanId)
    end

    local function TooltipDebug(stage, ...)
        if not tooltipDebug then
            return
        end
        local owner = GameTooltip:GetOwner()
        local point, rel, relPoint, x, y = GameTooltip:GetPoint(1)
        DEFAULT_CHAT_FRAME:AddMessage("|cffeda55fTWS tooltip:|r " .. weaponDef.id .. " " .. stage
            .. " | args=" .. select("#", ...)
            .. " | owner=" .. tostring(owner and owner.GetName and owner:GetName())
            .. " | shown=" .. tostring(GameTooltip:IsShown())
            .. " | lines=" .. tostring(GameTooltip:NumLines())
            .. " | alpha=" .. tostring(GameTooltip:GetAlpha())
            .. " | scale=" .. tostring(GameTooltip:GetScale())
            .. " | point=" .. tostring(point) .. "/" .. tostring(rel and rel.GetName and rel:GetName())
            .. "/" .. tostring(relPoint) .. " " .. tostring(x and math.floor(x)) .. "," .. tostring(y and math.floor(y))
            .. " | left=" .. tostring(GameTooltip:GetLeft() and math.floor(GameTooltip:GetLeft()))
            .. " bottom=" .. tostring(GameTooltip:GetBottom() and math.floor(GameTooltip:GetBottom()))
            .. " | strata=" .. tostring(GameTooltip:GetFrameStrata()))
    end

    local function CreateToolTip(...)
        TooltipDebug("called", ...)

        -- Titan Classic (TBC) hands us a tooltip without owner or anchor; attach it to our panel button.
        local button = _G["TitanPanel" .. titanId .. "Button"]
        if button and not GameTooltip:IsShown() then
            local _, centerY = button:GetCenter()
            local onBottomHalf = centerY
                and centerY * button:GetEffectiveScale() < UIParent:GetTop() * UIParent:GetEffectiveScale() / 2
            GameTooltip:SetOwner(button, onBottomHalf and "ANCHOR_TOP" or "ANCHOR_BOTTOM")
        end

        local name, _, level, maxLevel, learned, hasRanks = UpdateVars()

        GameTooltip:SetText(name or displayName, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)

        if learned and hasRanks then
            GameTooltip:AddLine(" ")

            local percent = (level / maxLevel) * 100
            GameTooltip:AddDoubleLine(L["SKILL"], GetSkillLevelColor(level, maxLevel) .. level .. "|r")
            GameTooltip:AddDoubleLine(L["MAXIMUM"], Color.WHITE .. maxLevel)
            GameTooltip:AddDoubleLine(L["PROGRESS"], string.format("%.1f%%", percent))

            local startLevel = sessionGains[name] or level
            local diff = level - startLevel
            if diff > 0 then
                GameTooltip:AddDoubleLine(L["THIS_SESSION"], Color.GREEN .. "+" .. diff)
            end

            if weaponDef.rankFromId then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["USES_UNARMED"], 0.7, 0.7, 0.7, true)
            end
        elseif learned then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["LEARNED"], 0.24, 0.86, 0.33, true)
            if weaponDef.rankFromId then
                GameTooltip:AddLine(L["USES_UNARMED"], 0.7, 0.7, 0.7, true)
            end
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["NOT_LEARNED"], 1, 1, 0.3, true)
        end

        GameTooltip:Show()

        if tooltipDebug then
            TooltipDebug("built")
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function() TooltipDebug("after 0.2s") end)
            end
        end
    end

    local function GetButtonText(self, id)
        local name, _, level, maxLevel, learned, hasRanks = UpdateVars(self.registry)

        if not learned then
            if not TitanGetVar(id, "ShowUnlearned") then
                return
            end
            return displayName .. ": ", Color.YELLOW .. L["NOT_LEARNED"]
        end

        if not hasRanks then
            return displayName .. ": ", Color.GREEN .. L["LEARNED"]
        end

        local showMax = TitanGetVar(id, "ShowMax")
        local showSession = TitanGetVar(id, "ShowSession")

        local maxText = ""
        if showMax then
            maxText = "|r/" .. Color.WHITE .. maxLevel
        end

        local sessionText = ""
        if showSession then
            local startLevel = sessionGains[name] or level
            local diff = level - startLevel
            if diff > 0 then
                sessionText = Color.GREEN .. " [+" .. diff .. "]"
            end
        end

        return name .. ": ", GetSkillLevelColor(level, maxLevel) .. level .. maxText .. sessionText .. "|r"
    end

    local button = Elib.Register({
        id = titanId,
        name = displayName,
        tooltip = displayName,
        icon = weaponDef.icon,
        category = "Combat",
        version = VERSION,
        getButtonText = GetButtonText,
        eventsTable = {
            SKILL_LINES_CHANGED = ReloadPlugin,
            PLAYER_ENTERING_WORLD = ReloadPlugin,
            CHAT_MSG_SKILL = ReloadPlugin,
            PLAYER_LEVEL_UP = ReloadPlugin,
            SPELLS_CHANGED = ReloadPlugin,
        },
        customTooltip = CreateToolTip,
        menus = menus,
    })

    -- Titan Classic (TBC) does not hide our custom tooltip when the mouse leaves the button.
    button:HookScript("OnLeave", function(self)
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
end

local function Initialize()
    local _, classToken = UnitClass("player")
    if not classToken then
        return
    end

    for _, weaponDef in ipairs(WEAPON_DEFS) do
        if weaponDef.classes[classToken] then
            CreateWeaponPlugin(weaponDef)
        end
    end
end

-- /tws debug: prints which skill API is in use and what each weapon lookup returns.
local function PrintDebug()
    local function out(msg)
        DEFAULT_CHAT_FRAME:AddMessage("|cffeda55fTWS:|r " .. msg)
    end

    out("v" .. VERSION .. " locale=" .. locale .. " isTBC=" .. tostring(isTBC)
        .. " build=" .. tostring(select(4, GetBuildInfo())))
    out("mode=" .. (API_GetSkillLineInfoByID and "skillId lookup" or "skill list")
        .. " | global GetNumSkillLines=" .. tostring(GetNumSkillLines ~= nil)
        .. " | C_SkillInfo=" .. tostring(C_SkillInfo ~= nil)
        .. " | ByID=" .. tostring(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID ~= nil))

    cacheDirty = true
    RefreshSkillCache()

    for _, def in ipairs(WEAPON_DEFS) do
        local line = def.id .. " (id " .. tostring(def.skillId) .. ")"
        if API_GetSkillLineInfoByID and def.skillId then
            local info = API_GetSkillLineInfoByID(def.skillId)
            if type(info) == "table" then
                local nameOk = def.nameLookup[info.name] and "ok" or "NAME MISMATCH"
                line = line .. ": " .. tostring(info.name) .. " " .. tostring(info.rank) .. "/"
                    .. tostring(info.maxRank) .. " [" .. nameOk .. "]"
            else
                line = line .. ": no data (not learned)"
            end
        else
            local name, rank, maxRank = GetCachedSkill(def)
            line = line .. ": " .. (name and (name .. " " .. rank .. "/" .. maxRank) or "not in list")
        end
        local known = IsWeaponProficiencyKnown(def)
        out(line .. (known and " | proficiency known" or "") .. (def.classes[select(2, UnitClass("player"))] and "" or " | (other class)"))
    end
end

SLASH_TITANWEAPONSKILLS1 = "/tws"
SlashCmdList["TITANWEAPONSKILLS"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg:match("^%s*debug") then
        PrintDebug()
    elseif msg:match("^%s*tooltip") then
        tooltipDebug = not tooltipDebug
        DEFAULT_CHAT_FRAME:AddMessage("|cffeda55fTWS:|r tooltip debug " .. (tooltipDebug and "ON" or "OFF"))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffeda55fTWS:|r /tws debug | /tws tooltip")
    end
end

-- Player info is available at load for character-specific addons; fall back if needed.
if UnitClass("player") then
    Initialize()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Initialize()
    end)
end
