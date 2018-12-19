--[[
    Special thanks to Niseko for code help.  You can find his WA located here: https://wago.io/rk7idBBoX
]]--

HTMT = LibStub("AceAddon-3.0"):NewAddon("HighTideManaTracker", "AceConsole-3.0", "AceEvent-3.0")

-- extra Ace libs
local AceGUI = LibStub("AceGUI-3.0")

-- variables used to handle the tracking of mana spent
local manaTrigger = 40000
local manaCount = 0
local manaCountInverse = 40000
local formatTableOptions = {}
ui_reload=false
ui_logout=false
ui_quit=false

-- function to hook into /reloadui command
function UI_Reloading()
     ui_reload=true
end

function UI_LogingOut()
    ui_logout=true
end
function UI_Quitting()
    ui_quit=true
end

hooksecurefunc("Logout", UI_LogingOut)
hooksecurefunc("Quit", UI_Quitting)
hooksecurefunc("ReloadUI", UI_Reloading)


-- register for specific events from wow using AceEvent
function HTMT:OnEnable()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("ENCOUNTER_START", "Encounter_Start")
    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- register slash commands
function HTMT:OnInitialize()
    self:RegisterChatCommand('htmt', 'SlashCommands')
end

-- Handle the initialization of values from nil to 0 first time addon is loaded.
function HTMT:ADDON_LOADED()
    if manaUsed == nil then
        manaUsed = 0
    end
    if manaUsedInverse == nil then
        manaUsedInverse = 40000
    end
    if reloadedUI == nil then
        reloadedUI = false
    end
    if zones == nil or table.getn(zones) < 5 then
        zones = {"Uldir", "Battle for Dazar'alor", "Crucible of Storms", "Arathi Highlands", "Tiragarde Sound"}
    end
    if menuOptions == nil then
        menuOptions = {}
        menuOptions.dropdownValue = 1
    end
    if textFormatOptions == nil or table.getn(textFormatOptions) < 10 then
        textFormatOptions = {"25,350", "25350 : 40k", "25350 / 40k", "25.35k", "25.35k : 40k", "25.35k / 40k","25.4k", "25.4k : 40k", "25.4k / 40k"}
    end
    if textFontOptions == nil then
        textFontOptions = {}
    end
end

-- reset manaCount on encounter start
function HTMT:Encounter_Start(...)
    local difficultyID = select(4,...)
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end
    if difficultyID ~= 14 or difficultyID ~= 15 or difficultyID ~= 16 or difficultyID ~= 17 then
        return  
    end
    if menuOptions.inverseCheckButton then
        manaCount = 0
        manaUsed = 0
        HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
        self:Print("Mana has been reset!")
    else
        manaCountInverse = 40000
        manaUsedInverse = 40000
        HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
        self:Print("Mana has been reset!")  
    end
end
-- function HTMT:ENCOUNTER_START()
--     --local specID = select(1, GetSpecializationInfo(GetSpecialization()))
--     if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end

--     local zone = GetZoneText()
--     local subZone = GetSubZoneText()

--     if menuOptions.inverseCheckButton then
--         for i,v in ipairs(zones) do
--             if zone == v then
--                 manaCountInverse = 40000
--                 manaUsedInverse = 40000
--                 HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
--                 self:Print("Mana has been reset!")  
--             end
--         end
--     else
--         for i,v in ipairs(zones) do
--             if zone == v then
--                 manaCount = 0
--                 manaUsed = 0
--                 HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
--                 self:Print("Mana has been reset!")
--             end
--         end
--     end
-- end

-- reset manaCount on swapping to high tide
function HTMT:PLAYER_TALENT_UPDATE()
    local specID = select(1, GetSpecializationInfo(GetSpecialization()))
    if specID ~= 264 then
        htmtManaTracker:Hide()
        return
    else
        htmtManaTracker:Show()
    end
    local learned = select(10,GetTalentInfoBySpecialization(3,7,1))
    if menuOptions.inverseCheckButton then
        if not learned then
            manaCountInverse = 40000
            manaUsedInverse = 40000
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
            htmtManaTracker:Hide()
            self:Print("Mana has been reset!")
        else
            htmtManaTracker:Show()
        end
    else
        if not learned then
            manaCount = 0
            manaUsed = 0
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
            htmtManaTracker:Hide()
            self:Print("Mana has been reset!")
        else
            htmtManaTracker:Show()
        end
    end

end

-- main driver behind tracking mana spent towards high tide
function HTMT:COMBAT_LOG_EVENT_UNFILTERED()
    -- local specID = select(1, GetSpecializationInfo(GetSpecialization()))
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end
    local learned = select(10,GetTalentInfoBySpecialization(3,7,1))
    local subevent = select(2, CombatLogGetCurrentEventInfo())
    local sourceGUID = select(4, CombatLogGetCurrentEventInfo())
    local spellID = select(12, CombatLogGetCurrentEventInfo())

    if subevent == "SPELL_CAST_SUCCESS" and (sourceGUID == UnitGUID("player")) and learned then
        local costs = GetSpellPowerCost(spellID)
        if costs then
            for _, costInfo in ipairs(costs) do -- this for loop credit to Niseko
                if (costInfo.type == UnitPowerType("player")) then
                    local spellCost = costInfo.cost
                    if spellCost ~= 0 then
                        if menuOptions.inverseCheckButton then
                            manaCountInverse = manaCountInverse - costs[1].cost
                            manaUsedInverse = manaCountInverse
                            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
                        else
                            manaCount = manaCount + costs[1].cost
                            manaUsed = manaCount
                            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
                        end
                    end
                end
            end
        end
    end
    if menuOptions.inverseCheckButton then
        if manaCountInverse <= 0 then
            manaCountInverse = manaCountInverse + manaTrigger
            manaUsedInverse = manaCountInverse
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
        end
    else
        if manaCount >= manaTrigger then
            manaCount = manaCount - manaTrigger
            manaUsed = manaCount
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
        end
    end
end

-- check if reloadui was true and if was restore manaCount value otherwise was logout/login so reset to 0
function HTMT:PLAYER_ENTERING_WORLD()
    -- local specID = select(1, GetSpecializationInfo(GetSpecialization()))
    local learned = select(10,GetTalentInfoBySpecialization(3,7,1))
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 or learned ~= true then 
        htmtManaTracker:Hide()
    end
    if menuOptions.textColorPicker then 
        htmtManaTrackerManaCount:SetTextColor(menuOptions.textColorPicker[1], menuOptions.textColorPicker[2], menuOptions.textColorPicker[3], menuOptions.textColorPicker[4]) 
    else
        htmtManaTrackerManaCount:SetTextColor(255,255,255)
    end
    if menuOptions.manaTrackerSize then
        HTMT_SetTrackerSizeOnLogin()
    end
    if menuOptions.lockFrameCheckButton then
        htmtManaTracker:EnableMouse(false)
    else
        htmtManaTracker:EnableMouse(true)
    end
    if reloadedUI and (ui_logout ~= true) and (ui_quit ~= true) then
        if menuOptions.inverseCheckButton then
            manaCountInverse = manaUsedInverse
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
        else
            manaCount = manaUsed
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
        end
    else
        if menuOptions.inverseCheckButton then
            manaCountInverse = 40000
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
        else
            manaCount = 0
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
        end
    end
end

-- check for if ui_reload happened, if yes then store manaCount and true for reloadUI otherwise 0 and false
function HTMT:PLAYER_LEAVING_WORLD()
    if ui_reload or (ui_logout ~= true) and (ui_quit ~= true) then 
        if menuOptions.inverseCheckButton then
            manaUsedInverse = manaCountInverse
            reloadedUI = true
        else
            manaUsed = manaCount
            reloadedUI = true
        end
    else
        manaUsedInverse = 40000
        reloadedUI = false
        manaUsed = 0
    end
end

-- handle the addons slash commands
function HTMT:SlashCommands(input)
    --local specID = select(1, GetSpecializationInfo(GetSpecialization()))
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end
    input = string.lower(input)
    local command,value,_ = strsplit(" ", input)

    if command == "" then
        HTMT_ToggleMenu()
    elseif command == "show" then
        htmtManaTracker:Show()
        HTMT:Print("ManaTracker is now being shown!")
    elseif command == "hide" then
        htmtManaTracker:Hide()
        HTMT:Print("ManaTracker is now being hidden!")
    elseif command == "inverse" then
        if menuOptions.inverseCheckButton then
            menuOptions.inverseCheckButton = false
            manaCountInverse = manaTrigger - manaUsed
            manaUsedInverse = manaCountInverse
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
        else
            menuOptions.inverseCheckButton = true
            manaCount = manaTrigger - manaUsedInverse
            manaUsed = manaCount
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
        end
    elseif command == "lock" then
        if menuOptions.lockFrameCheckButton then
            menuOptions.lockFrameCheckButton = false
            htmtManaTracker:EnableMouse(true)
        else
            menuOptions.lockFrameCheckButton = true
            htmtManaTracker:EnableMouse(false)
        end
    elseif command == "help" then
        HTMT:Print("\tHigh Tide Mana Tracker")
        HTMT:Print("\"/htmt\" - to open the options menu!")
        HTMT:Print("\"/htmt show\" - to show the tracker if hidden!")
        HTMT:Print("\"/htmt hide\" - to hide the tracker if shown!")
        HTMT:Print("\"/htmt inverse\" - to swap between counting up or down!")
        HTMT:Print("\"/htmt lock\" -  to lock or unlock the tracker window!")
        HTMT:Print("==========================================")
    end

end

function comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function HTMT_UpdateTextNonProgressBar(manaValue, formatType, fontType)
    if formatType == 1 then
        -- display text in this format
        manaValue = comma_value(manaValue)
        htmtManaTrackerManaCount:SetText(manaValue)
    elseif formatType == 2 then
        -- display text in this format
        local manaString = tostring(manaValue)
        manaString = manaString .. " : 40k"
        htmtManaTrackerManaCount:SetText(manaString)
    elseif formatType == 3 then
        -- display text in this format
        local manaString = tostring(manaValue)
        manaString = manaString .. " / 40k"
        htmtManaTrackerManaCount:SetText(manaString)
    elseif formatType == 4 then
        -- display text in this format
        local manaString = tostring(manaValue/1000)
        manaString = manaString .. "k"
        htmtManaTrackerManaCount:SetText(manaString)
    elseif formatType == 5 then
        -- display text in this format
        local manaString = tostring(manaValue/1000)
        manaString = manaString .. "k : 40k"
        htmtManaTrackerManaCount:SetText(manaString)
    elseif formatType == 6 then
        -- display text in this format
        local manaString = tostring(manaValue/1000)
        manaString = manaString .. "k / 40k"
        htmtManaTrackerManaCount:SetText(manaString)
    elseif formatType == 7 then
        -- display text in this format
        manaValue = tonumber(string.format("%." .. (1) .. "f", (manaValue/1000)))
        local manaString = tostring(manaValue)
        manaString = manaString .. "k"
        htmtManaTrackerManaCount:SetText(manaString)
    elseif formatType == 8 then
        -- display text in this format
        manaValue = tonumber(string.format("%." .. (1) .. "f", (manaValue/1000)))
        local manaString = tostring(manaValue)
        manaString = manaString .. "k : 40k"
        htmtManaTrackerManaCount:SetText(manaString)
    else
        -- display text in this format
        manaValue = tonumber(string.format("%." .. (1) .. "f", (manaValue/1000)))
        local manaString = tostring(manaValue)
        manaString = manaString .. "k / 40k"
        htmtManaTrackerManaCount:SetText(manaString)
    end
end

function HTMT_ToggleMenu()
    if not HTMT.menu then HTMT:CreateOptionsMenu() end
    if HTMT.menu:IsShown() then
        HTMT.menu:Hide()
        HTMT:Print("Options menu hidden, for other commands use \"/htmt help\"")
    else
        HTMT.menu:Show()
        HTMT:Print("Options menu loaded, for other commands use \"/htmt help\"")
    end
end

function HTMT_SaveCheckBoxState(widget, event, value)
    menuOptions.inverseCheckButton = value
    if value then
        manaCountInverse = manaTrigger - manaUsed
        manaUsedInverse = manaCountInverse
        HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
    else
        manaCount = manaTrigger - manaUsedInverse
        manaUsed = manaCount
        HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
    end
end

function HTMT_SaveProgressBarCheckBoxState(widget, event, value)
    menuOptions.progressBarCheckButton = value
end

function HTMT_ColorPickerConfirmed(widget, event, r, g, b, a)
    menuOptions.textColorPicker = {r,g,b,a}
    htmtManaTrackerManaCount:SetTextColor(r,g,b,a)
end

function HTMT_DropdownState(widget, event, key, checked)
    menuOptions.dropdownValue = key
    if menuOptions.inverseCheckButton then
        HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
    else
        HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
    end
end

function HTMT_LockFrameCheckBoxState(widget, event, value)
    menuOptions.lockFrameCheckButton = value
    if menuOptions.lockFrameCheckButton then
        htmtManaTracker:EnableMouse(false)
    else
        htmtManaTracker:EnableMouse(true)
    end
end

function HTMT_ResizeFrameSliderUpdater(widget, event, value)
    menuOptions.textFrameSizeSlider = value
    local multiplier = value
    local width = 100 + (multiplier * 100)
    local height = 40 + (multiplier * 40)
    local fontVal = 16 + (multiplier * 16)
    htmtManaTracker:SetWidth(width)
    htmtManaTracker:SetHeight(height)
    htmtManaTrackerManaCount:SetSize(width, height)
    htmtManaTrackerManaCount:SetFont("Fonts\\MORPHEUS.ttf",fontVal)
    --htmtManaTrackerManaCount:SetTextHeight(fontVal)
    menuOptions.fontVal = fontVal
end

function HTMT_SetTrackerSizeOnLogin()
    if table.getn(menuOptions.manaTrackerSize) == 2 and menuOptions.fontVal then
        htmtManaTracker:SetWidth(menuOptions.manaTrackerSize[1])
        htmtManaTracker:SetHeight(menuOptions.manaTrackerSize[2])
        htmtManaTrackerManaCount:SetSize(menuOptions.manaTrackerSize[1], menuOptions.manaTrackerSize[2])
        htmtManaTrackerManaCount:SetFont("Fonts\\MORPHEUS.ttf",menuOptions.fontVal)
        --htmtManaTrackerManaCount:SetTextHeight(menuOptions.fontVal)
    end
end

function HTMT_ResizeFrameSliderDone(widget, event, value)
    menuOptions.textFrameSizeSlider = value
    menuOptions.manaTrackerSize = {htmtManaTracker:GetWidth(), htmtManaTracker:GetHeight()}
end

function HTMT:CreateOptionsMenu()
    -- grab localization if available
    local L = LibStub("AceLocale-3.0"):GetLocale("htmtMenuTranslations")

    local menu = AceGUI:Create("Frame")
    menu:SetTitle("High Tide Mana Tracker Options")
    menu:SetStatusText("v2.3")
    menu:SetWidth(250)
    menu:SetHeight(250)
    menu:SetLayout("Flow")
    menu:Hide()
    HTMT.menu = menu

    HTMT_menu = menu.frame
    menu.frame:SetMaxResize(250, 250)
    menu.frame:SetFrameStrata("HIGH")
    menu.frame:SetFrameLevel(1)

    local inverseCheckButton = AceGUI:Create("CheckBox")
    inverseCheckButton:SetLabel(L["Inverse"])
    inverseCheckButton:SetWidth(80)
    inverseCheckButton:SetHeight(22)
    inverseCheckButton:SetType("checkbox")
    inverseCheckButton:ClearAllPoints()
    if menuOptions.inverseCheckButton then inverseCheckButton:SetValue(menuOptions.inverseCheckButton)end
    inverseCheckButton:SetPoint("TOPLEFT", menu.frame, "TOPLEFT",6,0)
    inverseCheckButton:SetCallback("OnValueChanged",HTMT_SaveCheckBoxState)
    menu:AddChild(inverseCheckButton)
    menu.inverseCheckButton = inverseCheckButton

    -- local progressBarCheckButton = AceGUI:Create("CheckBox")
    -- progressBarCheckButton:SetLabel("Progress Bar")
    -- progressBarCheckButton:SetWidth(125)
    -- progressBarCheckButton:SetHeight(22)
    -- progressBarCheckButton:SetType("checkbox")
    -- progressBarCheckButton:ClearAllPoints()
    -- if menuOptions.progressBarCheckButton then progressBarCheckButton:SetValue(menuOptions.progressBarCheckButton)end
    -- progressBarCheckButton:SetPoint("TOPLEFT", menu.frame, "TOPLEFT",6,-25)
    -- progressBarCheckButton:SetCallback("OnValueChanged",HTMT_SaveProgressBarCheckBoxState)
    -- menu:AddChild(progressBarCheckButton)
    -- menu.progressBarCheckButton = progressBarCheckButton

    -- checkbox for locking the frames position
    local lockFrameCheckButton = AceGUI:Create("CheckBox")
    lockFrameCheckButton:SetLabel(L["Lock"])
    lockFrameCheckButton:SetWidth(80)
    lockFrameCheckButton:SetHeight(22)
    lockFrameCheckButton:SetType("checkbox")
    lockFrameCheckButton:ClearAllPoints()
    if menuOptions.lockFrameCheckButton then lockFrameCheckButton:SetValue(menuOptions.lockFrameCheckButton)end
    lockFrameCheckButton:SetPoint("TOPLEFT", menu.frame, "TOPLEFT",6,-25)
    lockFrameCheckButton:SetCallback("OnValueChanged",HTMT_LockFrameCheckBoxState)
    menu:AddChild(lockFrameCheckButton)
    menu.inverseCheckButton = inverseCheckButton

    local textColorPicker = AceGUI:Create("ColorPicker")
    if menuOptions.textColorPicker then 
        textColorPicker:SetColor(menuOptions.textColorPicker[1], menuOptions.textColorPicker[2], menuOptions.textColorPicker[3], menuOptions.textColorPicker[4]) 
    else
        textColorPicker:SetColor(255,255,255)
    end
    textColorPicker:SetLabel(L["Text Color"])
    textColorPicker:ClearAllPoints()
    textColorPicker:SetPoint("TOPLEFT", menu.frame, "TOPLEFT", 6, 0)
    textColorPicker:SetCallback("OnValueConfirmed", HTMT_ColorPickerConfirmed)
    menu:AddChild(textColorPicker)
    menu.textColorPicker = textColorPicker

    local textStyleDropDown = AceGUI:Create("Dropdown")
    textStyleDropDown:SetLabel("Text Format")
    textStyleDropDown:SetWidth(125)
    textStyleDropDown:SetMultiselect(false)
    textStyleDropDown:ClearAllPoints()
    textStyleDropDown:SetList(textFormatOptions)
    textStyleDropDown:SetText(textFormatOptions[menuOptions.dropdownValue])
    textStyleDropDown:SetPoint("LEFT", menu.frame, "LEFT", 6, 0)
    textStyleDropDown:SetCallback("OnValueChanged", HTMT_DropdownState)
    menu:AddChild(textStyleDropDown)
    menu.textStyleDropDown = textStyleDropDown

    local textFrameSizeSlider = AceGUI:Create("Slider")
    textFrameSizeSlider:SetLabel(L["Tracker Size"])
    textFrameSizeSlider:SetWidth(150)
    textFrameSizeSlider:SetIsPercent(true)
    if menuOptions.textFrameSizeSlider then textFrameSizeSlider:SetValue(menuOptions.textFrameSizeSlider) end
    textFrameSizeSlider:SetSliderValues(0,1,.01)
    textFrameSizeSlider:ClearAllPoints()
    textFrameSizeSlider:SetPoint("LEFT", menu.frame, "LEFT", 6, 0)
    textFrameSizeSlider:SetCallback("OnValueChanged", HTMT_ResizeFrameSliderUpdater)
    textFrameSizeSlider:SetCallback("OnMouseUp", HTMT_ResizeFrameSliderDone)
    menu:AddChild(textFrameSizeSlider)
    menu.textFrameSizeSlider = textFrameSizeSlider

end