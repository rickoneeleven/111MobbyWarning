-- Combined Version
local frame = CreateFrame("FRAME", "EnhancedWarningFrame")
local debugMode = 0  -- Set to 1 for debug messages, 0 to disable
local lastAlertTime = {
    nameplate = 0,
    target = 0
}
local COOLDOWN_DURATION = 60  -- Cooldown in seconds

local function debugPrint(message)
    if debugMode == 1 then
        print("[EnhancedWarning Debug]: " .. message)
    end
end

local function checkThreatLevel(unitToken)
    local targetLevel = UnitLevel(unitToken)
    local playerLevel = UnitLevel("player")
    local classification = UnitClassification(unitToken)
    local isElite = classification == "elite" or 
                    classification == "rareelite" or 
                    classification == "worldboss"
    
    debugPrint(string.format("Unit Check - Level: %s, Classification: %s", 
        tostring(targetLevel), tostring(classification)))
    
    return {
        isThreating = (targetLevel and playerLevel and (targetLevel >= playerLevel + 1)) or isElite,
        level = targetLevel,
        classification = classification,
        isElite = isElite
    }
end

local function showWarning(unitToken, warningType)
    local currentTime = GetTime()
    if currentTime - lastAlertTime[warningType] < COOLDOWN_DURATION then
        debugPrint("Warning suppressed due to cooldown")
        return
    end
    
    local threatInfo = checkThreatLevel(unitToken)
    if not threatInfo.isThreating then
        debugPrint("Unit not threatening enough for warning")
        return
    end
    
    local unitName = UnitName(unitToken)
    local eliteStatus = threatInfo.isElite and threatInfo.classification .. " " or ""
    local warningText = string.format("%s%s(Level %s) %s", 
        eliteStatus,
        unitName,
        tostring(threatInfo.level),
        warningType == "nameplate" and "nearby!" or "targeted!"
    )
    
    RaidNotice_AddMessage(RaidWarningFrame, warningText, ChatTypeInfo["RAID_WARNING"])
    PlaySound(SOUNDKIT.RAID_WARNING)
    lastAlertTime[warningType] = currentTime
    
    debugPrint("Warning displayed: " .. warningText)
end

local function handleTargetChange(self, event, ...)
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        debugPrint("Inside instance - warnings disabled")
        return
    end
    
    local target = "target"
    if not UnitExists(target) then return end
    
    if UnitIsPlayer(target) or not UnitIsEnemy("player", target) then
        debugPrint("Target is either a player or not an enemy - ignoring")
        return
    end
    
    showWarning(target, "target")
end

local function handleNamePlate(self, event, unitToken)
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        debugPrint("Inside instance - warnings disabled")
        return
    end
    
    if UnitIsPlayer(unitToken) or not UnitIsEnemy("player", unitToken) then
        debugPrint("Nameplate unit is either a player or not an enemy - ignoring")
        return
    end
    
    showWarning(unitToken, "nameplate")
end

-- Register events and handlers
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        handleTargetChange(self, event, ...)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        handleNamePlate(self, event, ...)
    end
end)

-- Optional: Add slash commands for runtime debug toggle
SLASH_ENHANCEDWARNING1 = "/ew"
SLASH_ENHANCEDWARNING2 = "/enhancedwarning"
SlashCmdList["ENHANCEDWARNING"] = function(msg)
    if msg == "debug" then
        debugMode = debugMode == 1 and 0 or 1
        print("Enhanced Warning debug mode: " .. (debugMode == 1 and "ON" or "OFF"))
    elseif msg == "help" then
        print("Enhanced Warning commands:")
        print("/ew debug - Toggle debug mode")
        print("/ew help - Show this help message")
    end
end