repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer.Character
if getgenv().Config.loaded then return end

-- getgenv().Config["Sell Pets"].Level = 30
-- getgenv().Config = {
--     ["Auto Pet"] = true,
-- }

local Task = loadstring(game:HttpGet("https://raw.githubusercontent.com/alienschub/alienhub/refs/heads/main/TaskController.luau"))()
local State = loadstring(game:HttpGet("https://raw.githubusercontent.com/alienschub/alienhub/refs/heads/main/StateController.luau"))()
local RateLimiter = loadstring(game:HttpGet("https://raw.githubusercontent.com/alienschub/alienhub/refs/heads/main/RateLimiter.luau"))()

Task.define("priority", "SubmitPet", "high")
Task.define("priority", "MutationPet", "high")
Task.define("singleton", "Trade", "high")
Task.define("normal", "AutoPlace", 51)
Task.define("normal", "AutoSell", 50)
Task.define("normal", "AutoFeed", 49)
Task.define("normal", "ApplyBooster", 48)
Task.define("normal", "AutoHatch", 47)

-- Modules
local PetListModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Data").PetRegistry.PetList)

-- Global Shared Variables
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Hum = Character:WaitForChild("Humanoid")
local config = getgenv().Config
local cachedPlayerData = nil

local settings = {
    ["Game"] = {
        ["Farm"] = {
            ["Self"] = nil,
            ["Can Plant"] = {},
            ["Eggs Point"] = {}
        },
        ["Player"] = {
            ["Backpack"] = {
                ["Fruits"] = {},
                ["Eggs"] = {},
                ["Pets"] = {},
                ["Booster"] = {}
            },
            ["Data"] = {
                maxEggs = 0,
                maxPets = 0,
                maxEquipedPets = 0,
                equipedPets = {},
                pets = {},
                dinoMachine = nil,
                petMutationMachine = nil,
                petEggStock = nil,
                gearStock = nil,
                seedStock = nil,
            }
        }
    }
}

-- Function
local function getFarm()
    for _, farm in ipairs(workspace:WaitForChild("Farm"):GetChildren()) do
        local success, owner = pcall(function()
            return farm:WaitForChild("Important").Data.Owner.Value
        end)
        if success and owner == Player.Name then
            return farm
        end
    end
    return nil
end

local function teleport(position)
    local adjustedPos = position + Vector3.new(0, 0.5, 0)
    HRP.CFrame = CFrame.new(adjustedPos)
end

local function getItemById(id)
    for _, container in ipairs({Player.Backpack, Player.Character}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    for key, value in pairs(tool:GetAttributes()) do
                        if value == id then
                            return tool
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function isHungry(hunger, petType, hungerThreshold)
    hungerThreshold = hungerThreshold or 0.50 -- default 25% (0.25)
    
    local maxHunger = PetListModule[petType].DefaultHunger

    if not hunger or not maxHunger then
        return false -- data tidak valid
    end

    return (hunger / maxHunger) < hungerThreshold
end

local function isAlreadyIn(list, uuid)
    for _, v in ipairs(list) do
        if v.uuid == uuid then return true end
    end
    return false
end

local function cleanToolFrom(t)
    for i = #t, 1, -1 do
        local tool = t[i].tool
        if not tool or not tool.Parent or (tool.Parent ~= Player.Backpack and not table.find(settings["Game"]["Player"]["Data"].equipedPets, t[i].uuid)) then
            table.remove(t, i)
        end
    end
end

local function isProtectedPet(pet, isKeep, isMutation)
    local name = pet.name
    local mutation = pet.mutation

    local keepConfig = config["Sell Pets"]["Keep"]
    local mutaList = keepConfig.Mutation[mutation]

    local isKeptType = isKeep and (table.find(keepConfig.Type, name) ~= nil)
    local isKeptMutation = isMutation and mutation and mutaList and (table.find(mutaList, name) ~= nil)
    local isAscended = mutation == "n"
    local isOstrich = name == "Ostrich"
    -- local isUsedPet = table.find(settings["Game"]["Player"]["Data"].equipedPets, pet.uuid)

    return isKeptType or isKeptMutation or isAscended or isOstrich
end

-- Init
getgenv().Config.loaded = true
-- track Character & HRP on respawn
Player.CharacterAdded:Connect(function(c)
    Character = c
    HRP = character:WaitForChild("HumanoidRootPart")
    Hum = character:WaitForChild("Humanoid")
end)

settings["Game"]["Farm"]["Self"] = getFarm()
settings["Game"]["Farm"]["Point"] = settings["Game"]["Farm"]["Self"]:WaitForChild("Important").Plant_Locations.Can_Plant.Position
local base = settings["Game"]["Farm"]["Point"]

-- Baris pertama: 5 titik di z - 15
for i = -2, 2 do
    table.insert(settings["Game"]["Farm"]["Eggs Point"], {
        Used = false,
        Position = Vector3.new(base.X + (i * 4), base.Y, base.Z - 15)
    })
end

-- Baris kedua: 3 titik di z - 19
for i = -1, 1 do
    table.insert(settings["Game"]["Farm"]["Eggs Point"], {
        Used = false,
        Position = Vector3.new(base.X + (i * 4), base.Y, base.Z - 19)
    })
end

-- Hook GetData
task.spawn(function()
    local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
    if typeof(DataService.GetData) == "function" then
        local oldGetData = DataService.GetData

        DataService.GetData = function(self, ...)
            local data = oldGetData(self, ...)
            cachedPlayerData = data
            return data
        end
    else
        warn("DataService.GetData bukan fungsi atau belum tersedia.")
    end
end)

-- Auto Buy Stock
task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            local data = settings["Game"]["Player"]["Data"]
            if not data or not data.petEggStock or not data.gearStock or not data.seedStock then return end

            -- Auto Buy Eggs
            if data.petEggStock and data.petEggStock.Stocks then
                local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("BuyPetEgg")
                for index, info in ipairs(data.petEggStock.Stocks) do
                    if info and info.Stock > 0 then
                        for i = 1, info.Stock do
                            remote:FireServer(index)
                            task.wait()
                        end
                    end
                end
            end

            -- Auto Buy Tools
            if data.gearStock and data.gearStock.Stocks then
                local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("BuyGearStock")
                for _, itemName in ipairs({ "Levelup Lollipop", "Medium Toy", "Medium Treat", "Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler", "Master Sprinkler" }) do
                    local info = data.gearStock.Stocks[itemName]
                    if info and info.Stock > 0 then
                        for i = 1, info.Stock do
                            remote:FireServer(itemName)
                            task.wait()
                        end
                    end
                end
            end

            -- Auto Buy Seeds
            if data.seedStock and data.seedStock.Stocks then
                local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuySeedStock")
                for itemName, info in pairs(data.seedStock.Stocks) do
                    if info and info.Stock > 0 then
                        for i = 1, info.Stock do
                            remote:FireServer(itemName)
                            task.wait()
                        end
                    end
                end
            end

        end)
        if not success then
            warn("[Task Error: Auto Buy Stock]", err)
        end
    end
end)


-- Backpack
task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            local data = cachedPlayerData
            local success, err = pcall(function()
                settings["Game"]["Player"]["Data"].maxEggs = data.PetsData.MutableStats.MaxEggsInFarm
                settings["Game"]["Player"]["Data"].maxPets = data.PetsData.MutableStats.MaxPetsInInventory
                settings["Game"]["Player"]["Data"].equipedPets = data.PetsData.EquippedPets
                settings["Game"]["Player"]["Data"].maxEquipedPets = data.PetsData.MutableStats.MaxEquippedPets
                settings["Game"]["Player"]["Data"].pets = data.PetsData.PetInventory.Data

                settings["Game"]["Player"]["Data"].dinoMachine = data.DinoMachine
                settings["Game"]["Player"]["Data"].petMutationMachine = data.PetMutationMachine

                settings["Game"]["Player"]["Data"].petEggStock = data.PetEggStock
                settings["Game"]["Player"]["Data"].gearStock = data.GearStock
                settings["Game"]["Player"]["Data"].seedStock = data.SeedStock
            end)

            if not success then
                warn("[PetData Error] Gagal update stat pet player:", err)
                return
            end


            local backpack = settings["Game"]["Player"]["Backpack"]
            backpack.Eggs = {}
            backpack.Booster = { xp = {}, passive = {}, unknow = {}}
            local fruits = backpack.Fruits
            for uuid, item in pairs(data.InventoryData) do
                local type = item.ItemType
                local data = item.ItemData
                local tool = getItemById(uuid)

                if type == "PetEgg" then
                    table.insert(backpack.Eggs, {
                        tool = tool,
                        uuid = uuid,
                        name = data.EggName,
                        amount = data.Uses
                    })
                elseif type == "Holdable" then
                    if not isAlreadyIn(fruits, uuid) then
                        table.insert(fruits, {
                            tool = tool,
                            uuid = uuid,
                            name = data.ItemName,
                            favorite = data.IsFavorite
                        })
                    end
                elseif type == "PetBoost" then
                    local boost = data.PetBoostType == "PET_XP_BOOST" and "xp"
                        or data.PetBoostType == "PASSIVE_BOOST" and "passive"
                        or "unknow"
                    table.insert(backpack.Booster[boost], {
                        tool = tool,
                        uuid = uuid,
                        amount = data.Uses
                    })
                end
            end

            local pets = backpack.Pets
            for uuid, pet in pairs(data.PetsData.PetInventory.Data or {}) do
                local type = pet.PetType
                local data = pet.PetData
                local tool = getItemById(uuid)

                if type then
                    if not isAlreadyIn(pets, uuid) then
                        table.insert(pets, {
                            tool = tool,
                            uuid = uuid,
                            name = type,
                            mutation = data.MutationType,
                            level = data.Level
                        })
                    end
                end
            end

            cleanToolFrom(backpack.Fruits)
            cleanToolFrom(backpack.Pets)
        end)
        if not success then
            warn("[Task Error: Backpack]", err)
        end
    end
end)

-- Auto Hatch Eggs
task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            local farm = settings["Game"]["Farm"]["Self"]
            if not farm then return end
            local petCount = 0
            for _ in pairs(settings["Game"]["Player"]["Data"].pets) do petCount = petCount + 1 end
            if petCount >= settings["Game"]["Player"]["Data"].maxPets then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetEggService")
            for _, egg in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                if egg.Name == "PetEgg" then
                    local time = egg:GetAttribute("TimeToHatch")
                    if time == 0 then
                        remote:FireServer("HatchPet", egg)
                        Task.normal("AutoHatch", function()
                            task.wait(0.5)
                        end, {})
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Hatch Eggs]", err)
        end
    end
end)

-- Auto Place Eggs
task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            local placed = 0

            -- Reset titik tempat egg
            for _, e in ipairs(settings["Game"]["Farm"]["Eggs Point"]) do e.Used = false end

            -- Hitung egg yang sudah ditempatkan & tandai titiknya
            for _, egg in ipairs(settings["Game"]["Farm"].Self:WaitForChild("Important").Objects_Physical:GetChildren()) do
                if egg.Name == "PetEgg" then
                    placed = placed + 1
                    local pos = egg.PetEgg.Position
                    for _, entry in ipairs(settings["Game"]["Farm"]["Eggs Point"]) do
                        if not entry.Used and math.abs(entry.Position.X - pos.X) <= 1 and math.abs(entry.Position.Z - pos.Z) <= 1 then
                            entry.Used = true
                            break
                        end
                    end
                end
            end

            local maxEggs = settings["Game"]["Player"]["Data"].maxEggs

            if placed < maxEggs then
                Task.normal("AutoPlace", function()
                    local remote = game.ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")
                    local eggsInBackpack = settings["Game"]["Player"]["Backpack"].Eggs

                    for _, eggName in ipairs(config["Place Eggs"]["Order By"]) do
                        if config["Place Eggs"]["Item"][eggName] then
                            -- Cari egg di backpack yang cocok dengan nama ini
                            for _, egg in ipairs(eggsInBackpack) do
                                if egg.name == eggName then
                                    Hum:EquipTool(egg.tool)
                                    task.wait(1)

                                    for i = 1, egg.amount do
                                        -- Cari titik penempatan yang belum dipakai
                                        local target = nil
                                        for _, p in ipairs(settings["Game"]["Farm"]["Eggs Point"]) do
                                            if not p.Used then
                                                target = p
                                                break
                                            end
                                        end

                                        if not target then return end

                                        -- Tempatkan egg
                                        remote:FireServer("CreateEgg", target.Position)
                                        target.Used = true
                                        placed = placed + 1
                                        task.wait(1)

                                        if placed >= maxEggs then return end
                                    end
                                end
                            end
                        end
                    end
                end, {})
            end

        end)
        if not success then
            warn("[Task Error: Auto Place Eggs]", err)
        end
    end
end)

-- Auto Pet
task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            local equipped = settings["Game"]["Player"]["Data"].equipedPets
            local maxEquipped = settings["Game"]["Player"]["Data"].maxEquipedPets
            local placed = #equipped
            local inventory = settings["Game"]["Player"]["Data"].pets
            local hungries = {}
            local active = {}

            for uuid, pet in pairs(inventory) do
                local hungry = isHungry(pet.PetData.Hunger, pet.PetType)
                if hungry then table.insert(hungries, uuid) end

                if table.find(equipped, uuid) then
                    if pet.PetType ~= "Ostrich" then
                        game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet", uuid)
                        placed = placed - 1
                        task.wait(0.2)
                    else
                        active[uuid] = pet
                    end
                end

                if placed < maxEquipped and pet.PetType == "Ostrich" then
                    active[uuid] = pet
                    
                    game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", uuid)
                    placed = placed + 1
                    task.wait(0.2)
                end
            end

             if #hungries > 0 then
                local fruits = settings["Game"]["Player"]["Backpack"].Fruits
                for i = #fruits, 1, -1 do
                    if fruits[i].favorite then
                        table.remove(fruits, i)
                    end
                end
                if #fruits == 0 then return end

                Task.normal("AutoFeed", function()
                    local fruits = settings["Game"]["Player"]["Backpack"].Fruits

                    for _, pet in ipairs(hungries) do
                        for i = #fruits, 1, -1 do
                            if fruits[i].favorite == false then
                                Hum:EquipTool(fruits[i].tool)
                                task.wait(0.5)

                                game:GetService("ReplicatedStorage").GameEvents.ActivePetService:FireServer("Feed", pet)
                                task.wait(0.3)

                                table.remove(fruits, i)

                                local hungry = isHungry(settings["Game"]["Player"]["Data"].pets[pet]["PetData"].Hunger, settings["Game"]["Player"]["Data"].pets[pet]["PetType"])
                                if not hungry then break end
                            end
                        end
                    end

                end, {})
            end

            if next(active) then
                local booster = settings.Game.Player.Backpack.Booster
                local nBoost = { xp = {}, passive = {} }

                for uuid, pet in pairs(active) do
                    local isNeed = { xp = true, passive = true }
                    for _, boost in ipairs(pet.PetData.Boosts) do
                        if boost.BoostType == "PET_XP_BOOST" then isNeed.xp = false end
                        if boost.BoostType == "PASSIVE_BOOST" then isNeed.passive = false end
                    end

                    if isNeed.xp then table.insert(nBoost.xp, uuid) end
                    if isNeed.passive then table.insert(nBoost.passive, uuid) end
                end

                local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetBoostService")
                if (#nBoost.xp > 0 and #booster.xp > 0) or (#nBoost.passive > 0 and #booster.passive > 0) then
                    local xp = booster.xp[1] or nil
                    local passive = booster.passive[1] or nil
                    Task.normal("ApplyBooster", function()
                        if xp then
                            Hum:EquipTool(xp.tool)
                            task.wait(1)
                            for _, pet in ipairs(nBoost.xp) do
                                remote:FireServer("ApplyBoost", pet)
                                xp.amount = xp.amount - 1
                                task.wait(0.1)
                                if xp.amount <= 0 then break end
                            end
                        end

                        if passive then
                            Hum:EquipTool(passive.tool)
                            task.wait(1)
                            for _, pet in ipairs(nBoost.passive) do
                                remote:FireServer("ApplyBoost", pet)
                                passive.amount = passive.amount - 1
                                task.wait(0.1)
                                if passive.amount <= 0 then break end
                            end
                        end
                    end, {})
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Pet]", err)
        end
    end
end)

-- Auto Sell Pet
task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            local farm = settings["Game"]["Farm"]["Self"]
            if not farm then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("SellPet_RE")
            local pets = settings.Game.Player.Backpack.Pets

            Task.normal("AutoSell", function()
                for i = #pets, 1, -1 do
                    local pet = pets[i]
                    local isProtected = isProtectedPet(pet, true, true)
                    if not isProtected and pet.level < config["Sell Pets"].Level then
                        Hum:EquipTool(pet.tool)
                        task.wait(1)

                        remote:FireServer(workspace[Player.Name][pet.tool.Name])
                        task.wait(2)
                    end
                end
            end, {})
        end)
        if not success then
            warn("[Task Error: Auto Sell Pet]", err)
        end
    end
end)

-- Trade Pet
game:GetService("TextChatService").OnIncomingMessage = function(msg)
    local cmd, lvl, amt = msg.Text:lower():match("^/(%w+)%s+(%d+)%s+(%w+)$")
    if cmd == "pet" and msg.TextSource then
        local level = tonumber(lvl)
        local sender = game.Players:GetNameFromUserIdAsync(msg.TextSource.UserId)
        if sender == Player.Name then return end
        
        local remote = game.ReplicatedStorage.GameEvents.PetGiftingService
        local pets = {}
        for _, pet in ipairs(settings.Game.Player.Backpack.Pets) do
            if pet.level >= level and not isProtectedPet(pet, true, true) then
                table.insert(pets, pet)
            end
        end

        table.sort(pets, function(a, b)
            return math.abs(a.level - level) < math.abs(b.level - level)
        end)

        if #pets == 0 then return end
        local amount = amt == "all" and #pets or tonumber(amt)
        Task.singleton("Trade", function()
            teleport(workspace[sender]:GetPivot().Position)
            task.wait(1)

            for i = 1, amount do
                Hum:EquipTool(pets[i].tool)
                task.wait(1)
                remote:FireServer("GivePet", game.Players[sender])
                task.wait(1)
            end
        end, {})
    end
end

-- Auto Dino Pet
task.spawn(function()
    while task.wait(2) do
        local success, err = pcall(function()
            local dinoMachine = settings["Game"]["Player"]["Data"].dinoMachine
            if not dinoMachine then return end

            if not dinoMachine.IsRunning then
                local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE")
                if dinoMachine.RewardReady then
                    remote:FireServer("ClaimReward")
                    task.wait(0.5)
                end

                local pets = settings.Game.Player.Backpack.Pets
                local target = nil
                for i = #pets, 1, -1 do
                    local pet = pets[i]
                    if not isProtectedPet(pet, true, true)
                        and pet.level < config["Sell Pets"].Level
                        and not table.find({"Pterodactyl", "Raptor", "Triceratops", "Stegosaurus", "Brontosaurus", "T-Rex"}, pet.name) then
                        target = pet
                        break
                    end
                end

                if not target then return end
                Task.priority("SubmitPet", function()
                    Hum:EquipTool(target.tool)
                    task.wait(0.5)

                    remote:FireServer("MachineInteract")
                    task.wait(1)
                end, {})
            end
        end)
        if not success then
            warn("[Task Error: Auto Dino Pet]", err)
        end
    end
end)

-- -- Auto Pet Mutation
task.spawn(function()
    while task.wait(2) do
        local success, err = pcall(function()
            local petMutationMachine = settings["Game"]["Player"]["Data"].petMutationMachine
            if not petMutationMachine then return end

            if not petMutationMachine.IsRunning then
                local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetMutationMachineService_RE")
                if petMutationMachine.PetReady then
                    remote:FireServer("ClaimMutatedPet")
                    task.wait(1)
                end

                local pets = settings.Game.Player.Backpack.Pets
                local target = nil
                local level = (config["Sell Pets"].Level and config["Sell Pets"].Level > 50) and config["Sell Pets"].Level or 60
                for i = #pets, 1, -1 do
                    local pet = pets[i]
                    if pet.level >= 50 and pet.level < level and not isProtectedPet(pet, false, true) then
                        target = pet
                        break
                    end
                end

                if not target then return end
                Task.priority("MutationPet", function()
                    -- sell 1 pet if full inventory
                    local petCount = 0
                    for _ in pairs(settings["Game"]["Player"]["Data"].pets) do petCount = petCount + 1 end
                    if petCount >= settings["Game"]["Player"]["Data"].maxPets then
                        for i = #pets, 1, -1 do
                            local pet = pets[i]
                            if not isProtectedPet(pet, true, true) then
                                Hum:EquipTool(pet.tool)
                                task.wait(0.5)

                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("SellPet_RE"):FireServer(workspace[Player.Name][pet.tool.Name])
                                task.wait(1.5)
                                break
                            end
                        end
                    end
                    Hum:EquipTool(target.tool)
                    task.wait(0.5)

                    remote:FireServer("SubmitHeldPet")
                    task.wait(1)
                    remote:FireServer("StartMachine")
                    task.wait(1)
                end, {})
            end
        end)
        if not success then
            warn("[Task Error: Auto Pet Mutation]", err)
        end
    end
end)