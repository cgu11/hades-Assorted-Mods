ModUtil.RegisterMod("ScaleTest")

ModUtil.WrapBaseFunction("HandleNextSpawn", function( baseFunc, ... )
    local spawnedID = baseFunc( ... )
    SetScale({ Id = spawnedID, Fraction = 0.3, Duration = 0.0})
    return spawnedID
end, ScaleTest)