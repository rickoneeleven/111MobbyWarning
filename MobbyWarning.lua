-- Version 7
local frame = CreateFrame("FRAME", "MobbyWarningFrame")
local debugMode = 0  -- Set to 1 for debug messages, 0 to disable

local function debugPrint(message)  -- Version 1
    if debugMode == 1 then
        print(message)
    end
end

local function MobbyWarning(frame, event, ...)  -- Version 2
    -- Check if the player is in an instance and return early if so
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        debugPrint("Inside an instance, addon will not alter behaviour.")  -- Debug: Inform about instance
        return
    end

    debugPrint("Event fired: " .. event)  -- Debug: Check if the event is firing

    if event == "PLAYER_TARGET_CHANGED" then
        local targetLevel = UnitLevel("target")
        local playerLevel = UnitLevel("player")
        local isEnemy = UnitIsEnemy("player", "target")
        local isPlayer = UnitIsPlayer("target")
        local classification = UnitClassification("target")

        debugPrint("Target Level: " .. tostring(targetLevel))  -- Debug: Output target level
        debugPrint("Player Level: " .. tostring(playerLevel))  -- Debug: Output player level
        debugPrint("Is Enemy: " .. tostring(isEnemy))         -- Debug: Output if target is an enemy
        debugPrint("Is Player: " .. tostring(isPlayer))       -- Debug: Output if target is a player
        debugPrint("Classification: " .. tostring(classification))  -- Debug: Output target classification

        if isEnemy and not isPlayer and 
           ((targetLevel and playerLevel and (targetLevel >= playerLevel + 3)) or
           (classification == "elite")) then
            debugPrint("Condition met, showing warning.")  -- Debug: Check if condition is met
            local alertMessage = "Target: Level " .. tostring(targetLevel)  -- Change here
            RaidNotice_AddMessage(RaidWarningFrame, alertMessage, ChatTypeInfo["RAID_WARNING"])  -- Updated message
            PlaySound(SOUNDKIT.RAID_WARNING)  -- Replace SOUNDKIT.RAID_WARNING with the sound you want
        else
            debugPrint("Condition not met.")  -- Debug: Check if condition is not met
        end
    end
end

frame:SetScript("OnEvent", MobbyWarning)
frame:RegisterEvent("PLAYER_TARGET_CHANGED")