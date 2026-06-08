-- Sparring + AutoKill + Bed + Rejoin (исправленный, с ожиданием персонажа)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Сохраняем код скрипта для авто-перезапуска
if not _G.SparringScriptCode then
    _G.SparringScriptCode = debug and debug.getinfo(1).source:sub(2) or ""
    if _G.SparringScriptCode == "" then
        _G.SparringScriptCode = "loadstring(game:HttpGet('https://raw.githubusercontent.com/jmiyazaki32-blip/bak/refs/heads/main/bcfarm.lua'))()"
    end
end

-- Настройка авто-перезапуска
if not _G.SparringQueued then
    _G.SparringQueued = true
    local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if queue then
        queue("loadstring([[ " .. _G.SparringScriptCode .. " ]])()")
    end
end

getgenv().G = true
getgenv().Creator = 'https://discord.gg/B3HqPPzFYr - HalloweenGaster'

local killLoopActive = false
local bedPos = Vector3.new(-231, 266, -565)
local REST_THRESHOLD = 80
local lastRejoinTime = 0
local rejoinDelay = 5

local serverEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Server")

-- === БЕЗОПАСНОЕ ОЖИДАНИЕ ПЕРСОНАЖА ===
local function waitForCharacter()
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    return player.Character:WaitForChild("HumanoidRootPart", 10)
end

-- === КИЛЛ ЛУП ===
local function killLoop()
    while killLoopActive and getgenv().G do
        pcall(function()
            sethiddenproperty(player, "SimulationRadius", 112412400000)
            sethiddenproperty(player, "MaxSimulationRadius", 112412400000)
        end)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Humanoid") and obj.Parent and obj.Parent.Name ~= player.Name then
                pcall(function() obj.Health = 0 end)
            end
        end
        task.wait(0.9)
    end
end

-- === ПОЛУЧЕНИЕ УСТАЛОСТИ ===
local function getFatigue()
    local hud = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("HUD")
    if hud then
        local numbers = hud:FindFirstChild("Numbers")
        if numbers then
            local fatigueLabel = numbers:FindFirstChild("Fatigue")
            if fatigueLabel and fatigueLabel:IsA("TextLabel") then
                local txt = fatigueLabel.Text
                local num = txt:match("(%d+%.?%d*)%%")
                if num then return tonumber(num) end
            end
        end
    end
    return 0
end

-- === ТЕЛЕПОРТ С ОЖИДАНИЕМ ПЕРСОНАЖА ===
local function safeTeleport(pos)
    local hrp = waitForCharacter()
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    task.wait(0.3)
end

-- === ПОИСК ПРОМПТА КРОВАТИ ===
local cachedBedPrompt, cachedBedPart = nil, nil
local function findBedPrompt()
    if cachedBedPrompt and cachedBedPrompt.Parent and cachedBedPrompt.Parent.Parent then
        return cachedBedPrompt, cachedBedPart
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Parent:IsA("BasePart") then
            local dist = (obj.Parent.Position - bedPos).Magnitude
            if dist < 10 then
                cachedBedPrompt = obj
                cachedBedPart = obj.Parent
                return cachedBedPrompt, cachedBedPart
            end
        end
    end
    return nil, nil
end

-- === ОТДЫХ В КРОВАТИ ===
local function restInBed()
    safeTeleport(bedPos)
    task.wait(3)
    for attempt = 1, 5 do
        local prompt, part = findBedPrompt()
        if prompt and part then
            local hrp = waitForCharacter()
            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
            task.wait(0.3)
            if fireproximityprompt then
                fireproximityprompt(prompt, 5)
                task.wait(0.5)
                while getFatigue() > 0 do
                    task.wait(2)
                end
                return true
            end
        end
        task.wait(1)
    end
    return false
end

-- === РЕЖОИН ===
local function rejoinServer()
    killLoopActive = false
    task.wait(0.5)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)
    task.wait(2)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    -- Останавливаем скрипт, queue_on_teleport перезапустит его
    error("Режоин выполнен")
end

-- === ЗАПУСК СПАРРИНГА ===
local function startSparring()
    if not serverEvent then return false end
    local npc = Workspace:FindFirstChild("Alive") and Workspace.Alive:FindFirstChild("NPCs") and Workspace.Alive.NPCs:FindFirstChild("Wrestler")
    if not npc then
        for i = 1, 30 do
            task.wait(1)
            npc = Workspace:FindFirstChild("Alive") and Workspace.Alive:FindFirstChild("NPCs") and Workspace.Alive.NPCs:FindFirstChild("Wrestler")
            if npc then break end
        end
        if not npc then
            print("NPC Wrestler не найден, режоин")
            rejoinServer()
            return false
        end
    end
    local args = { "Misc", "SparTrainer", "Start", "Stage8", npc }
    serverEvent:FireServer(unpack(args))
    print("Спарринг запущен")
    return true
end

-- === ГЛАВНЫЙ ЦИКЛ ===
local function main()
    -- Ждём загрузки персонажа
    waitForCharacter()

    killLoopActive = true
    task.spawn(killLoop)
    startSparring()
    lastRejoinTime = tick()

    while true do
        local fatigue = getFatigue()
        if fatigue >= REST_THRESHOLD then
            print("Усталость >=80%, идём в кровать")
            killLoopActive = false
            if restInBed() then
                print("Отдых завершён, усталость 0%")
            else
                print("Не удалось отдохнуть, режоин")
                rejoinServer()
            end
            killLoopActive = true
            task.spawn(killLoop)
            startSparring()
            lastRejoinTime = tick()
        else
            if tick() - lastRejoinTime >= rejoinDelay then
                print("Усталость " .. fatigue .. "% (<80) -> режоин")
                rejoinServer()
            end
        end
        task.wait(2)
    end
end

-- Запуск
local ok, err = pcall(main)
if not ok then
    print("Скрипт остановлен:", err)
end
