local _, ns = ...
local L = ns.L
local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then return end

L["NO_WEAPON"] = "Ninguna"
L["NOT_LEARNED"] = "No aprendida, entrenable"
L["LEARNED"] = "Aprendida"
L["NO_WEAPON_SKILL"] = "No hay habilidad de arma disponible"
L["SKILL"] = "Habilidad"
L["MAXIMUM"] = "Máximo"
L["PROGRESS"] = "Progreso"
L["THIS_SESSION"] = "Esta sesión"
L["SHOW_MAX"] = "Mostrar máximo"
L["SHOW_SESSION"] = "Mostrar progreso de sesión"
L["SHOW_UNLEARNED"] = "Mostrar habilidades no aprendidas"
L["MARK_LEARNED"] = "Marcar como aprendida"
L["USES_UNARMED"] = "La probabilidad de golpe y el progreso usan Sin armas"
