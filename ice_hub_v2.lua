-- ICE HUB V2
-- Full key-based aimbot hub (FF2 safe)
-- by IceCube1214

-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- SETTINGS
local Settings = {
    Enabled = false,
    AutoLock = false,
    LockTarget = nil,
    Mode = "BULLET", -- BULLET / MAG / DIVE
    Gravity = 28,
    Modes = {"BULLET", "MAG", "DIVE"},
    BeamEnabled = true,
    DangerCheck = true
}

local ModePower = {
    BULLET = 95,
    MAG = 75,
    DIVE = 60
}

local beamLine = nil
local landingPart = nil
local dangerLabel = nil
local LocalPlayer = Players.LocalPlayer
local lastModeSwitch = 0
-- Get Closest Target
local function GetClosestTarget()
    local closest = nil
    local shortest = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if player.Team == LocalPlayer.Team then continue end
            local hrp = player.Character.HumanoidRootPart
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Throw velocity prediction
local function GetThrowVelocity(targetPos, targetVel, originPos, gravity, power)
    local distance = (targetPos - originPos).Magnitude
    local time = distance / power
    local predictedPos = targetPos + targetVel * time
    local dir = (predictedPos - originPos)

    local arcAdjust = 0
    if Settings.Mode == "MAG" then arcAdjust = 4
    elseif Settings.Mode == "DIVE" then arcAdjust = 8
    end

    local yOffset = 0.5 * gravity * (time ^ 2) + arcAdjust
    dir = Vector3.new(dir.X, dir.Y + yOffset, dir.Z)
    return dir.Unit * power
end
-- Draw Beam + Arc + Landing Line
local function DrawBeam(originPos, targetPos)
    if not beamLine then
        beamLine = Instance.new("Beam", Workspace.CurrentCamera)
        local a0 = Instance.new("Attachment", Workspace.CurrentCamera)
        local a1 = Instance.new("Attachment", Workspace.Terrain)
        beamLine.Attachment0 = a0
        beamLine.Attachment1 = a1
        beamLine.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
        beamLine.Width0 = 0.15
        beamLine.Width1 = 0.15
        beamLine.Transparency = NumberSequence.new(0.1)
    end
    beamLine.Attachment0.WorldPosition = originPos
    beamLine.Attachment1.WorldPosition = targetPos
    beamLine.Enabled = Settings.BeamEnabled
end

-- Landing indicator part
local function DrawLanding(pos)
    if not landingPart then
        landingPart = Instance.new("Part", Workspace)
        landingPart.Anchored = true
        landingPart.Size = Vector3.new(1.5, 0.5, 1.5)
        landingPart.Transparency = 0.4
        landingPart.Color = Color3.fromRGB(0, 150, 255)
        landingPart.Material = Enum.Material.Neon
    end
    landingPart.Position = pos
end

-- Danger Check Label UI
local function CreateDangerLabel()
    if not dangerLabel then
        local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
        dangerLabel = Instance.new("TextLabel", screenGui)
        dangerLabel.Size = UDim2.new(1, 0, 0, 30)
        dangerLabel.Position = UDim2.new(0, 0, 0, 0)
        dangerLabel.BackgroundTransparency = 1
        dangerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        dangerLabel.TextStrokeTransparency = 0.5
        dangerLabel.Font = Enum.Font.SourceSansBold
        dangerLabel.TextSize = 30
        dangerLabel.Text = ""
    end
end
-- Main Aim Loop
local function AimLoop()
    CreateDangerLabel()

    RunService.RenderStepped:Connect(function()
        -- AutoLock logic
        if Settings.AutoLock and (not Settings.LockTarget or not Settings.LockTarget.Character) then
            Settings.LockTarget = GetClosestTarget()
        end

        -- If no lock target, skip
        if not Settings.LockTarget or not Settings.LockTarget.Character or not Settings.Enabled then
            if beamLine then beamLine.Enabled = false end
            if landingPart then landingPart.Transparency = 1 end
            if dangerLabel then dangerLabel.Text = "" end
            return
        end

        local hrp = Settings.LockTarget.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Prediction
        local targetVel = hrp.AssemblyLinearVelocity
        local throwVelocity = GetThrowVelocity(hrp.Position, targetVel, Camera.CFrame.Position, Settings.Gravity, ModePower[Settings.Mode])
        local leadPos = Camera.CFrame.Position + throwVelocity * 0.035

        -- Beam + landing
        DrawBeam(Camera.CFrame.Position, leadPos)
        DrawLanding(hrp.Position + Vector3.new(0, 0, 0))

        -- Defender intercept danger check
        local danger = false
        if Settings.DangerCheck then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local dhrp = player.Character.HumanoidRootPart
                    local dist = (dhrp.Position - hrp.Position).Magnitude
                    if dist < 15 then
                        -- simple jump/dive check
                        danger = true
                        break
                    end
                end
            end
        end

        -- Danger UI
        if danger then
            dangerLabel.Text = "⚠️ DANGER: Defender may intercept!"
            dangerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        else
            dangerLabel.Text = "✅ Pass is safe"
            dangerLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
        end
    end)
end
-- KEYBINDS
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local key = input.KeyCode

    if key == Enum.KeyCode.A then
        Settings.Enabled = not Settings.Enabled
        print("[ICE HUB V2] Aimbot: " .. tostring(Settings.Enabled))

    elseif key == Enum.KeyCode.G then
        Settings.LockTarget = GetClosestTarget()
        if Settings.LockTarget then
            print("[ICE HUB V2] Locked: " .. Settings.LockTarget.Name)
        else
            print("[ICE HUB V2] No target found.")
        end

    elseif key == Enum.KeyCode.V then
        Settings.LockTarget = nil
        print("[ICE HUB V2] Target unlocked.")

    elseif key == Enum.KeyCode.F then
        Settings.AutoLock = not Settings.AutoLock
        print("[ICE HUB V2] AutoLock: " .. tostring(Settings.AutoLock))

    elseif key == Enum.KeyCode.Z then
        Settings.Mode = Settings.Modes[(table.find(Settings.Modes, Settings.Mode) % #Settings.Modes) + 1]
        print("[ICE HUB V2] Mode: " .. Settings.Mode)

    elseif key == Enum.KeyCode.U then
        Settings.BeamEnabled = not Settings.BeamEnabled
        print("[ICE HUB V2] Beam: " .. tostring(Settings.BeamEnabled))
    end
end)

-- START LOOP
AimLoop()

print("[ICE HUB V2] Loaded! Keys: [A]=Aimbot  [G]=Lock  [V]=Unlock  [F]=AutoLock  [Z]=Mode  [U]=Beam")
