--[[
  GateControl
  Authors:
    cgull (Discord: cgull#4469)

    This mod allows for controlling of Chaos/Erebus appearance rates, entrance costs, etc
]]--
ModUtil.RegisterMod("GateControl")

local chaosConfig = {
    
    -- appearance rates
    TartarusChance = 1, --0.15 default
    AsphodelChance = 0.075, --0.075 default
    ElysiumChance = 0.05, --0.05 default

    -- chamber cooldowns (how many chambers before chaos can be seen again)
    TartarusCooldown = 0,--10 default
    AsphodelCooldown = 8, --8 default
    ElysiumCooldown = 8, --8 default

    -- entrance cost control (HP collected)
    BaseCost = 13, --20 default
    DepthScaling = 0 -- Additional damage per chamber you've gone through, 0.2 default

}

local erebusConfig = {
    -- appearance rates
    TartarusChance = 1, --0.15 default
    AsphodelChance = 0.15, --0.15 default
    ElysiumChance = 0.15, --0.15 default

    -- chamber cooldowns (how many chambers before chaos can be seen again)
    TartarusCooldown = 0,--8 default
    AsphodelCooldown = 8, --8 default
    ElysiumCooldown = 8, --8 default

    -- entrance cost control (Heat required to enter)
    TartarusCost = 60, --5 default
    AsphodelCost = 10, --10 default
    ElysiumCost = 15 --15 default

}

-- global config

local config = {
  Enabled = true, 
  EnableTartarusMidBossGates = true,
  ChaosConfig = chaosConfig,
  ErebusConfig = erebusConfig
}

GateControl.Config = config

GateControl.ProtectedRooms = {
  Return01 = true,
  RoomChallenge01 = true,
  A_PostBoss01 = true,
  B_PostBoss01 = true,
  C_PostBoss01 = true,
}

GateControl.TartarusMidBosses = {
  A_MiniBoss01 = true,
  A_MiniBoss02 = true,
  A_MiniBoss03 = true,
  A_MiniBoss04 = true,
}

GateControl.RoomOverrides = {
  Tartarus = 
  {
    SecretSpawnChance = GateControl.Config.ChaosConfig.TartarusChance,
    SecretDoorRequirements = {
      RequiredTextLines = { "HermesFirstPickUp" },
      RequiredFalseTextLinesThisRun = { "HermesFirstPickUp" },
      -- run rollout preqs
      RequiredFalseTextLinesThisRun = { "CharonFirstMeeting", "CharonFirstMeeting_Alt", "HermesFirstPickUp", "SisyphusFirstMeeting" },

      RequiredMinRoomsSinceSecretDoor = GateControl.Config.ChaosConfig.TartarusCooldown,
    },
    ShrinePointDoorSpawnChance = GateControl.Config.ErebusConfig.TartarusChance,
    ShrinePointDoorCost = GateControl.Config.ErebusConfig.TartarusCost,
    ShrinePointDoorRequirements = {
      RequiredScreenViewed = "ShrineUpgrade",
      RequiredMinRoomsSinceShrinePointDoor = GateControl.Config.ErebusConfig.TartarusCooldown,
      RequireEncounterCompleted = "EnemyIntroFight01",
      RequiredCosmetics = { "ShrinePointGates", },
  }
  },
  Asphodel = {
    SecretSpawnChance = GateControl.Config.ChaosConfig.AsphodelChance,
    SecretDoorRequirements = {
      RequiredTextLines = { "HermesFirstPickUp" },
      RequiredFalseTextLinesThisRun = { "HermesFirstPickUp" },
      -- run rollout preqs
      RequiredFalseTextLinesThisRun = { "CharonFirstMeeting", "CharonFirstMeeting_Alt", "HermesFirstPickUp", "SisyphusFirstMeeting" },

      RequiredMinRoomsSinceSecretDoor = GateControl.Config.ChaosConfig.AsphodelCooldown,
    },
    ShrinePointDoorSpawnChance = GateControl.Config.ErebusConfig.AshpodelChance,
    ShrinePointDoorCost = GateControl.Config.ErebusConfig.AsphodelCost,
    ShrinePointDoorRequirements = {
      RequiredScreenViewed = "ShrineUpgrade",
      RequiredMinRoomsSinceShrinePointDoor = GateControl.Config.ErebusConfig.AsphodelCooldown,
      RequireEncounterCompleted = "EnemyIntroFight01",
      RequiredCosmetics = { "ShrinePointGates", },
  }
  },
  Elysium = {
    SecretSpawnChance = GateControl.Config.ChaosConfig.ElysiumChance,
    SecretDoorRequirements = {
      RequiredTextLines = { "HermesFirstPickUp" },
      RequiredFalseTextLinesThisRun = { "HermesFirstPickUp" },
      -- run rollout preqs
      RequiredFalseTextLinesThisRun = { "CharonFirstMeeting", "CharonFirstMeeting_Alt", "HermesFirstPickUp", "SisyphusFirstMeeting" },

      RequiredMinRoomsSinceSecretDoor = GateControl.Config.ChaosConfig.ElysiumCooldown,
    },
    ShrinePointDoorSpawnChance = GateControl.Config.ErebusConfig.ElysiumChance,
    ShrinePointDoorCost = GateControl.Config.ErebusConfig.ElysiumCost,
    ShrinePointDoorRequirements = {
      RequiredScreenViewed = "ShrineUpgrade",
      RequiredMinRoomsSinceShrinePointDoor = GateControl.Config.ErebusConfig.ElysiumCooldown,
      RequireEncounterCompleted = "EnemyIntroFight01",
      RequiredCosmetics = { "ShrinePointGates", },
  }
  },
}

-- editing chaos cost values
ModUtil.LoadOnce( function ()
    if GateControl.Config.Enabled then
        ModUtil.MapSetTable( HeroData, {
          DefaultHero = {
            SecretDoorCostBase = GateControl.Config.ChaosConfig.BaseCost,
            SecretDoorCostDepthScalar = GateControl.Config.ChaosConfig.DepthScaling
          }
        })
    end
end)

ModUtil.WrapBaseFunction( "CreateRoom", function( baseFunc, roomData, args)
    if GateControl.Config.Enabled then
        local isStyx = roomData.RoomSetName == "Styx"
        local isProtected = GateControl.ProtectedRooms[roomData.Name]
        local inheritsFromProtected = false
        for i, parentRoom in ipairs(roomData.InheritFrom) do
          inheritsFromProtected = GateControl.ProtectedRooms[parentRoom]
          if inheritsFromProtected then break end
        end
        local isTartarusMidboss = GateControl.TartarusMidBosses[roomData.Name]

        if isStyx or isProtected or inheritsFromProtected or (isTartarusMidboss and not GateControl.Config.EnableTartarusMidBossGates) then
          return baseFunc(roomData, args)
        end

        local roomOverrides = GateControl.RoomOverrides[roomData.RoomSetName]

        if args == nil then
          args = {}
        end
        if args.RoomOverrides == nil then
          args.RoomOverrides = roomOverrides
        else
          for k, v in pairs(roomOverrides) do
            args.RoomOverrides[k] = v
          end
        end
    end
    return baseFunc(roomData, args)

end, GateControl)