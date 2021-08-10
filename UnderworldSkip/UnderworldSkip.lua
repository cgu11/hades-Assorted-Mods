ModUtil.RegisterMod("UnderworldSkip")

local config = {
    Enabled = true,
    AthenaRoom = false
}
UnderworldSkip.Config = config

ModUtil.WrapBaseFunction( "StartNewGame", function( baseFunc )
    baseFunc()
    if UnderworldSkip.Config.Enabled then
        GameState.UnderworldSkip = true
    end

end, UnderworldSkip)

ModUtil.WrapBaseFunction( "ChooseNextRoomData", function( baseFunc, currentRun, args)
    local skipDepth = 1.0
    if UnderworldSkip.Config.AthenaRoom then
        skipDepth = 2.0
    end

    if UnderworldSkip.Config.Enabled and GameState.UnderworldSkip and currentRun.RunDepthCache >= skipDepth then
        DebugPrint({Text="SET"})

        return RoomData["D_Boss01"]
    else
        DebugPrint({Text="FAIL"})
        return baseFunc(currentRun, args)
    end

end, UnderworldSkip)