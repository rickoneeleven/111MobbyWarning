-- Combined Version
local frame = CreateFrame("FRAME", "EnhancedWarningFrame")
local debugMode = 0  -- Set to 1 for debug messages, 0 to disable
local lastAlertTime = {
    nameplate = 0
}
local TARGET_RECHECK_DELAY = 0.15  -- Retry target check once when unit data is delayed
local ALERT_SOUND = SOUNDKIT.RAID_WARNING
local db
local minimapButton
local settingsFrameRef

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

local function debugPrint(message)
    if debugMode == 1 then
        print("[EnhancedWarning Debug]: " .. message)
    end
end

local function initDB()
    CombinedMobWarningDB = CombinedMobWarningDB or {}
    db = CombinedMobWarningDB
    db.levelDiffThreshold = db.levelDiffThreshold or 1
    db.nameplateCooldown = db.nameplateCooldown or 60
    db.sleepUntil = db.sleepUntil or 0
    db.minimapAngle = db.minimapAngle or 225
end

local function isSleeping()
    return GetTime() < (db.sleepUntil or 0)
end

local function sleepFor(seconds)
    db.sleepUntil = GetTime() + seconds
    print(string.format("Enhanced Warning: alerts paused for %d minutes.", math.floor(seconds / 60)))
end

local function wakeAlerts()
    db.sleepUntil = 0
    print("Enhanced Warning: alerts resumed.")
end

local function checkThreatLevel(unitToken)
    local targetLevel = UnitLevel(unitToken)
    local playerLevel = UnitLevel("player")
    local classification = UnitClassification(unitToken)
    local isElite = classification == "elite" or
                    classification == "rareelite" or
                    classification == "worldboss"

    local levelDiff = 0
    local missingLevelData = false

    if targetLevel and targetLevel > 0 and playerLevel and playerLevel > 0 then
        levelDiff = targetLevel - playerLevel
    elseif targetLevel == -1 then
        levelDiff = 10  -- Skull level unit, treat as high threat.
    else
        missingLevelData = true
    end

    debugPrint(string.format(
        "Unit Check - Level: %s, Player: %s, Diff: %s, Classification: %s",
        tostring(targetLevel),
        tostring(playerLevel),
        tostring(levelDiff),
        tostring(classification)
    ))

    return {
        isThreatening = (levelDiff >= db.levelDiffThreshold) or isElite,
        level = targetLevel,
        classification = classification,
        isElite = isElite,
        levelDiff = levelDiff,
        missingLevelData = missingLevelData
    }
end

local function isAttackableNPC(unitToken, sourceLabel)
    if UnitIsPlayer(unitToken) then
        debugPrint(sourceLabel .. ": unit is player - ignoring")
        return false
    end

    if not UnitCanAttack("player", unitToken) then
        debugPrint(sourceLabel .. ": unit not attackable - ignoring")
        return false
    end

    return true
end

local function playThreatBeeps(levelDiff)
    local beepCount = math.max(1, levelDiff or 1)
    beepCount = math.min(beepCount, 10)

    if C_Timer and C_Timer.After then
        for i = 1, beepCount do
            C_Timer.After((i - 1) * 0.12, function()
                PlaySound(ALERT_SOUND)
            end)
        end
    else
        for _ = 1, beepCount do
            PlaySound(ALERT_SOUND)
        end
    end
end

local function showWarning(unitToken, warningType)
    local currentTime = GetTime()
    if isSleeping() then
        debugPrint("Warning suppressed due to sleep mode")
        return false, nil
    end

    if warningType == "nameplate" and (currentTime - lastAlertTime.nameplate) < db.nameplateCooldown then
        debugPrint("Nameplate warning suppressed due to cooldown")
        return false, nil
    end

    local threatInfo = checkThreatLevel(unitToken)
    if not threatInfo.isThreatening then
        debugPrint("Unit not threatening enough for warning")
        return false, threatInfo
    end

    local unitName = UnitName(unitToken) or "Unknown"
    local eliteStatus = threatInfo.isElite and (threatInfo.classification .. " ") or ""
    local displayLevel = (threatInfo.level and threatInfo.level > 0) and tostring(threatInfo.level) or "??"
    local warningText = string.format(
        "%s%s (Level %s, +%d) %s",
        eliteStatus,
        unitName,
        displayLevel,
        math.max(0, threatInfo.levelDiff),
        warningType == "nameplate" and "nearby!" or "targeted!"
    )

    RaidNotice_AddMessage(RaidWarningFrame, warningText, ChatTypeInfo["RAID_WARNING"])
    playThreatBeeps(threatInfo.levelDiff)
    if warningType == "nameplate" then
        lastAlertTime.nameplate = currentTime
    end

    debugPrint("Warning displayed: " .. warningText)
    return true, threatInfo
end

local function handleTargetChange()
    local inInstance = IsInInstance()
    if inInstance then
        debugPrint("Inside instance - warnings disabled")
        return
    end

    local target = "target"
    if not UnitExists(target) then return end
    if not isAttackableNPC(target, "Target") then return end

    local alerted, threatInfo = showWarning(target, "target")

    -- Sometimes level/classification data is not fully available on first target event.
    -- Re-check once shortly after targeting to catch valid warnings we might miss.
    if (not alerted) and threatInfo and threatInfo.missingLevelData and C_Timer and C_Timer.After then
        local targetGUID = UnitGUID(target)
        C_Timer.After(TARGET_RECHECK_DELAY, function()
            if not UnitExists("target") then return end
            if UnitGUID("target") ~= targetGUID then return end
            if not isAttackableNPC("target", "Target recheck") then return end
            showWarning("target", "target")
        end)
    end
end

local function handleNamePlate(unitToken)
    local inInstance = IsInInstance()
    if inInstance then
        debugPrint("Inside instance - warnings disabled")
        return
    end

    if not isAttackableNPC(unitToken, "Nameplate") then return end
    showWarning(unitToken, "nameplate")
end

local function updateMinimapButtonPosition(button)
    if not Minimap then return end
    local angle = db.minimapAngle or 225
    local radius = 80
    local radians = math.rad(angle)
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function createSettingsFrame()
    local settingsFrame = CreateFrame("Frame", "EnhancedWarningSettingsFrame", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(300, 200)
    settingsFrame:SetPoint("CENTER")
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:Hide()

    settingsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    settingsFrame:SetBackdropColor(0, 0, 0, 0.9)

    local header = CreateFrame("Frame", nil, settingsFrame)
    header:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -8, -8)
    header:SetHeight(34)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        settingsFrame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        settingsFrame:StopMovingOrSizing()
    end)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints(true)
    headerBg:SetColorTexture(0.1, 0.1, 0.1, 0.75)

    local closeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        settingsFrame:Hide()
    end)

    settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    settingsFrame.title:SetPoint("CENTER", header, "CENTER", 0, 0)
    settingsFrame.title:SetText("Enhanced Warning")

    local slider = CreateFrame("Slider", "EnhancedWarningLevelDiffSlider", settingsFrame, "OptionsSliderTemplate")
    slider:SetPoint("TOP", settingsFrame, "TOP", 0, -50)
    slider:SetMinMaxValues(1, 10)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)
    slider:SetValue(db.levelDiffThreshold)
    _G[slider:GetName() .. "Low"]:SetText("1")
    _G[slider:GetName() .. "High"]:SetText("10")
    _G[slider:GetName() .. "Text"]:SetText("Min Level Diff To Alert")

    local valueText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -8)
    valueText:SetText(string.format("Current: +%d", db.levelDiffThreshold))

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor(value + 0.5)
        db.levelDiffThreshold = rounded
        self:SetValue(rounded)
        valueText:SetText(string.format("Current: +%d", rounded))
    end)

    local sleepButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    sleepButton:SetSize(120, 24)
    sleepButton:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 18, 20)
    sleepButton:SetText("Sleep 2 Min")
    sleepButton:SetScript("OnClick", function()
        sleepFor(120)
    end)

    local wakeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    wakeButton:SetSize(120, 24)
    wakeButton:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -18, 20)
    wakeButton:SetText("Wake Now")
    wakeButton:SetScript("OnClick", function()
        wakeAlerts()
    end)

    local sleepStatus = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sleepStatus:SetPoint("BOTTOM", settingsFrame, "BOTTOM", 0, 54)
    sleepStatus:SetText("Alerts Active")

    settingsFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.2 then return end
        self.elapsed = 0

        local remaining = math.floor((db.sleepUntil or 0) - GetTime())
        if remaining > 0 then
            sleepStatus:SetText(string.format("Sleeping: %ds remaining", remaining))
        else
            sleepStatus:SetText("Alerts Active")
        end
    end)

    return settingsFrame
end

local function createMinimapButton(settingsFrame)
    if not Minimap then return nil end
    local button = CreateFrame("Button", "EnhancedWarningMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_DeathScream")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Enhanced Warning", 1, 1, 1)
        GameTooltip:AddLine("Left click: Open settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right click: Sleep alerts 2 min", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cx = cx / scale
            cy = cy / scale
            local angle = math.deg(atan2(cy - my, cx - mx))
            if angle < 0 then
                angle = angle + 360
            end
            db.minimapAngle = angle
            updateMinimapButtonPosition(self)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            sleepFor(120)
            return
        end

        if settingsFrame:IsShown() then
            settingsFrame:Hide()
        else
            settingsFrame:Show()
        end
    end)

    updateMinimapButtonPosition(button)
    button:Show()
    return button
end

local function initializeUI()
    settingsFrameRef = createSettingsFrame()
    minimapButton = createMinimapButton(settingsFrameRef)
end

-- Register events and handlers
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        initDB()
        initializeUI()
    elseif not db then
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        handleTargetChange()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unitToken = ...
        handleNamePlate(unitToken)
    end
end)

-- Optional: Add slash commands for runtime debug toggle
SLASH_ENHANCEDWARNING1 = "/ew"
SLASH_ENHANCEDWARNING2 = "/enhancedwarning"
SlashCmdList["ENHANCEDWARNING"] = function(msg)
    local command = string.lower((msg or ""):match("^%s*(.-)%s*$"))
    if command == "debug" then
        debugMode = debugMode == 1 and 0 or 1
        print("Enhanced Warning debug mode: " .. (debugMode == 1 and "ON" or "OFF"))
    elseif command == "sleep" then
        sleepFor(120)
    elseif command == "wake" then
        wakeAlerts()
    elseif command == "resetbutton" then
        if not db then
            print("Enhanced Warning: not initialized yet.")
            return
        end
        db.minimapAngle = 225
        if minimapButton then
            updateMinimapButtonPosition(minimapButton)
            minimapButton:Show()
        end
        print("Enhanced Warning: minimap button reset.")
    else
        print("Enhanced Warning commands:")
        print("/ew debug - Toggle debug mode")
        print("/ew sleep - Pause alerts for 2 minutes")
        print("/ew wake - Resume alerts")
        print("/ew resetbutton - Reset minimap button position")
    end
end
