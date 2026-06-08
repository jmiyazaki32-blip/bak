-- Sparring + AutoKill + Bed + Rejoin (исправленный: после реджоина запускает спарринг, реджоин только если долго нет прогресса)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Авто-перезапуск после реджоина
if not _G.SparringScriptCode then
    _G.SparringScriptCode = debug and debug.getinfo(1).source:sub(2) or ""
    if _G.SparringScriptCode == "" then
        _G.SparringScriptCode = "loadstring(game:HttpGet('https://raw.githubusercontent.com/jmiyazaki32-blip/bak/refs/heads/main/bcfarm.lua'))()"
    end
end
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
local lastFatigueTime = 0      -- время последнего изменения усталости
local rejoinCooldown = 30      -- секунд без роста усталости перед реджоином
local rejoinTimer = nil

local serverEvent = nil

-- Функция получения актуального serverEvent (ждёт появления)
local function getServerEvent()
    while not serverEvent do
        serverEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Server")
        if not serverEvent then task.wait(1) end
    end
    return serverEvent
end

-- Безопасное получение HumanoidRootPart (ждёт вечно)
local function getHRP()
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    return player.Character:WaitForChild("HumanoidRootPart")
end

-- Бесконечный килл всех NPC (кроме игрока)
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

-- Получение усталости из HUD
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

-- Телепорт
local function safeTeleport(pos)
    local hrp = getHRP()
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    task.wait(0.3)
end

-- Поиск промпта кровати
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

-- Отдых в кровати до 0% усталости
local function restInBed()
    safeTeleport(bedPos)
    task.wait(3)
    for attempt = 1, 5 do
        local prompt, part = findBedPrompt()
        if prompt and part then
            local hrp = getHRP()
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

-- Режоин (перезаход)
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
    error("Режоин выполнен")
end

-- Запуск спарринга с повторными попытками
local function startSparring()
    getServerEvent()  -- ждём serverEvent
    local npc = nil
    for i = 1, 120 do
        npc = Workspace:FindFirstChild("Alive") and Workspace.Alive:FindFirstChild("NPCs") and Workspace.Alive.NPCs:FindFirstChild("Wrestler")
        if npc then break end
        task.wait(1)
    end
    if not npc then
        print("NPC Wrestler не найден, режоин")
        rejoinServer()
        return false
    end
    local args = { "Misc", "SparTrainer", "Start", "Stage8", npc }
    serverEvent:FireServer(unpack(args))
    print("Спарринг запущен")
    return true
end

-- Главный цикл
local function main()
    -- Даём игре время на загрузку после реджоина
    task.wait(3)
    getHRP()
    getServerEvent()

    killLoopActive = true
    task.spawn(killLoop)
    startSparring()
    lastFatigueTime = tick()
    local lastFatigueValue = getFatigue()

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
            lastFatigueTime = tick()
            lastFatigueValue = 0
        else
            -- Проверяем, растёт ли усталость (нормальный процесс тренировки)
            if fatigue > lastFatigueValue then
                lastFatigueTime = tick()
            end
            lastFatigueValue = fatigue
            -- Если усталость не растёт дольше rejoinCooldown секунд и при этом ниже порога, реджоинимся
            if tick() - lastFatigueTime > rejoinCooldown and fatigue < REST_THRESHOLD then
                print("Усталость не растёт (" .. fatigue .. "%) более " .. rejoinCooldown .. " сек, режоин")
                rejoinServer()
            end
        end
        task.wait(2)
    end
end

-- Запуск
pcall(main)
