--[[
    ChargedShotLotto
    Author:
        Museus (Discord: cgull#4469)

    Equip beowulf and Pom Blossom for a fun experience
]]
ModUtil.RegisterMod("ChargedShotLotto")

local config = {
    Enabled = true,
}
ChargedShotLotto.Config = config
ChargedShotLotto.CurrentCastTrait = {}

ChargedShotLotto.Casts = {
    "ShieldLoadAmmo_ZeusRangedTrait",
    "ShieldLoadAmmo_AphroditeRangedTrait",
    "ShieldLoadAmmo_ArtemisRangedTrait",
    "ShieldLoadAmmo_DemeterRangedTrait",
    "ShieldLoadAmmo_AresRangedTrait",
    "ShieldLoadAmmo_AthenaRangedTrait",
    "PoseidonRangedTrait",
    "DionysusRangedTrait",
}
ChargedShotLotto.Rarities = {
    "Common",
    "Rare",
    "Epic",
    --"Heroic",
}

-- loading animataions and assets

ModUtil.WrapBaseFunction( "SetupMap", function(baseFunc)
    LoadPackages({Names = {
        "ZeusUpgrade",
        "PoseidonUpgrade",
        "AthenaUpgrade",
        "AphroditeUpgrade",
        "ArtemisUpgrade",
        "AresUpgrade",
        "DionysusUpgrade",
        "HermesUpgrade",
        "DemeterUpgrade",
        "Chaos"
    }})
    return baseFunc()
end)

-- force hammer start
ModUtil.WrapBaseFunction("ChooseRoomReward", function(baseFunc, run, room, rewardStoreName, previouslyChosenRewards, args)
    if ChargedShotLotto.Config.Enabled and HeroHasTrait("ShieldLoadAmmoTrait") and room.Name == "RoomOpening" then
        return "WeaponUpgrade"
    else
        return baseFunc(run, room, rewardStoreName, previouslyChosenRewards, args)
    end
end, ChargedShotLotto)

-- force charged shot hammer
ModUtil.WrapBaseFunction("SetTraitsOnLoot", function(baseFunc, lootData, args)
    if ChargedShotLotto.Config.Enabled and HeroHasTrait("ShieldLoadAmmoTrait") and CurrentRun.RunDepthCache <= 1.0 and lootData.Name == "WeaponUpgrade" then
        lootData.BlockReroll = true
        lootData.UpgradeOptions = {
            { 
                ItemName = "ShieldRushProjectileTrait", 
                Type = "Trait",
                Rarity = "Common",
            }
        }
    else
        baseFunc(lootData, args)
    end
end, ChargedShotLotto)

-- cast roulette
ModUtil.WrapBaseFunction("StartRoom", function(baseFunc, currentRun, currentRoom)
    if ChargedShotLotto.Config.Enabled and HeroHasTrait("ShieldLoadAmmoTrait") then
        if ChargedShotLotto.CurrentCastTrait.Name == nil then
            ChargedShotLotto.CurrentCastTrait = {
                Name = GetRandomValue(ChargedShotLotto.Casts),
                Rarity = GetRandomValue(ChargedShotLotto.Rarities)
            }
            AddTraitToHero({ TraitData = GetProcessedTraitData({ 
                Unit = CurrentRun.Hero,
                TraitName = ChargedShotLotto.CurrentCastTrait.Name,
                Rarity = ChargedShotLotto.CurrentCastTrait.Rarity
            })})
        else
            local castLevel = GetTraitNameCount(CurrentRun.Hero, ChargedShotLotto.CurrentCastTrait.Name)
            if castLevel == nil then
                castLevel = 1
            end
            while HeroHasTrait(ChargedShotLotto.CurrentCastTrait.Name) do
                RemoveTrait(CurrentRun.Hero, ChargedShotLotto.CurrentCastTrait.Name)
            end

            ChargedShotLotto.CurrentCastTrait = {
                Name = GetRandomValue(ChargedShotLotto.Casts),
                Rarity = GetRandomValue(ChargedShotLotto.Rarities)
            }

            AddTraitToHero({ TraitData = GetProcessedTraitData({ 
                Unit = CurrentRun.Hero,
                TraitName = ChargedShotLotto.CurrentCastTrait.Name,
                Rarity = ChargedShotLotto.CurrentCastTrait.Rarity
            })})

            for i=1, castLevel - 1 do
                AddTraitToHero({ TraitData = GetProcessedTraitData({ 
                    Unit = CurrentRun.Hero,
                    TraitName = ChargedShotLotto.CurrentCastTrait.Name,
                    Rarity = ChargedShotLotto.CurrentCastTrait.Rarity
                })})
            end
        end
    end
    baseFunc(currentRun, currentRoom)
end, ChargedShotLotto)