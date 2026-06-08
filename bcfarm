-- Sparring + AutoKill + Bed + Rejoin (каждые 5 сек при fatigue < 80%) + авто-перезапуск
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Сохраняем код скрипта для авто-перезапуска после режоина
if not _G.SparringScriptCode then
    _G.SparringScriptCode = debug and debug.getinfo(1).source:sub(2) or ""
    if _G.SparringScriptCode == "" then
        -- Если не удалось получить код, используем заглушку (но скрипт должен быть загружен через инжектор)
        _G.SparringScriptCode = "loadstring(game:HttpGet('https://raw.githubusercontent.com/jmiyazaki32-blip/bak/main/bcfarm.lua'))()"
    end
end

-- Настройка авто-перезапуска при телепортации
if not _G.SparringQueued then
    _G.SparringQueued = true
    local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if queue then
        queue("loadstring([[ " .. _G.SparringScriptCode .. " ]])()")
    end
end

-- Глобальные настройки
getgenv().G = true
getgenv().Creator = 'https://discord.gg/B3HqPPzFYr - HalloweenGaster'

local killLoopActive = false
local bedPos = Vector3.new(-231, 266, -565)
local REST_THRESHOLD = 80
local lastRejoinTime = 0
local rejoinDelay = 5 -- секунд

local serverEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Server")

-- === БЕСКОНЕЧНЫЙ КИЛЛ ВСЕХ NPC (КРОМЕ ИГРОКА) ===
local function killLoop()
    while killLoopActive and getgenv().G do
        -- Расширяем радиус симуляции (опционально)
        pcall(function()
            sethiddenproperty(player, "SimulationRadius", 112412400000)
            sethiddenproperty(player, "MaxSimulationRadius", 112412400000)
        end)
        -- Убиваем всех Humanoid, которые не принадлежат игроку
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Humanoid") and obj.Parent and obj.Parent.Name ~= player.Name then
                pcall(function() obj.Health = 0 end)
            end
        end
        task.wait(0.9)
    end
end

-- === ПОЛУЧЕНИЕ УСТАЛОСТИ ИЗ HUD ===
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

-- === БЕЗОПАСНЫЙ ТЕЛЕПОРТ ===
local function safeTeleport(pos)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        task.wait(0.3)
    end
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

-- === ОТДЫХ В КРОВАТИ ДО 0% УСТАЛОСТИ ===
local function restInBed()
    safeTeleport(bedPos)
    task.wait(3)
    for attempt = 1, 5 do
        local prompt, part = findBedPrompt()
        if prompt and part then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
                task.wait(0.3)
            end
            if fireproximityprompt then
                fireproximityprompt(prompt, 5)
                task.wait(0.5)
                -- Ждём, пока усталость не упадёт до 0
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

-- === РЕЖОИН (ПЕРЕЗАХОД) ===
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

-- === ЗАПУСК СПАРРИНГА С NPC ===
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

-- === ГЛАВНЫЙ ЦИКЛ (С РЕЖОИНОМ КАЖДЫЕ 5 СЕКУНД ПРИ УСТАЛОСТИ < 80%) ===
local function main()
    -- Ждём полной загрузки персонажа
    repeat
        task.wait(0.5)
    until game:IsLoaded() and player.Character and player.Character:FindFirstChild("HumanoidRootPart")

    -- Запускаем убийство NPC
    killLoopActive = true
    task.spawn(killLoop)

    -- Запускаем спарринг
    startSparring()

    lastRejoinTime = tick() -- запоминаем время начала

    -- Основной цикл проверки усталости
    while true do
        local fatigue = getFatigue()
        if fatigue >= REST_THRESHOLD then
            -- Усталость высокая -> идём отдыхать
            print("Усталость >=80%, идём в кровать")
            killLoopActive = false
            if restInBed() then
                print("Отдых завершён, усталость 0%")
            else
                print("Не удалось отдохнуть, режоин")
                rejoinServer()
            end
            -- После отдыха снова запускаем убийство и спарринг
            killLoopActive = true
            task.spawn(killLoop)
            startSparring()
            lastRejoinTime = tick() -- сбрасываем таймер режоина
        else
            -- Усталость ниже 80% -> проверяем, не пора ли сделать режоин
            if tick() - lastRejoinTime >= rejoinDelay then
                print("Усталость " .. fatigue .. "% (<80) -> режоин каждые 5 сек")
                rejoinServer()
            end
        end
        task.wait(2) -- проверяем усталость каждые 2 секунды
    end
end

-- Запуск с защитой от ошибок
local ok, err = pcall(main)
if not ok then
    print("Скрипт остановлен:", err)
end
