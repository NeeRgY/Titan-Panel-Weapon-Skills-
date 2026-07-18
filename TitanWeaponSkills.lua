---@diagnostic disable: duplicate-set-field

local ADDON_NAME = "TitanWeaponSkills"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "1.1.0"

local Elib = LibStub and LibStub("Elib-4.0", true)
if not Elib then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000TitanWeaponSkills:|r Elib-4.0 library not found!")
    return
end

local L = {}
local locale = GetLocale()

if locale == "deDE" then
    L["NO_WEAPON"] = "Keine"
    L["NOT_LEARNED"] = "Nicht gelernt, erlernbar"
    L["NO_WEAPON_SKILL"] = "Keine Waffenfertigkeit vorhanden"
    L["SKILL"] = "Fertigkeit"
    L["MAXIMUM"] = "Maximum"
    L["PROGRESS"] = "Fortschritt"
    L["THIS_SESSION"] = "Diese Sitzung"
    L["SHOW_MAX"] = "Maximum anzeigen"
    L["SHOW_SESSION"] = "Session-Fortschritt anzeigen"
    L["SHOW_UNLEARNED"] = "Ungelernte Fertigkeiten anzeigen"
else
    L["NO_WEAPON"] = "None"
    L["NOT_LEARNED"] = "Not learned, trainable"
    L["NO_WEAPON_SKILL"] = "No weapon skill available"
    L["SKILL"] = "Skill"
    L["MAXIMUM"] = "Maximum"
    L["PROGRESS"] = "Progress"
    L["THIS_SESSION"] = "This Session"
    L["SHOW_MAX"] = "Show Maximum"
    L["SHOW_SESSION"] = "Show Session Progress"
    L["SHOW_UNLEARNED"] = "Show Unlearned Skills"
end

local Color = {}
Color.WHITE = "|cFFFFFFFF"
Color.RED = "|cFFDC2924"
Color.YELLOW = "|cFFFFF244"
Color.GREEN = "|cFF3DDC53"
Color.ORANGE = "|cFFFFA500"
Color.GRAY = "|cFF888888"

-- Project detection (Classic Era vs TBC Classic)
local isTBC = false
do
    local projectId = WOW_PROJECT_ID
    if projectId and WOW_PROJECT_BURNING_CRUSADE_CLASSIC and projectId == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        isTBC = true
    else
        local build = select(4, GetBuildInfo())
        if build and build >= 20000 and build < 30000 then
            isTBC = true
        end
    end
end

--[[
    Stable weapon definitions.
    names: exact localized skill line names (must be exact to avoid Axes vs Two-Handed Axes).
    classes: English class tokens that can learn this skill.
]]
local WEAPON_DEFS = {
    {
        id = "AXES",
        icon = "Interface\\Icons\\INV_Axe_06",
        names = {
            enUS = "Axes", deDE = "Äxte", frFR = "Haches", esES = "Hachas", esMX = "Hachas",
            ruRU = "Топоры", zhCN = "斧", zhTW = "斧", koKR = "도끼",
        },
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, SHAMAN = true },
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
        classes = { WARRIOR = true, PALADIN = true, HUNTER = true, DRUID = true },
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
        classes = { WARRIOR = true, HUNTER = true, ROGUE = true, SHAMAN = true, DRUID = true },
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
            enUS = "Bows", deDE = "Bögen", frFR = "Arcs", esES = "Arcos", esMX = "Arcos",
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
        -- Hunter dual wield is TBC+; Classic Era hunters cannot learn it.
        classes = isTBC
            and { WARRIOR = true, HUNTER = true, ROGUE = true }
            or { WARRIOR = true, ROGUE = true },
    },
}

local sessionGains = {}
local skillCache = {}
local cacheDirty = true

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

for _, def in ipairs(WEAPON_DEFS) do
    def.nameLookup = BuildNameLookup(def)
    def.displayName = GetDisplayName(def)
end

local function RefreshSkillCache()
    wipe(skillCache)

    -- Expand collapsed headers backwards so inserted rows do not shift unread indices.
    local collapsedHeaders = {}
    for i = GetNumSkillLines() or 0, 1, -1 do
        local skillName, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded and skillName then
            collapsedHeaders[skillName] = true
            ExpandSkillHeader(i)
        end
    end

    for i = 1, GetNumSkillLines() or 0 do
        local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
        if skillName and not isHeader and skillRank and skillRank > 0 then
            skillCache[skillName] = {
                rank = skillRank,
                maxRank = skillMaxRank or 0,
            }
        end
    end

    -- Restore previously collapsed headers (backwards again).
    for i = GetNumSkillLines() or 0, 1, -1 do
        local skillName, isHeader = GetSkillLineInfo(i)
        if isHeader and skillName and collapsedHeaders[skillName] then
            CollapseSkillHeader(i)
        end
    end

    cacheDirty = false
end

local function GetCachedSkill(weaponDef)
    if cacheDirty then
        RefreshSkillCache()
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
    { type = "rightSideToggle" },
}

local function CreateWeaponPlugin(weaponDef)
    local titanId = "TITAN_WEAPONSKILL_" .. weaponDef.id
    local displayName = weaponDef.displayName

    local function UpdateVars(registry)
        local skillName, rank, maxRank = GetCachedSkill(weaponDef)

        if skillName then
            if registry then
                registry.icon = weaponDef.icon
                registry.tooltipTitle = skillName
                registry.menuText = Color.GREEN .. skillName .. "|r"
            end

            if not sessionGains[skillName] then
                sessionGains[skillName] = rank
            end

            return skillName, weaponDef.icon, rank, maxRank, true
        end

        if registry then
            registry.icon = weaponDef.icon
            registry.tooltipTitle = displayName
            registry.menuText = displayName .. " [" .. Color.YELLOW .. L["NOT_LEARNED"] .. "|r]"
        end

        return displayName, weaponDef.icon, 0, 0, false
    end

    local function ReloadPlugin()
        cacheDirty = true
        TitanPanelButton_UpdateButton(titanId)
    end

    local function CreateToolTip()
        local name, _, level, maxLevel, learned = UpdateVars()

        GameTooltip:SetText(name or displayName, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)

        if learned and maxLevel and maxLevel > 0 then
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
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["NOT_LEARNED"], 1, 1, 0.3, true)
        end
    end

    local function GetButtonText(self, id)
        local name, _, level, maxLevel, learned = UpdateVars(self.registry)

        if not learned then
            if not TitanGetVar(id, "ShowUnlearned") then
                return
            end
            return displayName .. ": ", Color.YELLOW .. L["NOT_LEARNED"]
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

    Elib.Register({
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
        },
        customTooltip = CreateToolTip,
        menus = menus,
    })
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
