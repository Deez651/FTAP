local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GrabEvents = RS:WaitForChild("GrabEvents", 10)
local SetNetworkOwner = GrabEvents and GrabEvents:WaitForChild("SetNetworkOwner", 5)
local EndGrabEarly = GrabEvents and GrabEvents:WaitForChild("EndGrabEarly", 5)
local CreateGrabLine = GrabEvents and GrabEvents:WaitForChild("CreateGrabLine", 5)
local DestroyGrabLine = GrabEvents and GrabEvents:WaitForChild("DestroyGrabLine", 5)

local grabConfirmed = false
local releaseConfirmed = false

if CreateGrabLine then
    CreateGrabLine.OnClientEvent:Connect(function(player, part, cf)
        if player == LocalPlayer then
            grabConfirmed = true
        end
    end)
end

if DestroyGrabLine then
    DestroyGrabLine.OnClientEvent:Connect(function(player)
        if player == LocalPlayer then
            releaseConfirmed = true
        end
    end)
end

local CONF = {
    RANGE = 18,
    DROP_RANGE = 80,
    FLUNG_COOLDOWN = 10,
    AIM_TIMEOUT = 1.5,
    AIM_DOT_MIN = 0.98,
    GRAB_CONFIRM_TIMEOUT = 1.0,
    RELEASE_CONFIRM_TIMEOUT = 0.6,
    AIM_SPEED = 0.10,
    SPIN_TIME = 0.9,
    SPIN_TORQUE = 250,
    FLING_POWER = 500,
    POST_RELEASE_TIME = 0.2,
    BETWEEN_TARGETS = 0.5,
}

local MODE = 0
local running = false
local isBusy = false
local aimActive = false
local lockedTarget = nil
local cooldown = {}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NinjaScript"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local COL_IDLE = Color3.fromRGB(42, 44, 58)
local COL_HOVER = Color3.fromRGB(60, 62, 82)
local COL_1 = Color3.fromRGB(46, 168, 132)
local COL_2 = Color3.fromRGB(204, 128, 66)
local COL_3 = Color3.fromRGB(206, 66, 80)

local function glassify(obj, radius, bgTrans)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Transparency = 0.75
    s.Thickness = 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    if obj:IsA("GuiObject") then
        obj.BackgroundTransparency = bgTrans or 0.3
    end
end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 280, 0, 330)
Main.Position = UDim2.new(0, 20, 0.28, 0)
Main.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
glassify(Main, 22, 0.35)

local Grad = Instance.new("UIGradient")
Grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 90, 130)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 34, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 17, 26)),
})
Grad.Rotation = 90
Grad.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0, 36)
Title.Position = UDim2.new(0, 14, 0, 12)
Title.BackgroundTransparency = 1
Title.Text = "Ninja Script"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

local TitleGrad = Instance.new("UIGradient")
TitleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 200, 255)),
})
TitleGrad.Parent = Title

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -28, 0, 1)
Divider.Position = UDim2.new(0, 14, 0, 52)
Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Divider.BackgroundTransparency = 0.85
Divider.BorderSizePixel = 0
Divider.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -28, 0, 40)
Status.Position = UDim2.new(0, 14, 0, 58)
Status.BackgroundTransparency = 1
Status.Text = "Загрузка..."
Status.TextColor3 = Color3.fromRGB(180, 190, 210)
Status.Font = Enum.Font.GothamMedium
Status.TextSize = 13
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextWrapped = true
Status.Parent = Main

local function makeButton(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -28, 0, 36)
    b.Position = UDim2.new(0, 14, 0, y)
    b.BackgroundColor3 = COL_IDLE
    b.TextColor3 = Color3.fromRGB(240, 240, 255)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.Text = text
    b.AutoButtonColor = false
    b.Parent = Main
    glassify(b, 14, 0.3)
    b.MouseEnter:Connect(function()
        if b.BackgroundColor3 == COL_IDLE then b.BackgroundColor3 = COL_HOVER end
    end)
    b.MouseLeave:Connect(function()
        if b.BackgroundColor3 == COL_HOVER then b.BackgroundColor3 = COL_IDLE end
    end)
    return b
end

local btn1 = makeButton("Версия 1 — Спин", 106)
local btn2 = makeButton("Версия 2 — Спин + бросок", 146)
local btn3 = makeButton("Версия 3 — МАКС", 186)

local function setStatus(t, c)
    Status.Text = t
    Status.TextColor3 = c or Color3.fromRGB(180, 190, 210)
end

local function getHRP(p)
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function getHum(p)
    return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function getDist(p)
    local a = getHRP(LocalPlayer)
    local b = getHRP(p)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

local function isValid(p)
    if not p or not p.Parent then return false end
    local h = getHum(p)
    if not h or h.Health <= 0 then return false end
    if cooldown[p] and tick() - cooldown[p] < CONF.FLUNG_COOLDOWN then return false end
    return true
end

local function findTarget()
    local best, bd = nil, CONF.RANGE
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isValid(p) then
            local d = getDist(p)
            if d < bd then bd = d; best = p end
        end
    end
    return best
end

RunService:BindToRenderStep("NinjaAim", Enum.RenderPriority.Camera.Value + 1, function()
    if not aimActive or not lockedTarget then return end
    local r = getHRP(lockedTarget)
    if not r then return end
    local ap = r.Position + Vector3.new(0, 1.5, 0)
    local cp = Camera.CFrame.Position
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(cp, ap), CONF.AIM_SPEED)
end)

local function aimWaitFor(p, timeout)
    local t0 = tick()
    while tick() - t0 < timeout do
        if not isValid(p) then return false end
        local r = getHRP(p)
        if r then
            local dir = (r.Position + Vector3.new(0, 1.5, 0)) - Camera.CFrame.Position
            if dir.Magnitude > 0.01 and Camera.CFrame.LookVector:Dot(dir.Unit) >= CONF.AIM_DOT_MIN then
                return true
            end
        end
        task.wait(0.02)
    end
    return true
end

local function waitForFlag(getter, timeout)
    local t0 = tick()
    while tick() - t0 < timeout do
        if getter() then return true end
        task.wait(0.02)
    end
    return false
end

local function flingTarget(p)
    isBusy = true
    lockedTarget = p
    aimActive = true

    setStatus("Наведение: " .. p.Name, Color3.fromRGB(255, 220, 100))
    aimWaitFor(p, CONF.AIM_TIMEOUT)

    if not isValid(p) then
        aimActive = false
        isBusy = false
        return
    end

    local targetHRP = getHRP(p)
    if not targetHRP then
        aimActive = false
        isBusy = false
        return
    end

    setStatus("Запрос захвата: " .. p.Name, Color3.fromRGB(100, 200, 255))
    grabConfirmed = false
    releaseConfirmed = false

    if SetNetworkOwner then
        pcall(function() SetNetworkOwner:FireServer(targetHRP) end)
    end

    local got = waitForFlag(function() return grabConfirmed end, CONF.GRAB_CONFIRM_TIMEOUT)

    if not got or not targetHRP.Parent then
        setStatus("Захват не удался", Color3.fromRGB(255, 100, 100))
        cooldown[p] = tick()
        aimActive = false
        isBusy = false
        return
    end

    aimActive = false
    setStatus("Раскрутка: " .. p.Name, Color3.fromRGB(255, 130, 80))

    local spinStart = tick()
    local spinConn
    local applyVel = MODE >= 2
    local power = CONF.FLING_POWER

    spinConn = RunService.Heartbeat:Connect(function()
        if not targetHRP or not targetHRP.Parent then return end
        local elapsed = tick() - spinStart
        if elapsed > CONF.SPIN_TIME + CONF.POST_RELEASE_TIME then return end

        pcall(function()
            targetHRP.AssemblyAngularVelocity = Vector3.new(0, CONF.SPIN_TORQUE, 0)

            if applyVel then
                local look = Camera.CFrame.LookVector
                local intensity = 1
                if elapsed > CONF.SPIN_TIME then
                    intensity = 1.6
                end
                targetHRP.AssemblyLinearVelocity = Vector3.new(
                    look.X * power * intensity + math.random(-40, 40),
                    power * 0.55 * intensity,
                    look.Z * power * intensity + math.random(-40, 40)
                )
            elseif MODE == 1 then
                targetHRP.AssemblyAngularVelocity = Vector3.new(
                    math.random(-CONF.SPIN_TORQUE, CONF.SPIN_TORQUE),
                    CONF.SPIN_TORQUE,
                    math.random(-CONF.SPIN_TORQUE, CONF.SPIN_TORQUE)
                )
            end
        end)
    end)

    task.wait(CONF.SPIN_TIME)

    setStatus("Отпуск: " .. p.Name, Color3.fromRGB(120, 255, 160))

    if EndGrabEarly then
        pcall(function() EndGrabEarly:FireServer() end)
    end

    waitForFlag(function() return releaseConfirmed end, CONF.RELEASE_CONFIRM_TIMEOUT)

    task.wait(CONF.POST_RELEASE_TIME)

    if spinConn then spinConn:Disconnect() end

    if targetHRP and targetHRP.Parent then
        pcall(function()
            targetHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
    end

    cooldown[p] = tick()
    isBusy = false
    aimActive = false
    lockedTarget = nil
    setStatus("Готово: " .. p.Name, Color3.fromRGB(120, 255, 160))
end

local function mainLoop()
    if running then return end
    running = true
    task.spawn(function()
        while MODE ~= 0 do
            if isBusy then
                task.wait(0.05)
            else
                local t
                if lockedTarget and isValid(lockedTarget) and getDist(lockedTarget) <= CONF.DROP_RANGE then
                    t = lockedTarget
                else
                    lockedTarget = nil
                    t = findTarget()
                    lockedTarget = t
                end

                if t then
                    flingTarget(t)
                    task.wait(CONF.BETWEEN_TARGETS)
                else
                    setStatus("Нет целей рядом", Color3.fromRGB(150, 150, 170))
                    lockedTarget = nil
                    task.wait(0.3)
                end
            end
        end
        lockedTarget = nil
        aimActive = false
        isBusy = false
        running = false
    end)
end

local function setMode(m)
    if MODE == m then
        MODE = 0
        lockedTarget = nil
        isBusy = false
        aimActive = false
        setStatus("Выключено", Color3.fromRGB(255, 100, 100))
        btn1.BackgroundColor3 = COL_IDLE
        btn2.BackgroundColor3 = COL_IDLE
        btn3.BackgroundColor3 = COL_IDLE
    else
        MODE = m
        lockedTarget = nil
        setStatus("Режим " .. m .. " активен", Color3.fromRGB(120, 255, 160))
        btn1.BackgroundColor3 = (m == 1) and COL_1 or COL_IDLE
        btn2.BackgroundColor3 = (m == 2) and COL_2 or COL_IDLE
        btn3.BackgroundColor3 = (m == 3) and COL_3 or COL_IDLE

        if m == 1 then
            CONF.AIM_SPEED = 0.07
            CONF.SPIN_TIME = 0.8
            CONF.SPIN_TORQUE = 200
            CONF.FLING_POWER = 0
        elseif m == 2 then
            CONF.AIM_SPEED = 0.11
            CONF.SPIN_TIME = 1.0
            CONF.SPIN_TORQUE = 260
            CONF.FLING_POWER = 500
        elseif m == 3 then
            CONF.AIM_SPEED = 0.16
            CONF.SPIN_TIME = 1.2
            CONF.SPIN_TORQUE = 320
            CONF.FLING_POWER = 800
        end

        mainLoop()
    end
end

btn1.MouseButton1Click:Connect(function() setMode(1) end)
btn2.MouseButton1Click:Connect(function() setMode(2) end)
btn3.MouseButton1Click:Connect(function() setMode(3) end)

if SetNetworkOwner and EndGrabEarly and CreateGrabLine and DestroyGrabLine then
    setStatus("Готов. Радиус 18", Color3.fromRGB(120, 255, 160))
else
    setStatus("Ошибка: GrabEvents не полные", Color3.fromRGB(255, 100, 100))
end
