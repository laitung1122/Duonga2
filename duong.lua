local branch = getgenv().DuongApi_dev_mode and "dev" or "main"
local HttpService = game:GetService("HttpService")
local baseURL = "https://raw.githubusercontent.com/laitung1122/Duonga2/" .. branch

export type gameMapping = {
    exclusions: table?,
    main: string
}

if not getgenv().ExecutorSupport then
    local success, err = pcall(function()
        loadstring(game:HttpGet(baseURL .. "/linh.lua"))()
    end)
    if not success then warn("Failed to load linh.lua: " .. err) end
end

if not getgenv().BloxstrapRPC then
    local BloxstrapRPC = {}

    export type RichPresence = {
        details:     string?,
        state:       string?,
        timeStart:   number?,
        timeEnd:     number?,
        smallImage:  RichPresenceImage?,
        largeImage:  RichPresenceImage?
    }

    export type RichPresenceImage = {
        assetId:    number?,
        hoverText:  string?,
        clear:      boolean?,
        reset:      boolean?
    }

    function BloxstrapRPC.SendMessage(command: string, data: any)
        local json = HttpService:JSONEncode({command = command, data = data})
        print("[BloxstrapRPC] " .. json)
    end

    function BloxstrapRPC.SetRichPresence(data: RichPresence)
        if data.timeStart ~= nil then
            data.timeStart = math.round(data.timeStart)
        end
        if data.timeEnd ~= nil then
            data.timeEnd = math.round(data.timeEnd)
        end
        BloxstrapRPC.SendMessage("SetRichPresence", data)
    end

    getgenv().BloxstrapRPC = BloxstrapRPC
end

local success, result = pcall(function()
    return game:HttpGet(baseURL .. "/map/" .. game.GameId .. ".json")
end)
if success then
    local mapping = HttpService:JSONDecode(result)
    local scriptPath = mapping.main

    if mapping.exclusions and mapping.exclusions[tostring(game.PlaceId)] then
        scriptPath = mapping.exclusions[tostring(game.PlaceId)]
    end

    local successScript, errScript = pcall(function()
        loadstring(game:HttpGet(baseURL .. scriptPath))()
    end)
    if not successScript then warn("Failed to load script: " .. errScript) end
else
    warn("Failed to get mapping: " .. result)
end

if getgenv().mspaint_disable_addons then return end

task.spawn(function()
    local fileSystemAPIs = {"isfile", "delfile", "listfiles", "writefile", "makefolder", "isfolder"}
    local supportsFileSystem = true
    for _, api in ipairs(fileSystemAPIs) do
        if not ExecutorSupport[api] then
            supportsFileSystem = false
            break
        end
    end

    if not supportsFileSystem then
        warn("[DuongApi] Your executor doesn't support the FileSystem API. Addons will not work.")
        return
    end

    if not isfolder("DuongApi/addons") then
        makefolder("DuongApi/addons")
        return
    end
    
    repeat task.wait() until getgenv().mspaint_loaded == true

    local function getGameAddonPath(path)
        return string.match(path, "/places/(.-)%.lua")
    end

    local function AddAddonElement(LinoriaElement, AddonName, Element)
        if not LinoriaElement then return end
        if typeof(Element) ~= "table" or typeof(Element.Type) ~= "string" then return end
        if typeof(AddonName) ~= "string" then return end
        if Element.Type:sub(1, 3) == "Add" then Element.Type = Element.Type:sub(4) end

        if Element.Type == "Divider" then
            return LinoriaElement:AddDivider()
        elseif Element.Type == "DependencyBox" then
            return LinoriaElement:AddDependencyBox()
        elseif typeof(Element.Arguments) == "table" then
            if Element.Type == "Label" then
                return LinoriaElement:AddLabel(table.unpack(Element.Arguments))
            elseif Element.Type == "Toggle" then
                return LinoriaElement:AddToggle(AddonName .. "_" .. Element.Name, Element.Arguments)
            elseif Element.Type == "Button" then
                return LinoriaElement:AddButton(Element.Arguments)
            elseif Element.Type == "Slider" then
                return LinoriaElement:AddSlider(AddonName .. "_" .. Element.Name, Element.Arguments)
            elseif Element.Type == "Input" then
                return LinoriaElement:AddInput(AddonName .. "_" .. Element.Name, Element.Arguments)
            elseif Element.Type == "Dropdown" then
                return LinoriaElement:AddInput(AddonName .. "_" .. Element.Name, Element.Arguments)
            elseif Element.Type == "ColorPicker" then
                return LinoriaElement:AddColorPicker(AddonName .. "_" .. Element.Name, Element.Arguments)        
            elseif Element.Type == "KeyPicker" then
                return LinoriaElement:AddKeyPicker(AddonName .. "_" .. Element.Name, Element.Arguments)
            end
        end
    end

    local gameAddonPath = getGameAddonPath(scriptPath)
    local AddonTab, LastGroupbox = nil, "Right"

    local function createAddonTab(hasAddons)
        if AddonTab ~= nil then return end
        local addonsText = hasAddons and 
            "This tab is for UN-OFFICIAL addons made for DuongApi. We are not responsible for what addons you will use. You are putting yourself AT RISK since you are executing third-party scripts." or
            "Your addons FOLDER is empty!"
        AddonTab = getgenv().Library.Window:AddTab("Addons [BETA]")
        AddonTab:UpdateWarningBox({
            Visible = true,
            Title = "WARNING",
            Text = addonsText
        })
    end

    local containAddonsLoaded = false
    for _, file in pairs(listfiles("DuongApi/addons")) do
        if file:sub(#file - 3) ~= ".lua" and file:sub(#file - 4) ~= ".luau" and file:sub(#file - 7) ~= ".lua.txt" then continue end
        local success, errorMessage = pcall(function()
            local fileContent = readfile(file)
            local addon = loadstring(fileContent)()

            if typeof(addon.Name) ~= "string" or typeof(addon.Elements) ~= "table" then return end
            if typeof(addon.Game) == "string" then
                if addon.Game ~= gameAddonPath and addon.Game ~= "*" then return end
            elseif typeof(addon.Game) == "table" then
                if not table.find(addon.Game, gameAddonPath) then return end
            else return end

            addon.Name = addon.Name:gsub("%s+", "")
            addon.Title = typeof(addon.Title) == "string" and addon.Title or addon.Name

            if not AddonTab then createAddonTab(true) end

            local AddonGroupbox = LastGroupbox == "Right" and AddonTab:AddLeftGroupbox(addon.Title) or AddonTab:AddRightGroupbox(addon.Title)
            LastGroupbox = LastGroupbox == "Right" and "Left" or "Right"
            if typeof(addon.Description) == "string" then
                AddonGroupbox:AddLabel(addon.Description, true)
            end

            local function loadElements(linoriaMainElement, elements)
                for _, element in pairs(elements) do                      
                    local linoriaElement = AddAddonElement(linoriaMainElement, addon.Name, element)
                    if linoriaElement and typeof(element.Elements) == "table" then
                        loadElements(linoriaElement, element.Elements)
                    end  
                end
            end

            loadElements(AddonGroupbox, addon.Elements)
        end)

        if success then
            containAddonsLoaded = true
        else
            warn("[DuongApi] Failed to load addon '" .. file .. "': " .. errorMessage)
        end
    end
    createAddonTab(containAddonsLoaded)
end)
