ModUtil.RegisterMod("BargeOfExtraDeath")

local config = {
    Enabled = true
}
BargeOfExtraDeath.Config = config

BargeOfExtraDeath.CrawlerMiniBoss2 = DeepCopyTable(EnemyData['CrawlerMiniBoss'])
BargeOfExtraDeath.CrawlerMiniBoss2.SpawnOptions = {
    "ThiefImpulseMineLayerElite"
}
BargeOfExtraDeath.CrawlerMiniBoss2.WeaponOptions = {
     "CrawlerRushMiniBoss", "CrawlerRushMiniBoss", "CrawlerSpawns", "CrawlerRushMiniBoss"
}
BargeOfExtraDeath.BargeOfExtraDeathEncounter = DeepCopyTable(EncounterData.WrappingAsphodel)

BargeOfExtraDeath.BargeOfExtraDeathEncounter.ManualWaveTemplates = nil
BargeOfExtraDeath.BargeOfExtraDeathEncounter.RequiredInactiveMetaUpgrade = nil
BargeOfExtraDeath.BargeOfExtraDeathEncounter.EnemySet = nil
BargeOfExtraDeath.BargeOfExtraDeathEncounter.MinWaves = 5
BargeOfExtraDeath.BargeOfExtraDeathEncounter.MaxWaves = 5
BargeOfExtraDeath.BargeOfExtraDeathEncounter.SpawnWaves = {
    -- wave 1, MM barge encounter copy
    {
        Spawns =
        {
            {
                Name = "ShieldRangedMiniBoss",
                TotalCount = 1,
                SpawnOnIds = { 514164 },
                ForceFirst = true,
            },
            {
                Name = "BloodlessWaveFistElite",
                CountMin = 3,
                CountMax = 3,
            },
            {
                Name = "BloodlessGrenadierElite",
                CountMin = 3,
                CountMax = 3,
            },
        },
        StartDelay = 0,
        OverrideValues =
        {
            SpawnIntervalMin = 0.175,
            SpawnIntervalMax = 0.225,
        },
    },
    -- wave 2, MM power couple
    {
        Spawns =
        {
            {
                Name = "HitAndRunUnitElite",
                TotalCount = 2,
                ForceFirst = true,
            },
            {
                Name = "CrusherUnitElite",
                TotalCount = 2
            },
        },
        StartDelay = 2,
        OverrideValues =
        {
            SpawnIntervalMin = 0.175,
            SpawnIntervalMax = 0.225,
        },
    },
    -- wave 3, asterius
    {
        Spawns =
        {
            {
                Name = "Minotaur",
                TotalCount = 1,
                SpawnOnIds = { 514164 },
                ForceFirst = true,
            },
        },
        StartDelay = 2,
        OverrideValues =
        {
            SpawnIntervalMin = 0.175,
            SpawnIntervalMax = 0.225,
        },
    },
    -- wave 4, 3x sneak, 1 super elite soul catcher
    {
        Spawns =
        {
            {
                Name = "FlurrySpawnerSuperElite",
                TotalCount = 1,
                SpawnOnIds = { 514164 },
                ForceFirst = true,
            },
            {
                Name = "WretchAssassinMiniboss",
                TotalCount = 2,
            },
            {
                Name = "RangedBurrowerSuperElite",
                TotalCount = 3,
            },
        },
        StartDelay = 2,
        OverrideValues =
        {
            SpawnIntervalMin = 0.175,
            SpawnIntervalMax = 0.225,
        },
    },
    -- wave 5, tiny vermin
    {
        Spawns =
        {
            {
                Name = "CrawlerMiniBoss2",
                TotalCount = 1,
                SpawnOnIds = { 514164 },
                ForceFirst = true,
            },
        },
        StartDelay = 0.5,
        OverrideValues =
        {
            SpawnIntervalMin = 0.175,
            SpawnIntervalMax = 0.225,
        },
    },
}
EncounterData["BargeOfExtraDeathEncounter"] = BargeOfExtraDeath.BargeOfExtraDeathEncounter


BargeOfExtraDeath.RoomOverrides = {
    Asphodel = {
        [1] = {
            Room = RoomSetData.Asphodel.B_Combat09,
            Reward = "HermesUpgrade",
            BoonRaritiesOverride = {
                EpicChance = 1.0,
                LegendaryChance = 0.5
            }
        },
        [2] = {
            Room = RoomSetData.Asphodel.B_Combat06,
            Reward = "WeaponUpgrade",
        },
        [3] = {
            Room = RoomSetData.Asphodel.B_Shop01,
            Reward = "Shop"
        },
        [4] = {
            Room = RoomSetData.Asphodel.B_Story01,
            Reward = "Story"
        },
        [5] = {
            Room = RoomSetData.Asphodel.B_Wrapping01,
            LegalEncounters = {"BargeOfExtraDeathEncounter"},
            BoonRaritiesOverride = {
                HeroicChance = 1.0,
                LegendaryChance = 0.5
            }
        },
        [6] = {
            Room = RoomSetData.Asphodel.B_Reprieve01,
            Reward = "Boon",
            BoonRaritiesOverride = {
                HeroicChance = 1.0,
                LegendaryChance = 0.5
            }
        }
    }
}

ModUtil.WrapBaseFunction("ChooseNextRoomData", function( baseFunc, run, args ) 
    local nextRoomData = baseFunc(run, args)
    local biome = nextRoomData.RoomSetName
    local currentBiomeDepth = GetBiomeDepth(CurrentRun)

    if BargeOfExtraDeath.Config.Enabled and BargeOfExtraDeath.RoomOverrides[biome] ~= nil and 
       not nextRoomData.NoReward and BargeOfExtraDeath.RoomOverrides[biome][currentBiomeDepth]  then
        local overrideData = BargeOfExtraDeath.RoomOverrides[biome][currentBiomeDepth]
        nextRoomData = overrideData.Room
        nextRoomData.BoonRaritiesOverride = overrideData.BoonRaritiesOverride or nil
        nextRoomData.ForcedReward = overrideData.Reward or nil
        nextRoomData.LegalEncounters = overrideData.LegalEncounters or nextRoomData.LegalEncounters

        return nextRoomData
    else
        return nextRoomData
    end


end, BargeOfExtraDeath)

ModUtil.WrapBaseFunction( "StartRoom", function(baseFunc, currentRun, currentRoom )
    baseFunc( currentRun, currentRoom )

    if BargeOfExtraDeath.Config.Enabled and currentRoom.Name == "B_Wrapping01" then
        LoadPackages({Names = {
            "Minotaur",
            "CrawlerMiniBoss",
            "ShieldRangedMiniBoss",
            "RangedBurrowerSuperElite",
            "WretchAssassinMiniboss",
            "FlurrySpawnerSuperElite",
            "HitAndRunUnitElite",
            "CrusherUnitElite",
            "BloodlessWaveFistElite",
            "BlodlessGrenadierElite"
        }})
    end
end, BargeOfExtraDeath)

ModUtil.WrapBaseFunction("ChooseEncounter", function( baseFunc, currentRun, room )
    if BargeOfExtraDeath.Config.Enabled and room.Name == "B_Wrapping01" then
        EnemyData["CrawlerMiniBoss2"] = BargeOfExtraDeath.CrawlerMiniBoss2
    end
    return baseFunc( currentRun, room )

end, ToggleableShenanigans)