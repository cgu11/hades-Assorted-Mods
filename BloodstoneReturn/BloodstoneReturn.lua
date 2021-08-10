ModUtil.RegisterMod("BloodstoneReturn")

local config = {
    Enabled = true
}
BloodstoneReturn.Config = config

ModUtil.WrapBaseFunction("EndEncounterEffects", function( baseFunc, ... )
    baseFunc( ... )

    -- returning infernal casts
    if IsMetaUpgradeActive("AmmoMetaUpgrade") and BloodstoneReturn.Config.Enabled then
        local ammoIds = GetIdsByType({ Name = "AmmoPack" })
        SetObstacleProperty({ Property = "Magnetism", Value = 3000, DestinationIds = ammoIds })
        SetObstacleProperty({ Property = "MagnetismSpeedMax", Value = currentRun.Hero.LeaveRoomAmmoMangetismSpeed, DestinationIds = ammoIds })
        StopAnimation({ DestinationIds = ammoIds, Name = "AmmoReturnTimer" })

    -- refilling stygian casts
    elseif IsMetaUpgradeActive("ReloadAmmoMetaUpgrade") and BloodstoneReturn.Config.Enabled then
        ReloadRangedAmmo(0)
    end
end, BloodstoneReturn)