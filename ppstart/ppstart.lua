ModUtil.RegisterMod("ppstart")


-- force reward type (starting, boon or hammer), only for first room if requested
ModUtil.WrapBaseFunction("ChooseRoomReward", function( baseFunc, run, room, rewardStoreName, previouslyChosenRewards, args )
    local startingReward = RunStartControl.StartingData.StartingReward

    if room.Name == "RoomOpening"  then
        return "Boon"
    else
        return baseFunc(run, room, rewardStoreName, previouslyChosenRewards, args)
    end
end, ppstart)

ModUtil.WrapBaseFunction("ChooseLoot", function( baseFunc, excludeLootNames, forceLootName )
    -- checking if it's the first boon, and we have a god to overwrite with
    if IsEmpty(GetAllUpgradableGodTraits()) then
        return baseFunc( excludeLootNames, "ArtemisUpgrade" )
    else
        return baseFunc( excludeLootNames, forceLootName)
    end
end, ppstart)

ModUtil.WrapBaseFunction("SetTraitsOnLoot", function(baseFunc, lootData, args)
    if CurrentRun.CurrentRoom.Name == "RoomOpening" then
        lootData.BlockReroll = true
        lootData.UpgradeOptions = {
            ItemName = "CritBonusTrait",
            Type = 'Trait',
            Rarity = 'Epic',
        }
    else
        baseFunc(lootData, args)
    end
end, ppstart)