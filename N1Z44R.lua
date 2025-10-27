local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Reconnect character on respawn
player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
end)

local _G = {
    autoStealEnabled = false,
    autoSellEnabled = false,
    farmRadius = 150,
    stealDelay = 0.3,
    priorityRare = true,
    walkSpeed = 16,
    flyEnabled = false,
    flySpeed = 100,
    noClipEnabled = false,
    itemESP = false,
    guardESP = false,
    playerESP = false,
    fullBright = false,
    noFog = false
}

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local BrainrotItems = {
    "Brainrot", "Brain", "Cash", "Money", "Coin", "Diamond", 
    "Gold", "Ruby", "Sapphire", "Emerald", "Crystal"
}

local BrainrotGuards = {
    "Guard", "Police", "Security", "Cop", "Officer"
}

local FarmModule = {}

function FarmModule:IsBrainrotItem(obj)
    if not obj or not obj.Name then return false end
    local objName = obj.Name:lower()
    for _, itemName in pairs(BrainrotItems) do
        if objName:find(itemName:lower()) then
            return true
        end
    end
    return false
end

function FarmModule:IsGuard(obj)
    if not obj or not obj.Name then return false end
    local objName = obj.Name:lower()
    local humanoid = obj:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for _, guardName in pairs(BrainrotGuards) do
            if objName:find(guardName:lower()) then
                return true
            end
        end
    end
    return false
end

function FarmModule:GetNearbyItems()
    local items = {}
    
    if not hrp or not hrp.Parent then return items end
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("Part") or obj:IsA("Model")) and obj ~= character then
            local success, result = pcall(function()
                local objPosition = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
                return (hrp.Position - objPosition).Magnitude
            end)
            
            if success and result and result <= _G.farmRadius then
                if FarmModule:IsBrainrotItem(obj) then
                    local isRare = obj.Name:lower():find("rare") or obj.Name:lower():find("legendary")
                    table.insert(items, {
                        object = obj,
                        distance = result,
                        isRare = isRare or false
                    })
                end
            end
        end
    end
    
    table.sort(items, function(a, b)
        if _G.priorityRare then
            if a.isRare and not b.isRare then return true end
            if not a.isRare and b.isRare then return false end
        end
        return a.distance < b.distance
    end)
    
    return items
end

function FarmModule:CollectItem(itemObj)
    if not itemObj or not itemObj.Parent then return end
    
    pcall(function()
        -- Try ClickDetector
        if itemObj:FindFirstChild("ClickDetector") then
            fireclickdetector(itemObj.ClickDetector)
        end
        
        -- Try ProximityPrompt
        if itemObj:FindFirstChild("ProximityPrompt") then
            fireproximityprompt(itemObj.ProximityPrompt)
        end
        
        -- Try common remotes
        local remotes = {"CollectItem", "PickupItem", "GrabItem", "Collect", "Pickup"}
        for _, remoteName in pairs(remotes) do
            local remote = ReplicatedStorage:FindFirstChild(remoteName, true)
            if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(itemObj)
                else
                    remote:InvokeServer(itemObj)
                end
            end
        end
    end)
end

function FarmModule:SmartSteal()
    if not hrp or not hrp.Parent then return end
    
    local items = FarmModule:GetNearbyItems()
    
    if #items > 0 then
        local target = items[1]
        
        pcall(function()
            if target.object and target.object.Parent then
                local targetPos = target.object:IsA("Model") and target.object:GetPivot().Position or target.object.Position
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
                local targetCFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
                tween:Play()
                
                wait(0.3)
                FarmModule:CollectItem(target.object)
            end
        end)
    end
end

function FarmModule:AutoSell()
    if not hrp or not hrp.Parent then return end
    
    local sellZones = {}
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name then
            local name = obj.Name:lower()
            if name:find("sell") or name:find("bank") or name:find("deposit") or name:find("cashier") then
                table.insert(sellZones, obj)
            end
        end
    end
    
    if #sellZones > 0 then
        local closestZone = sellZones[1]
        local closestDist = math.huge
        
        for _, zone in pairs(sellZones) do
            local success, dist = pcall(function()
                local zonePos = zone:IsA("Model") and zone:GetPivot().Position or zone.Position
                return (hrp.Position - zonePos).Magnitude
            end)
            if success and dist < closestDist then
                closestDist = dist
                closestZone = zone
            end
        end
        
        pcall(function()
            local zonePos = closestZone:IsA("Model") and closestZone:GetPivot() or closestZone.CFrame
            local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear)
            local tween = TweenService:Create(hrp, tweenInfo, {CFrame = zonePos})
            tween:Play()
            tween.Completed:Wait()
            
            wait(0.5)
            
            -- Try common sell remotes
            local sellRemotes = {"SellItems", "DepositCash", "Sell", "SellAll", "Deposit"}
            for _, remoteName in pairs(sellRemotes) do
                local remote = ReplicatedStorage:FindFirstChild(remoteName, true)
                if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer()
                    else
                        remote:InvokeServer()
                    end
                end
            end
        end)
    end
end

local ESPModule = {}
ESPModule.Highlights = {}

function ESPModule:CreateHighlight(obj, color, name)
    if not obj or not obj.Parent then return end
    if obj:FindFirstChild("N1Z44R_Highlight") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "N1Z44R_Highlight"
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Parent = obj
    
    table.insert(ESPModule.Highlights, highlight)
    
    return highlight
end

function ESPModule:UpdateESP()
    -- Clear old highlights
    for _, highlight in pairs(ESPModule.Highlights) do
        if highlight and highlight.Parent then
            pcall(function() highlight:Destroy() end)
        end
    end
    ESPModule.Highlights = {}
    
    -- Item ESP
    if _G.itemESP then
        local items = FarmModule:GetNearbyItems()
        for _, item in pairs(items) do
            if item.object and item.object.Parent then
                local color = item.isRare and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(0, 255, 0)
                ESPModule:CreateHighlight(item.object, color, "Item")
            end
        end
    end
    
    -- Guard ESP
    if _G.guardESP then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and FarmModule:IsGuard(obj) then
                ESPModule:CreateHighlight(obj, Color3.fromRGB(255, 0, 0), "Guard")
            end
        end
    end
    
    -- Player ESP
    if _G.playerESP then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                ESPModule:CreateHighlight(plr.Character, Color3.fromRGB(0, 100, 255), plr.Name)
            end
        end
    end
end

local VisualModule = {}
local originalLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd
}

function VisualModule:ToggleFullBright()
    if _G.fullBright then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.Brightness = originalLighting.Brightness
    end
end

function VisualModule:ToggleNoFog()
    if _G.noFog then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = originalLighting.FogEnd
    end
end

local FlyModule = {}
FlyModule.Enabled = false
FlyModule.BodyVelocity = nil

function FlyModule:Toggle()
    FlyModule.Enabled = _G.flyEnabled
    
    if FlyModule.BodyVelocity then
        FlyModule.BodyVelocity:Destroy()
        FlyModule.BodyVelocity = nil
    end
    
    if FlyModule.Enabled and hrp and hrp.Parent then
        FlyModule.BodyVelocity = Instance.new("BodyVelocity")
        FlyModule.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        FlyModule.BodyVelocity.MaxForce = Vector3.new(400000, 400000, 400000)
        FlyModule.BodyVelocity.Parent = hrp
        
        spawn(function()
            while FlyModule.Enabled and _G.flyEnabled and hrp and hrp.Parent do
                local camera = workspace.CurrentCamera
                local moveDirection = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDirection = moveDirection + (camera.CFrame.LookVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDirection = moveDirection - (camera.CFrame.LookVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection = moveDirection - (camera.CFrame.RightVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection = moveDirection + (camera.CFrame.RightVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDirection = moveDirection + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection = moveDirection - Vector3.new(0, 1, 0)
                end
                
                if FlyModule.BodyVelocity and FlyModule.BodyVelocity.Parent then
                    FlyModule.BodyVelocity.Velocity = moveDirection.Unit * _G.flySpeed
                end
                
                RunService.Heartbeat:Wait()
            end
            
            if FlyModule.BodyVelocity then
                FlyModule.BodyVelocity:Destroy()
                FlyModule.BodyVelocity = nil
            end
        end)
    end
end

-- Load Orion Library
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "N1Z44R v2.1 | Brainrot (Fixed)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "N1Z44RConfig"
})

-- Farm Tab
local FarmTab = Window:MakeTab({
    Name = "Auto Farm",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

FarmTab:AddToggle({
    Name = "Auto Steal Items",
    Default = false,
    Callback = function(value)
        _G.autoStealEnabled = value
        if value then
            spawn(function()
                while _G.autoStealEnabled do
                    FarmModule:SmartSteal()
                    wait(_G.stealDelay)
                end
            end)
        end
    end
})

FarmTab:AddToggle({
    Name = "Auto Sell",
    Default = false,
    Callback = function(value)
        _G.autoSellEnabled = value
        if value then
            spawn(function()
                while _G.autoSellEnabled do
                    FarmModule:AutoSell()
                    wait(15)
                end
            end)
        end
    end
})

FarmTab:AddToggle({
    Name = "Priority Rare Items",
    Default = true,
    Callback = function(value)
        _G.priorityRare = value
    end
})

FarmTab:AddSlider({
    Name = "Farm Radius",
    Min = 50,
    Max = 300,
    Default = 150,
    Color = Color3.fromRGB(0, 255, 0),
    Increment = 10,
    ValueName = "studs",
    Callback = function(value)
        _G.farmRadius = value
    end
})

FarmTab:AddSlider({
    Name = "Steal Delay",
    Min = 0.1,
    Max = 2,
    Default = 0.3,
    Color = Color3.fromRGB(255, 255, 0),
    Increment = 0.1,
    ValueName = "seconds",
    Callback = function(value)
        _G.stealDelay = value
    end
})

-- Movement Tab
local MoveTab = Window:MakeTab({
    Name = "Movement",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MoveTab:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 150,
    Default = 16,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "speed",
    Callback = function(value)
        _G.walkSpeed = value
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = value
        end
    end
})

MoveTab:AddToggle({
    Name = "Fly",
    Default = false,
    Callback = function(value)
        _G.flyEnabled = value
        FlyModule:Toggle()
    end
})

MoveTab:AddSlider({
    Name = "Fly Speed",
    Min = 50,
    Max = 300,
    Default = 100,
    Color = Color3.fromRGB(0, 200, 255),
    Increment = 10,
    ValueName = "speed",
    Callback = function(value)
        _G.flySpeed = value
    end
})

MoveTab:AddToggle({
    Name = "NoClip",
    Default = false,
    Callback = function(value)
        _G.noClipEnabled = value
        if value then
            spawn(function()
                while _G.noClipEnabled do
                    if character and character.Parent then
                        for _, part in pairs(character:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                    wait(0.1)
                end
                -- Restore collision
                if character and character.Parent then
                    for _, part in pairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end)
        end
    end
})

-- ESP Tab
local ESPTab = Window:MakeTab({
    Name = "ESP",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

ESPTab:AddToggle({
    Name = "Item ESP",
    Default = false,
    Callback = function(value)
        _G.itemESP = value
        ESPModule:UpdateESP()
    end
})

ESPTab:AddToggle({
    Name = "Guard ESP",
    Default = false,
    Callback = function(value)
        _G.guardESP = value
        ESPModule:UpdateESP()
    end
})

ESPTab:AddToggle({
    Name = "Player ESP",
    Default = false,
    Callback = function(value)
        _G.playerESP = value
        ESPModule:UpdateESP()
    end
})

-- Visual Tab
local VisualTab = Window:MakeTab({
    Name = "Visual",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

VisualTab:AddToggle({
    Name = "Full Bright",
    Default = false,
    Callback = function(value)
        _G.fullBright = value
        VisualModule:ToggleFullBright()
    end
})

VisualTab:AddToggle({
    Name = "No Fog",
    Default = false,
    Callback = function(value)
        _G.noFog = value
        VisualModule:ToggleNoFog()
    end
})

-- Initialize
OrionLib:Init()

-- ESP Update Loop
spawn(function()
    while true do
        if _G.itemESP or _G.guardESP or _G.playerESP then
            ESPModule:UpdateESP()
        end
        wait(2)
    end
end)

-- Keep walkspeed updated
spawn(function()
    while true do
        if humanoid and humanoid.Parent and _G.walkSpeed ~= 16 then
            humanoid.WalkSpeed = _G.walkSpeed
        end
        wait(0.5)
    end
end)

-- Notification
OrionLib:MakeNotification({
    Name = "N1Z44R v2.1 Fixed",
    Content = "Script cargado correctamente!",
    Image = "rbxassetid://4483345998",
    Time = 5
})
