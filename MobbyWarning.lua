-- Version 6
local frame = CreateFrame("FRAME", "MobbyWarningFrame")
local debugMode = 0  -- Set to 1 for debug messages, 0 to disable

local function debugPrint(message)
    if debugMode == 1 then
        print(message)
    end
end

local function MobbyWarning(frame, event, ...)
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
           ((targetLevel and playerLevel and (targetLevel >= playerLevel + 1)) or
           (classification == "elite")) then
            debugPrint("Condition met, showing warning.")  -- Debug: Check if condition is met
            RaidNotice_AddMessage(RaidWarningFrame, "WARNING, BIG, BAD, MOBBY", ChatTypeInfo["RAID_WARNING"])
            PlaySound(SOUNDKIT.RAID_WARNING)  -- Replace SOUNDKIT.RAID_WARNING with the sound you want
        else
            debugPrint("Condition not met.")  -- Debug: Check if condition is not met
        end
    end
end

frame:SetScript("OnEvent", MobbyWarning)
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
