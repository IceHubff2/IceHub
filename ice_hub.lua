-- ICE PASS ASSIST HUB - FULL VERSION

-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- SETTINGS
local Settings = {
    Enabled = false,
    Gravity = 28,
    BallOffset = Vector3.new(0, 2, 0),
    Modes = {"BULLET", "MAG", "DIVE"},
    CurrentMode = 1,
    AutoThrow = true,
    TeammateOnly = true,
    ActiveProfile = 1,
    Profiles = {
        {Mode=1, AutoThrow=true},
        {Mode=2, AutoThrow=false},
        {Mode=3, AutoThrow=true}
    }
}

local ModePower = {
    BULLET = 95,
    MAG = 70,
    DIVE = 60
}

-- INTERNAL VARS
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local aimConnection
local lockedTarget = nil
local beam = nil
-- PART 2/5 - GUI CREATION

local function CreateUI()
    local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
    screenGui.Name = "ICE_HUB_UI"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 460, 0, 500)
    frame.Position = UDim2.new(0.02, 0, 0.15, 0)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.1
    frame.Parent = screenGui

    local uiCorner = Instance.new("UICorner", frame)
    uiCorner.CornerRadius = UDim.new(0, 12)

    local uiStroke = Instance.new("UIStroke", frame)
    uiStroke.Color = Color3.fromRGB(0, 200, 255)
    uiStroke.Thickness = 4

    local title = Instance.new("TextLabel")
    title.Name = "TitleLabel"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextScaled = true
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(0, 200, 255)
    title.TextStrokeTransparency = 0.2
    title.Text = "❄ ICE HUB ❄"
    title.Parent = frame

    local buttonHolder = Instance.new("Frame")
    buttonHolder.Size = UDim2.new(1, -20, 1, -60)
    buttonHolder.Position = UDim2.new(0, 10, 0, 50)
    buttonHolder.BackgroundTransparency = 1
    buttonHolder.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = buttonHolder

    local function createButton(name, text, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextStrokeTransparency = 0.2
        btn.Text = text
        btn.Parent = buttonHolder

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 8)

        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    -- BUTTONS (callbacks added later in part 4)
    createButton("ToggleAimbot", "Toggle AimBot", function() end)
    createButton("ChangeMode", "Change Mode", function() end)
    createButton("ToggleAutoThrow", "Toggle AutoThrow", function() end)
    createButton("LockTarget", "Lock Closest Target", function() end)
    createButton("UnlockTarget", "Unlock Target", function() end)
    createButton("Profile1", "Load Profile 1", function() end)
    createButton("Profile2", "Load Profile 2", function() end)
    createButton("Profile3", "Load Profile 3", function() end)
    createButton("SaveProfiles", "Save Profiles", function() end)
    createButton("LoadProfiles", "Load Profiles", function() end)
end
-- PART 3/5 - TARGET FINDER + PROFILE APPLY + ARC PREDICTION

function GetClosestTarget()
    local closest = nil
    local shortest = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if Settings.TeammateOnly and player.Team ~= LocalPlayer.Team then
                continue
            end
            local hrp = player.Character.HumanoidRootPart
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if distance < shortest then
                    shortest = distance
                    closest = player
                end
            end
        end
    end
    return closest
end

function ApplyProfile(index)
    Settings.ActiveProfile = index
    Settings.CurrentMode = Settings.Profiles[index].Mode
    Settings.AutoThrow = Settings.Profiles[index].AutoThrow
    print("[ICE HUB] Applied Profile " .. tostring(index))
end

function GetThrowVelocity(targetPos, targetVel, originPos, gravity, power)
    local distance = (targetPos - originPos).Magnitude
    local time = distance / power
    local predictedPos = targetPos + targetVel * time
    local dir = (predictedPos - originPos)
    
    local arcAdjust = 0
    if Settings.Modes[Settings.CurrentMode] == "MAG" then
        arcAdjust = 4
    elseif Settings.Modes[Settings.CurrentMode] == "DIVE" then
        arcAdjust = 8
    end

    local yOffset = 0.5 * gravity * (time ^ 2) + arcAdjust
    dir = Vector3.new(dir.X, dir.Y + yOffset, dir.Z)
    return dir.Unit * power
end
-- PART 4/5 - AIMBOT LOOP + BEAM VISUAL

local function AssistLockLoop()
    if aimConnection then aimConnection:Disconnect() end

    aimConnection = RunService.RenderStepped:Connect(function()
        if not Settings.Enabled then return end

        local target = lockedTarget or GetClosestTarget()
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            if beam then beam.Enabled = false end
            return
        end

        local hrp = target.Character.HumanoidRootPart
        local targetVel = hrp.AssemblyLinearVelocity
        local ballOrigin = Camera.CFrame.Position + Settings.BallOffset

        local velocity = GetThrowVelocity(hrp.Position, targetVel, ballOrigin, Settings.Gravity, ModePower[Settings.Modes[Settings.CurrentMode]])
        local targetPos = ballOrigin + velocity

        -- BEAM VISUAL
        if not beam then
            beam = Instance.new("Beam", Workspace.CurrentCamera)
            local a0 = Instance.new("Attachment", Workspace.CurrentCamera)
            local a1 = Instance.new("Attachment", Workspace.Terrain)
            beam.Attachment0 = a0
            beam.Attachment1 = a1
            beam.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
            beam.Width0 = 0.15
            beam.Width1 = 0.15
            beam.Transparency = NumberSequence.new(0.1)
        end

        beam.Attachment0.WorldPosition = ballOrigin
        beam.Attachment1.WorldPosition = targetPos
        beam.Enabled = true

        -- MOUSE AIM LOCK
        local screenPos = Camera:WorldToViewportPoint(targetPos)
        local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        local aimVec = Vector2.new(screenPos.X, screenPos.Y)
        local move = (aimVec - center) / 2.5  -- faster lock

        if math.abs(move.X) > 0.5 or math.abs(move.Y) > 0.5 then
            mousemoverel(move.X, move.Y)
        end

        -- AUTO THROW
        if Settings.AutoThrow and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            mousemoverel(0, 0)
        end
    end)
end
-- PART 5/5 - SAFE AUTOSTART + U KEY SHOW/HIDE

repeat task.wait() until Players.LocalPlayer and Players.LocalPlayer.Character and Workspace.CurrentCamera
task.wait(1)

CreateUI()
ApplyProfile(1)
AssistLockLoop()

-- U KEY = SHOW / HIDE HUB
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.U then
        local gui = LocalPlayer.PlayerGui:FindFirstChild("ICE_HUB_UI")
        if gui then
            gui.Enabled = not gui.Enabled
            print("[ICE HUB] UI: " .. (gui.Enabled and "SHOWN" or "HIDDEN"))
        end
    end
end)

print("[ICE HUB] Loaded! Press U to hide/show | Click buttons to use 🚀")
