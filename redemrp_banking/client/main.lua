RedEM = exports["redem_roleplay"]:RedEM()

local bankPrompt
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local promptLabel = CreateVarString(10, "LITERAL_STRING", "Use Bank")

local menuOpen = false
local pendingOpen = false
local lastBalance = 0
local lastName = "Bank Account"
local activeBankMenuItems = {}

local function createHoldPrompt(text, control, group)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, control)
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", text))
    PromptSetHoldMode(prompt, true)
    PromptSetEnabled(prompt, false)
    PromptSetVisible(prompt, false)
    if group then
        PromptSetGroup(prompt, group)
    end
    PromptRegisterEnd(prompt)
    return prompt
end

local function setPromptState(prompt, enabled)
    if not prompt then return end
    PromptSetEnabled(prompt, enabled == true)
    PromptSetVisible(prompt, enabled == true)
end

local function promptNumberInput(title, defaultValue)
    AddTextEntry("FMMC_KEY_TIP1", title or "Amount")
    DisplayOnscreenKeyboard(0, "FMMC_KEY_TIP1", "", tostring(defaultValue or ""), "", "", "", 12)
    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Citizen.Wait(0)
    end
    if GetOnscreenKeyboardResult() then
        local value = tonumber(GetOnscreenKeyboardResult())
        if value and value > 0 then
            return math.floor(value)
        end
    end
    return nil
end

local function openBankMenu()
    local items = {
        balance = {
            itemName = "balance",
            label = ("Balance: $%s"):format(tonumber(lastBalance) or 0),
            description = tostring(lastName or "Bank Account"),
            category = "Banking",
            stockRemaining = 999,
            action = "event",
            actionId = "noop"
        },
        deposit = {
            itemName = "deposit",
            label = "Deposit Funds",
            description = "Move cash into your bank account",
            category = "Banking",
            stockRemaining = 999,
            action = "event",
            actionId = "deposit"
        },
        withdraw = {
            itemName = "withdraw",
            label = "Withdraw Funds",
            description = "Take cash from your bank account",
            category = "Banking",
            stockRemaining = 999,
            action = "event",
            actionId = "withdraw"
        },
        stash = {
            itemName = "stash",
            label = "Open Bank Stash",
            description = "Access your secure bank stash",
            category = "Banking",
            stockRemaining = 999,
            action = "event",
            actionId = "stash"
        },
        refresh = {
            itemName = "refresh",
            label = "Refresh Balance",
            description = "Request latest balance",
            category = "Banking",
            stockRemaining = 999,
            action = "event",
            actionId = "refresh"
        }
    }
    activeBankMenuItems = items

    menuOpen = true
    exports["swiffy_menu_base"]:OpenMenu({
        title = "Banking",
        categories = { "Banking" },
        items = items,
        useCallbacks = true,
        useBaseHandlers = false,
        defaultAction = "event",
        context = {
            hideItemAmount = true,
            hideRemainingText = true,
            ignoreStockRemaining = true
        },
        clientEvents = {
            event = "redemrp_banking:client:MenuAction"
        }
    })
end

RegisterNetEvent("redemrp_banking:client:MenuAction")
AddEventHandler("redemrp_banking:client:MenuAction", function(item)
    local selected = item
    if type(item) == "string" then
        selected = activeBankMenuItems[item]
    end
    if type(selected) ~= "table" then return end
    local actionId = tostring(selected.actionId or "")
    if actionId == "noop" then return end

    if actionId == "deposit" then
        exports["swiffy_menu_base"]:CloseMenu()
        Citizen.SetTimeout(120, function()
            local amount = promptNumberInput("Deposit Amount", 100)
            if amount then
                TriggerServerEvent("redemrp_banking:server:Deposit", amount)
                pendingOpen = true
                Citizen.SetTimeout(250, function()
                    TriggerServerEvent("redemrp_banking:server:RequestBalance")
                end)
            else
                pendingOpen = true
                TriggerServerEvent("redemrp_banking:server:RequestBalance")
            end
        end)
        return
    end

    if actionId == "withdraw" then
        exports["swiffy_menu_base"]:CloseMenu()
        Citizen.SetTimeout(120, function()
            local amount = promptNumberInput("Withdraw Amount", 100)
            if amount then
                TriggerServerEvent("redemrp_banking:server:Withdraw", amount)
                pendingOpen = true
                Citizen.SetTimeout(250, function()
                    TriggerServerEvent("redemrp_banking:server:RequestBalance")
                end)
            else
                pendingOpen = true
                TriggerServerEvent("redemrp_banking:server:RequestBalance")
            end
        end)
        return
    end

    if actionId == "stash" then
        exports["swiffy_menu_base"]:CloseMenu()
        menuOpen = false
        pendingOpen = false
        TriggerServerEvent("redemrp_banking:server:RequestBankStash")
        return
    end

    if actionId == "refresh" then
        pendingOpen = true
        TriggerServerEvent("redemrp_banking:server:RequestBalance")
    end
end)

RegisterNetEvent("redemrp_banking:client:ReceiveBalance")
AddEventHandler("redemrp_banking:client:ReceiveBalance", function(balance, characterName)
    lastBalance = tonumber(balance) or 0
    lastName = characterName or "Bank Account"
    if pendingOpen then
        pendingOpen = false
        openBankMenu()
    elseif menuOpen then
        openBankMenu()
    end
end)

RegisterNetEvent("redemrp_banking:client:CloseBank")
AddEventHandler("redemrp_banking:client:CloseBank", function()
    pendingOpen = false
    menuOpen = false
    if exports["swiffy_menu_base"] and exports["swiffy_menu_base"]:IsOpen() then
        exports["swiffy_menu_base"]:CloseMenu()
    end
end)

AddEventHandler("swiffy_menu_base:closed", function()
    menuOpen = false
end)

Citizen.CreateThread(function()
    bankPrompt = createHoldPrompt("Use Bank", 0xE8342FF2, promptGroup)
    while true do
        local waitTime = 500
        local found = false
        local playerCoords = GetEntityCoords(PlayerPedId())
        local isUiOpen = exports["swiffy_menu_base"] and exports["swiffy_menu_base"]:IsOpen() or false

        setPromptState(bankPrompt, false)

        if not isUiOpen then
            for _, bankCfg in pairs(Config.BankLocations or {}) do
                local pos = bankCfg.Position
                if pos then
                    local dist = #(playerCoords - vector3(pos.x, pos.y, pos.z))
                    if dist < 2.0 then
                        found = true
                        waitTime = 0
                        setPromptState(bankPrompt, true)
                        PromptSetActiveGroupThisFrame(promptGroup, promptLabel)
                        if PromptHasHoldModeCompleted(bankPrompt) then
                            pendingOpen = true
                            TriggerServerEvent("redemrp_banking:server:RequestBalance")
                            Citizen.Wait(400)
                        end
                        break
                    end
                end
            end
        end

        if not found then
            setPromptState(bankPrompt, false)
        end

        Citizen.Wait(waitTime)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if bankPrompt and PromptIsValid(bankPrompt) then
        PromptDelete(bankPrompt)
    end
end)
