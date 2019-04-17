HTMT = LibStub("AceAddon-3.0"):NewAddon("HighTideManaTracker", "AceConsole-3.0", "AceEvent-3.0")


-- grab localization if available
local L = LibStub("AceLocale-3.0"):GetLocale("htmtMenuTranslations")

-- extra Ace libs
local AceGUI = LibStub("AceGUI-3.0")
local LSM = LibStub("LibSharedMedia-3.0")


-- variables used to handle the tracking of mana spent
local manaTrigger = 40000
local manaCount = 0
local manaCountInverse = 40000
local formatTableOptions = {}
local fontTableOptions = {}
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
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- self:RegisterEvent("UNIT_AURA")
end

-- register slash commands
function HTMT:OnInitialize()
    self:RegisterChatCommand('htmt', 'SlashCommands')
    LSM.RegisterCallback(self, "LibSharedMedia_Registered", "UpdateUsedMedia")
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
    if menuOptions == nil then
        menuOptions = {}
        menuOptions.inverseCheckButton =  false
        menuOptions.lockFrameCheckButton = true
        menuOptions.dropdownValue = 1
        menuOptions.fontVal = 16
        menuOptions.fontName = "Fonts\\MORPHEUS_CYR.TTF"
        menuOptions.manaTrackerSize = {100,40}
        menuOptions.textFrameSizeSlider = 0
        menuOptions.backDropAlphaSlider = 1
    end
    if textFormatOptions == nil or table.getn(textFormatOptions) < 10 then
        textFormatOptions = {"25,350", "25350 : 40k", "25350 / 40k", "25.35k", "25.35k : 40k", "25.35k / 40k","25.4k", "25.4k : 40k", "25.4k / 40k"}
    end
    if shamanSpellCosts == nil then
        shamanSpellCosts = {
            ["Riptide"] = 1600,
            ["Healing Wave"] = 1800,
            ["Chain Heal"] = 5000,
            ["Healing Surge"] = 3800,
            ["Healing Rain"] = 4320,
            ["Healing Steam Totem"] = 2200,
            ["Earth Shield"] = 2000,
            ["Unleash Life"] = 800,
            ["Earthgrab Totem"] = 500,
            ["Earthen Wall Totem"] = 2200,
            ["Ancestral Protection Totem"] = 2200,
            ["Downpour"] = 3000,
            ["Cloudburst Totem"] = 1720,
            ["Flame Shock"] = 3000,
            ["Lava Burst"] = 1200,
            ["Chain Lightning"] = 200,
            ["Bloodlust"] = 4300,
            ["Spirit Link Totem"] = 2200,
            ["Healing Tide Totem"] = 1120,
            ["Spiritwalker's Grace"] = 2820,
            ["Earthbind Totem"] = 500,
            ["Tremor Totem"] = 460,
            ["Capacitor Totem"] = 2000,
            ["Purify Spirit"] = 1300,
            ["Purge"] = 1600,
            ["Heroism"] = 4300,
        }
    end 
end

function HTMT:UpdateUsedMedia(event, mediatype, key)
    fontTableOptions = LSM:List("font")
    -- for i, fonts in ipairs(fontTableOptions) do
    --     local fontName = LSM:Fetch("font", fontTableOptions[key])
    --     table.insert(fontTableOptions, fontName)
    -- end
    -- HTMT:Print("UpdateUsedMedia occured.")
end

function HTMT_TestUpdate()
    fontTableOptions = LSM:List("font")
    local tempTable = {}
    for i, fonts in ipairs(fontTableOptions) do
        local fontName = LSM:Fetch("font", fontTableOptions[i])
        table.insert(tempTable, fontName)
    end
    textFontOptions = tempTable
end

-- reset manaCount on encounter start
function HTMT:Encounter_Start(...)
    local difficultyID = select(4,...)
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end
    if (difficultyID == 14) or (difficultyID == 15) or (difficultyID == 16) or (difficultyID == 17) then
        if not menuOptions.inverseCheckButton then
            manaCount = 0
            manaUsed = 0
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
            self:Print(L["Mana count has been reset!"])
        else
            manaCountInverse = 40000
            manaUsedInverse = 40000
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
            self:Print(L["Mana count has been reset!"])  
        end
    end
end

-- reset manaCount on swapping to high tide
function HTMT:PLAYER_TALENT_UPDATE()
    local learned = select(10,GetTalentInfoBySpecialization(3,7,1))
    if learned and reloadedUI then
        if menuOptions.inverseCheckButton then
            manaCountInverse = manaUsedInverse
            HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
            htmtManaTracker:Show()
        else
            manaCount = manaUsed
            HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
            htmtManaTracker:Show()
        end
    else
        if menuOptions.inverseCheckButton then
            if not learned and not reloadedUI then
                manaCountInverse = 40000
                manaUsedInverse = 40000
                HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
                htmtManaTracker:Hide()
                self:Print(L["Mana count has been reset!"])
            else
                HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
                htmtManaTracker:Show()
            end
        else
            if not learned and not reloadedUI then
                manaCount = 0
                manaUsed = 0
                HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
                htmtManaTracker:Hide()
                self:Print(L["Mana count has been reset!"])
            else
                HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
                htmtManaTracker:Show()
            end
        end
    end
end

function HTMT:ACTIVE_TALENT_GROUP_CHANGED()
    local specID = select(1, GetSpecializationInfo(GetSpecialization()))
    if specID ~= 264 then
       manaCount = 0
        manaUsed = 0
        manaCountInverse = 40000
        manaUsedInverse = 40000
        self:Print(L["Mana count has been reset!"])
        htmtManaTracker:Hide()
    end
end

-- main driver behind tracking mana spent towards high tide
function HTMT:COMBAT_LOG_EVENT_UNFILTERED()
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end
    local learned = select(10,GetTalentInfoBySpecialization(3,7,1))
    local subevent = select(2, CombatLogGetCurrentEventInfo())
    local sourceGUID = select(4, CombatLogGetCurrentEventInfo())
    local spellID = select(12, CombatLogGetCurrentEventInfo())
    local spellName = select(13,CombatLogGetCurrentEventInfo())
    --print(spellName)


    if subevent == "SPELL_CAST_SUCCESS" and (sourceGUID == UnitGUID("player")) and learned then
        local costs = GetSpellPowerCost(spellID)
        -- Special thanks to Niseko for code help for the below code.  You can find his WA located here: https://wago.io/rk7idBBoX
        if costs then
            for _, costInfo in ipairs(costs) do
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
                    elseif HTMT_InnervateBuff() then
                        for k,v in pairs(shamanSpellCosts) do
                            if k == spellName then
                                if menuOptions.inverseCheckButton then
                                    manaCountInverse = manaCountInverse - v
                                    manaUsedInverse = manaCountInverse
                                    HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
                                else
                                    manaCount = manaCount + v
                                    manaUsed = manaCount
                                    HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
                                end
                                break
                            end
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

-- funtion to check for innervate
function HTMT_InnervateBuff()
    --innervate spell id 29166
    for i=1,40 do 
        local B=UnitBuff("player",i); 
        if B == "Innervate" then
             return true
        end
    end
end

-- check if reloadui was true and if was restore manaCount value otherwise was logout/login so reset to 0
function HTMT:PLAYER_ENTERING_WORLD()
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
    reloadedUI = false 
    if menuOptions.inverseCheckButton then
        manaCountInverse = manaUsedInverse
        HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
    else
        manaCount = manaUsed
        HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
    end
end

-- check for if ui_reload happened, if yes then store manaCount and true for reloadUI otherwise 0 and false
function HTMT:PLAYER_LEAVING_WORLD()
    if ui_logout or ui_quit then 
        manaUsedInverse = 40000
        reloadedUI = false
        manaUsed = 0
    else
        reloadedUI = true
        if menuOptions.inverseCheckButton then
            manaUsedInverse = manaCountInverse
        else
            manaUsed = manaCount
        end
    end
end

-- handle the addons slash commands
function HTMT:SlashCommands(input)
    if select(1, GetSpecializationInfo(GetSpecialization())) ~= 264 then return end
    input = string.lower(input)
    local command,value,_ = strsplit(" ", input)

    if command == "" then
        HTMT_ToggleMenu()
    elseif command == "show" then
        htmtManaTracker:Show()
        HTMT:Print(L["ManaTracker is now being shown!"])
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
        HTMT:Print("========High Tide Mana Tracker========")
        HTMT:Print(L["/htmt - to open the options menu!"])
        HTMT:Print(L["/htmt show - to show the tracker if hidden!"])
        HTMT:Print(L["/htmt hide - to hide the tracker if shown!"])
        HTMT:Print(L["/htmt inverse - to swap between counting up or down!"])
        HTMT:Print(L["/htmt lock -  to lock or unlock the tracker window!"])
        HTMT:Print("======================================")
    end

end

-- function to format the text, i do not have credit for writing this, it belongs to Richard Warburton.
function comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

-- function to update the text on the frame anytime an update occurs
function HTMT_UpdateTextNonProgressBar(manaValue, formatType, fontType)
    if fontType == 2 then
        htmtManaTrackerManaCount:SetText("")
    end
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

-- function to toggle the options menu
function HTMT_ToggleMenu()
    if not HTMT.menu then HTMT:CreateOptionsMenu() end
    if HTMT.menu:IsShown() then
        HTMT.menu:Hide()
        HTMT:Print(L["Options menu hidden, for other commands use /htmt help!"])
    else
        HTMT.menu:Show()
        HTMT:Print(L["Options menu loaded, for other commands use /htmt help!"])
    end
end

-- setcallback function for the inverse checkbox
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

-- setcallback function for the progressbar(once implemented)
function HTMT_SaveProgressBarCheckBoxState(widget, event, value)
    menuOptions.progressBarCheckButton = value
end

-- setcallback function for the colorpicker
function HTMT_ColorPickerConfirmed(widget, event, r, g, b, a)
    menuOptions.textColorPicker = {r,g,b,a}
    htmtManaTrackerManaCount:SetTextColor(r,g,b,a)
end

-- setcallback function for the dropdown text format
function HTMT_DropdownState(widget, event, key, checked)
    menuOptions.dropdownValue = key
    if menuOptions.inverseCheckButton then
        HTMT_UpdateTextNonProgressBar(manaCountInverse, menuOptions.dropdownValue, 1)
    else
        HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 1)
    end
end

-- setcallback function for the lock checkbox
function HTMT_LockFrameCheckBoxState(widget, event, value)
    menuOptions.lockFrameCheckButton = value
    if menuOptions.lockFrameCheckButton then
        htmtManaTracker:EnableMouse(false)
    else
        htmtManaTracker:EnableMouse(true)
    end
end

-- function to handle the sliding of the slider, this fires anytime the slider moves
function HTMT_ResizeFrameSliderUpdater(widget, event, value)
    menuOptions.textFrameSizeSlider = value
    local multiplier = value
    local width = 100 + (multiplier * 100)
    local height = 40 + (multiplier * 40)
    local fontVal = 16 + (multiplier * 16)
    htmtManaTracker:SetWidth(width)
    htmtManaTracker:SetHeight(height)
    htmtManaTrackerManaCount:SetSize(width, height)
    if menuOptions.fontName then
        htmtManaTrackerManaCount:SetFont(menuOptions.fontName,fontVal)
        --htmtManaTrackerManaCount:SetTextHeight(fontVal)
        menuOptions.fontVal = fontVal
    else
        htmtManaTrackerManaCount:SetFont("Fonts\\MORPHEUS.ttf",fontVal)
        --htmtManaTrackerManaCount:SetTextHeight(fontVal)
        menuOptions.fontVal = fontVal
    end
end

-- function to update the tracker size from user settings on login
function HTMT_SetTrackerSizeOnLogin()
    if table.getn(menuOptions.manaTrackerSize) == 2 and menuOptions.fontVal and menuOptions.fontName and menuOptions.backDropAlphaSlider then
        htmtManaTracker:SetWidth(menuOptions.manaTrackerSize[1])
        htmtManaTracker:SetHeight(menuOptions.manaTrackerSize[2])
        htmtManaTrackerManaCount:SetSize(menuOptions.manaTrackerSize[1], menuOptions.manaTrackerSize[2])
        htmtManaTrackerManaCount:SetFont(menuOptions.fontName,menuOptions.fontVal)
        htmtManaTracker:SetBackdropColor(0,0,0,menuOptions.backDropAlphaSlider)
        htmtManaTracker:SetBackdropBorderColor(255,255,255,menuOptions.backDropAlphaSlider)
        --htmtManaTrackerManaCount:SetTextHeight(fontVal)
    else
        htmtManaTrackerManaCount:SetFont("Fonts\\MORPHEUS.ttf", 16)
        --htmtManaTrackerManaCount:SetTextHeight(fontVal)
        menuOptions.fontVal = fontVal
    end
end

-- SetCallBack function that handles when the person stops sliding the slider
function HTMT_ResizeFrameSliderDone(widget, event, value)
    menuOptions.textFrameSizeSlider = value
    menuOptions.manaTrackerSize = {htmtManaTracker:GetWidth(), htmtManaTracker:GetHeight()}
end

-- Callback function for the font picker dropdown
function HTMT_FontPickerDropDownState(widget, event, key, checked)
    menuOptions.fontPickerDropDown = key
    menuOptions.fontName = LSM:Fetch("font", fontTableOptions[key])
    if table.getn(menuOptions.manaTrackerSize) == 2 and menuOptions.fontVal and menuOptions.fontName then
        htmtManaTracker:SetWidth(menuOptions.manaTrackerSize[1])
        htmtManaTracker:SetHeight(menuOptions.manaTrackerSize[2])
        htmtManaTrackerManaCount:SetSize(menuOptions.manaTrackerSize[1], menuOptions.manaTrackerSize[2])
        htmtManaTrackerManaCount:SetFont(menuOptions.fontName,menuOptions.fontVal)
        htmtManaTracker:Hide()
        htmtManaTracker:Show()
        HTMT_UpdateTextNonProgressBar(manaCount, menuOptions.dropdownValue, 2)
    end
end

-- callback for the backdrop opacity slider while moving
function HTMT_BackDropSliderOnValueChanged(widget, event, value)
    menuOptions.backDropAlphaSlider = value
    htmtManaTracker:SetBackdropColor(0,0,0,value)
    htmtManaTracker:SetBackdropBorderColor(255,255,255,value)
end

-- callback for the backdrop opacity slider when dont moving
function HTMT_BackDropSliderDone(widget, event, value)
    menuOptions.backDropAlphaSlider = value
end

-- create the options menu
function HTMT:CreateOptionsMenu()
    -- main menu frame
    local menu = AceGUI:Create("Frame")
    menu:SetTitle("High Tide Mana Tracker Options")
    menu:SetStatusText("v"..GetAddOnMetadata("HighTideManaTracker", "Version"))
    menu:SetWidth(250)
    menu:SetHeight(300)
    menu:SetLayout("Flow")
    menu:Hide()
    HTMT.menu = menu

    HTMT_menu = menu.frame
    menu.frame:SetMaxResize(250, 300)
    menu.frame:SetMinResize(250,300)
    menu.frame:SetFrameStrata("HIGH")
    menu.frame:SetFrameLevel(1)

    --inverse checkbox
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
    menu.lockFrameCheckButton = lockFrameCheckButton

    -- colorpicker for changing the color of the text
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

    -- dropdown for picking the text format
    local textStyleDropDown = AceGUI:Create("Dropdown")
    textStyleDropDown:SetLabel(L["Text Format"])
    textStyleDropDown:SetWidth(125)
    textStyleDropDown:SetMultiselect(false)
    textStyleDropDown:ClearAllPoints()
    textStyleDropDown:SetList(textFormatOptions)
    textStyleDropDown:SetText(textFormatOptions[menuOptions.dropdownValue])
    textStyleDropDown:SetPoint("LEFT", menu.frame, "LEFT", 6, 0)
    textStyleDropDown:SetCallback("OnValueChanged", HTMT_DropdownState)
    menu:AddChild(textStyleDropDown)
    menu.textStyleDropDown = textStyleDropDown

    -- slider for changing the size of the tracker and text
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

    -- Slider for the opacity of the backdrop and/or border
    local backDropAlphaSlider = AceGUI:Create("Slider")
    backDropAlphaSlider:SetLabel(L["Backdrop Opacity"])
    backDropAlphaSlider:SetWidth(150)
    backDropAlphaSlider:SetIsPercent(true)
    if menuOptions.backDropAlphaSlider then backDropAlphaSlider:SetValue(menuOptions.backDropAlphaSlider) else backDropAlphaSlider:SetValue(1) end
    backDropAlphaSlider:SetSliderValues(0,1,.01)
    backDropAlphaSlider:ClearAllPoints()
    backDropAlphaSlider:SetPoint("LEFT", menu.frame, "LEFT", 6, 0)
    backDropAlphaSlider:SetCallback("OnValueChanged", HTMT_BackDropSliderOnValueChanged)
    backDropAlphaSlider:SetCallback("OnMouseUp", HTMT_BackDropSliderDone)
    menu:AddChild(backDropAlphaSlider)
    menu.backDropAlphaSlider = backDropAlphaSlider

    -- Dropdown for different font options
    local fontPickerDropDown = AceGUI:Create("Dropdown")
    fontPickerDropDown:SetLabel(L["Choose Font"])
    fontPickerDropDown:SetWidth(250)
    fontPickerDropDown:SetMultiselect(false)
    fontPickerDropDown:ClearAllPoints()
    fontPickerDropDown:SetList(LSM:List("font"))
    if menuOptions.fontName and menuOptions.fontPickerDropDown then 
        fontPickerDropDown:SetText(fontTableOptions[menuOptions.fontPickerDropDown])
    else
        fontPickerDropDown:SetText("Morpheus")
    end
    fontPickerDropDown:SetPoint("LEFT", menu.frame, "LEFT", 6, 0)
    fontPickerDropDown:SetCallback("OnValueChanged", HTMT_FontPickerDropDownState)
    menu:AddChild(fontPickerDropDown)
    menu.fontPickerDropDown = fontPickerDropDown
end
