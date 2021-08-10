ModUtil.RegisterMod("RedressOfHermes")

local config = {
    Enabled = true
}
RedressOfHermes.Config = config

--Side hustle overrides
ModUtil.BaseOverride("StartEncounter", function( currentRun, currentRoom, currentEncounter )
    if CurrentRun.CurrentRoom.Encounter.EncounterType ~= "NonCombat" then
        ShowSuperMeter()
        if CurrentRun.CurrentRoom.Encounter == currentEncounter and currentEncounter ~= currentRoom.ChallengeEncounter and not CurrentRun.CurrentRoom.Encounter.DelayedStart then
            StartEncounterEffects( currentRun )
        end
    end

    if currentEncounter.DifficultyRating ~= nil and currentEncounter.EncounterType == "Default" then
        DebugPrint({ Text = currentEncounter.Name })
        DebugPrint({ Text = "    Encounter Difficulty = "..currentEncounter.DifficultyRating })
        for waveIndex, wave in pairs(currentEncounter.SpawnWaves) do
            DebugPrint({ Text = "        Wave #"..waveIndex })
            if wave.DifficultyRating ~= nil then
                DebugPrint({ Text = "        Wave Difficulty = "..wave.DifficultyRating })
            end

            for k, spawnEnemyArgs in pairs(wave.Spawns) do
                local enemyName = spawnEnemyArgs.Name or k or "?"
                local enemyCount = spawnEnemyArgs.TotalCount or spawnEnemyArgs.CountMax or "?"
                DebugPrint({ Text = "            "..enemyName.." "..enemyCount })
            end
        end
    end

    currentEncounter.Completed = false
    currentEncounter.InProgress = true
    if currentEncounter.TimerBlock ~= nil then
        AddTimerBlock( currentRun, currentEncounter.TimerBlock )
    end
    if CurrentRun.Hero.Health / CurrentRun.Hero.MaxHealth <= HealthUI.LowHealthThreshold and not currentRoom.HideLowHealthShroud then
        HeroDamageLowHealthPresentation( true )
    end
    if CurrentRun.CurrentRoom.Encounter == currentEncounter and currentEncounter ~= currentRoom.ChallengeEncounter then
        local goldPerRoom = round( GetTotalHeroTraitValue("MoneyPerRoom") )
        if HasHeroTraitValue( "BlockMoney" ) then
            goldPerRoom = 0
        end
        if goldPerRoom > 0 then
            if not CurrentRun.CurrentRoom.HideEncounterText then
                thread( PassiveGoldGainPresentation, goldPerRoom )
            end
            AddMoney( goldPerRoom, "Hermes Money Trait" )
        elseif goldPerRoom < 0 then 
            if not CurrentRun.CurrentRoom.HideEncounterText then
                thread( PassiveGoldGainPresentation, goldPerRoom )
            end
            SpendMoney( -1.0*goldPerRoom, "Hermes Money Trait" )
        end
    end

    StartTriggers( currentEncounter, currentEncounter.DistanceTriggers )

    if currentEncounter.UnthreadedEvents == nil then
        -- Event set for hand made encounters
        currentEncounter.UnthreadedEvents = EncounterSets.EncounterEventsDefault
    end
    RunEvents( currentEncounter )

    StartTriggers( currentEncounter, currentEncounter.PostCombatDistanceTriggers )

    currentEncounter.Completed = true
    currentRun.EncountersCompletedCache[currentEncounter.Name] = (currentRun.EncountersCompletedCache[currentEncounter.Name] or 0) + 1
    GameState.EncountersCompletedCache[currentEncounter.Name] = (GameState.EncountersCompletedCache[currentEncounter.Name] or 0) + 1

    -- Check for encounter-end effects
    if currentEncounter and currentEncounter.StartTime and not currentEncounter.ClearTime then
        currentEncounter.ClearTime = _worldTime - currentEncounter.StartTime
    end
    EndEncounterEffects( currentRun, currentRoom, currentEncounter )
    if not currentEncounter.SkipDisableTrapsOnEnd then
        DisableRoomTraps()
    end

    if currentEncounter ~= nil and currentEncounter.RemoveUpgradeOnEnd ~= nil then
        RemoveEnemyUpgrade(currentEncounter.RemoveUpgradeOnEnd, CurrentRun)
    end

    -- Check for encoutner complete exit
    wait( 0.2, RoomThreadName )
    if CheckRoomExitsReady( currentRoom ) then
        UnlockRoomExits( currentRun, currentRoom )
    end
end, RedressOfHermes)

-- modifying rush delivery to decrease damage on negative move speed
ModUtil.BaseOverride("CalculateDamageMultipliers", function( attacker, victim, weaponData, triggerArgs )
	local damageReductionMultipliers = 1
	local damageMultipliers = 1.0
	local lastAddedMultiplierName = ""

	if ConfigOptionCache.LogCombatMultipliers then
		DebugPrint({Text = " SourceWeapon : " .. tostring( triggerArgs.SourceWeapon )})
	end

	local addDamageMultiplier = function( data, multiplier )
		if multiplier >= 1.0 then
			if data.Multiplicative then
				damageReductionMultipliers = damageReductionMultipliers * multiplier
			else
				damageMultipliers = damageMultipliers + multiplier - 1
			end
			if ConfigOptionCache.LogCombatMultipliers then
				lastAddedMultiplierName = data.Name or "Unknown"
				DebugPrint({Text = " Additive Damage Multiplier (" .. lastAddedMultiplierName .. "):" .. multiplier })
			end
		else
			if data.Additive then
				damageMultipliers = damageMultipliers + multiplier - 1
			else
				damageReductionMultipliers = damageReductionMultipliers * multiplier
			end
			if ConfigOptionCache.LogCombatMultipliers then
				lastAddedMultiplierName = data.Name or "Unknown"
				DebugPrint({Text = " Multiplicative Damage Reduction (" .. lastAddedMultiplierName .. "):" .. multiplier })
			end
		end
	end

	if triggerArgs.ProjectileAdditiveDamageMultiplier then
		damageMultipliers = damageMultipliers + triggerArgs.ProjectileAdditiveDamageMultiplier
	end

	if victim.IncomingDamageModifiers ~= nil then
		for i, modifierData in pairs(victim.IncomingDamageModifiers) do
			if modifierData.GlobalMultiplier ~= nil then
				addDamageMultiplier( modifierData, modifierData.GlobalMultiplier)
			end
			
			local validWeapon = modifierData.ValidWeaponsLookup == nil or ( modifierData.ValidWeaponsLookup[ triggerArgs.SourceWeapon ] ~= nil and triggerArgs.EffectName == nil )

			if validWeapon and ( not triggerArgs.AttackerIsObstacle and ( attacker and attacker.DamageType ~= "Neutral" ) or modifierData.IncludeObstacleDamage or modifierData.TrapDamageTakenMultiplier ) then
				if modifierData.ZeroRangedWeaponAmmoMultiplier and RunWeaponMethod({ Id = victim.ObjectId, Weapon = "RangedWeapon", Method = "GetAmmo" }) == 0 then
					addDamageMultiplier( modifierData, modifierData.ZeroRangedWeaponAmmoMultiplier)
				end
				if modifierData.ValidWeaponMultiplier then
					addDamageMultiplier( modifierData, modifierData.ValidWeaponMultiplier)
				end
				if modifierData.ProjectileDeflectedMultiplier and triggerArgs.ProjectileDeflected then
					addDamageMultiplier( modifierData, modifierData.ProjectileDeflectedMultiplier)
				end

				if modifierData.BossDamageMultiplier and attacker and ( attacker.IsBoss or attacker.IsBossDamage ) then
					addDamageMultiplier( modifierData, modifierData.BossDamageMultiplier)
				end
				if modifierData.LowHealthDamageTakenMultiplier ~= nil and (victim.Health / victim.MaxHealth) <= modifierData.LowHealthThreshold then
					addDamageMultiplier( modifierData, modifierData.LowHealthDamageTakenMultiplier)
				end
				if modifierData.TrapDamageTakenMultiplier ~= nil and (( attacker ~= nil and attacker.DamageType == "Neutral" ) or (attacker == nil and triggerArgs.AttackerName ~= nil and EnemyData[triggerArgs.AttackerName] ~= nil and EnemyData[triggerArgs.AttackerName].DamageType == "Neutral" )) then
					addDamageMultiplier( modifierData, modifierData.TrapDamageTakenMultiplier)
				end
				if modifierData.DistanceMultiplier and triggerArgs.DistanceSquared ~= nil and triggerArgs.DistanceSquared ~= -1 and ( modifierData.DistanceThreshold * modifierData.DistanceThreshold ) <= triggerArgs.DistanceSquared then
					addDamageMultiplier( modifierData, modifierData.DistanceMultiplier)
				end
				if modifierData.ProximityMultiplier and triggerArgs.DistanceSquared ~= nil and triggerArgs.DistanceSquared ~= -1 and ( modifierData.ProximityThreshold * modifierData.ProximityThreshold ) >= triggerArgs.DistanceSquared then
					addDamageMultiplier( modifierData, modifierData.ProximityMultiplier)
				end
				if modifierData.NonTrapDamageTakenMultiplier ~= nil and (( attacker ~= nil and attacker.DamageType ~= "Neutral" ) or (attacker == nil and triggerArgs.AttackerName ~= nil and EnemyData[triggerArgs.AttackerName] ~= nil and EnemyData[triggerArgs.AttackerName].DamageType ~= "Neutral" )) then
					addDamageMultiplier( modifierData, modifierData.NonTrapDamageTakenMultiplier)
				end
				if modifierData.HitVulnerabilityMultiplier and triggerArgs.HitVulnerability then
					addDamageMultiplier( modifierData, modifierData.HitVulnerabilityMultiplier )
				end
				if modifierData.HitArmorMultiplier and triggerArgs.HitArmor then
					addDamageMultiplier( modifierData, modifierData.HitArmorMultiplier )
				end
				if modifierData.NonPlayerMultiplier and attacker ~= CurrentRun.Hero and attacker ~= nil and not HeroData.DefaultHero.HeroAlliedUnits[attacker.Name] then
					addDamageMultiplier( modifierData, modifierData.NonPlayerMultiplier)
				end
				if modifierData.SelfMultiplier and attacker == victim then
					addDamageMultiplier( modifierData, modifierData.SelfMultiplier)
				end
				if modifierData.PlayerMultiplier and attacker == CurrentRun.Hero then
					addDamageMultiplier( modifierData, modifierData.PlayerMultiplier )
				end
			end
		end
	end

	if attacker ~= nil and attacker.OutgoingDamageModifiers ~= nil and ( not weaponData or not weaponData.IgnoreOutgoingDamageModifiers ) then
		local appliedEffectTable = {}
		for i, modifierData in pairs(attacker.OutgoingDamageModifiers) do
			if modifierData.GlobalMultiplier ~= nil then
				addDamageMultiplier( modifierData, modifierData.GlobalMultiplier)
			end

			local validEffect = modifierData.ValidEffects == nil or ( triggerArgs.EffectName ~= nil and Contains(modifierData.ValidEffects, triggerArgs.EffectName ))
			local validWeapon = modifierData.ValidWeaponsLookup == nil or ( modifierData.ValidWeaponsLookup[ triggerArgs.SourceWeapon ] ~= nil and triggerArgs.EffectName == nil )
			local validTrait = modifierData.RequiredTrait == nil or ( attacker == CurrentRun.Hero and HeroHasTrait( modifierData.RequiredTrait ) )
			local validUniqueness = modifierData.Unique == nil or not modifierData.Name or not appliedEffectTable[modifierData.Name]
			local validEnchantment = true
			if modifierData.ValidEnchantments and attacker == CurrentRun.Hero then
				validEnchantment = false
				if modifierData.ValidEnchantments.TraitDependentWeapons then
					for traitName, validWeapons in pairs( modifierData.ValidEnchantments.TraitDependentWeapons ) do
						if Contains( validWeapons, triggerArgs.SourceWeapon) and HeroHasTrait( traitName ) then
							validEnchantment = true
							break
						end
					end
				end

				if not validEnchantment and modifierData.ValidEnchantments.ValidWeapons and Contains( modifierData.ValidEnchantments.ValidWeapons, triggerArgs.SourceWeapon ) then
					validEnchantment = true
				end
			end

			if validUniqueness and validWeapon and validEffect and validTrait and validEnchantment then
				if modifierData.Name then
					appliedEffectTable[ modifierData.Name] = true
				end
				if modifierData.HighHealthSourceMultiplierData and attacker.Health / attacker.MaxHealth > modifierData.HighHealthSourceMultiplierData.Threshold then
					addDamageMultiplier( modifierData, modifierData.HighHealthSourceMultiplierData.Multiplier )
				end
				if modifierData.PerUniqueGodMultiplier and attacker == CurrentRun.Hero then
					addDamageMultiplier( modifierData, 1 + ( modifierData.PerUniqueGodMultiplier - 1 ) * GetHeroUniqueGodCount( attacker ))
				end
				if modifierData.BossDamageMultiplier and victim.IsBoss then
					addDamageMultiplier( modifierData, modifierData.BossDamageMultiplier)
				end
				if modifierData.ZeroRangedWeaponAmmoMultiplier and RunWeaponMethod({ Id = attacker.ObjectId, Weapon = "RangedWeapon", Method = "GetAmmo" }) == 0 then
					addDamageMultiplier( modifierData, modifierData.ZeroRangedWeaponAmmoMultiplier)
				end
				if modifierData.EffectThresholdDamageMultiplier and triggerArgs.MeetsEffectDamageMultiplier then
					addDamageMultiplier( modifierData, modifierData.EffectThresholdDamageMultiplier)
				end
				if modifierData.PerfectChargeMultiplier and triggerArgs.IsPerfectCharge then
					addDamageMultiplier( modifierData, modifierData.PerfectChargeMultiplier)
				end

				if modifierData.UseTraitValue and attacker == CurrentRun.Hero then
					addDamageMultiplier( modifierData, GetTotalHeroTraitValue( modifierData.UseTraitValue, { IsMultiplier = modifierData.IsMultiplier }))
				end
				if modifierData.HitVulnerabilityMultiplier and triggerArgs.HitVulnerability then
					addDamageMultiplier( modifierData, modifierData.HitVulnerabilityMultiplier )
				end
				if modifierData.HitMaxHealthMultiplier and victim.Health == victim.MaxHealth and (victim.MaxHealthBuffer == nil or victim.HealthBuffer == victim.MaxHealthBuffer ) then
					addDamageMultiplier( modifierData, modifierData.HitMaxHealthMultiplier )
				end
				if modifierData.MinRequiredVulnerabilityEffects and victim.VulnerabilityEffects and TableLength( victim.VulnerabilityEffects ) >= modifierData.MinRequiredVulnerabilityEffects then
					--DebugPrint({Text = " min required vulnerability " .. modifierData.PerVulnerabilityEffectAboveMinMultiplier})
					addDamageMultiplier( modifierData, modifierData.PerVulnerabilityEffectAboveMinMultiplier)
				end
				if modifierData.HealthBufferDamageMultiplier and victim.HealthBuffer ~= nil and victim.HealthBuffer > 0 then
					addDamageMultiplier( modifierData, modifierData.HealthBufferDamageMultiplier)
				end
				if modifierData.StoredAmmoMultiplier and victim.StoredAmmo ~= nil and not IsEmpty( victim.StoredAmmo ) then
					local hasExternalStoredAmmo = false
					for i, storedAmmo in pairs(victim.StoredAmmo) do
						if storedAmmo.WeaponName ~= "SelfLoadAmmoApplicator" then
							hasExternalStoredAmmo = true
						end
					end
					if hasExternalStoredAmmo then
						addDamageMultiplier( modifierData, modifierData.StoredAmmoMultiplier)
					end
				end
				if modifierData.UnstoredAmmoMultiplier and IsEmpty( victim.StoredAmmo ) then
                    modifierData.Additive = true
					addDamageMultiplier( modifierData, modifierData.UnstoredAmmoMultiplier)
				end
				if modifierData.ValidWeaponMultiplier then
					addDamageMultiplier( modifierData, modifierData.ValidWeaponMultiplier)
				end
				if modifierData.RequiredSelfEffectsMultiplier and not IsEmpty(attacker.ActiveEffects) then
					local hasAllEffects = true
					for _, effectName in pairs( modifierData.RequiredEffects ) do
						if not attacker.ActiveEffects[ effectName ] then
							hasAllEffects = false
						end
					end
					if hasAllEffects then
						addDamageMultiplier( modifierData, modifierData.RequiredSelfEffectsMultiplier)
					end
				end

				if modifierData.RequiredEffectsMultiplier and victim and not IsEmpty(victim.ActiveEffects) then
					local hasAllEffects = true
					for _, effectName in pairs( modifierData.RequiredEffects ) do
						if not victim.ActiveEffects[ effectName ] then
							hasAllEffects = false
						end
					end
					if hasAllEffects then
						addDamageMultiplier( modifierData, modifierData.RequiredEffectsMultiplier)
					end
				end
				if modifierData.DistanceMultiplier and triggerArgs.DistanceSquared ~= nil and triggerArgs.DistanceSquared ~= -1 and ( modifierData.DistanceThreshold * modifierData.DistanceThreshold ) <= triggerArgs.DistanceSquared then
					addDamageMultiplier( modifierData, modifierData.DistanceMultiplier)
				end
				if modifierData.ProximityMultiplier and triggerArgs.DistanceSquared ~= nil and triggerArgs.DistanceSquared ~= -1 and ( modifierData.ProximityThreshold * modifierData.ProximityThreshold ) >= triggerArgs.DistanceSquared then
					addDamageMultiplier( modifierData, modifierData.ProximityMultiplier)
				end
				if modifierData.LowHealthDamageOutputMultiplier ~= nil and attacker.Health ~= nil and (attacker.Health / attacker.MaxHealth) <= modifierData.LowHealthThreshold then
					addDamageMultiplier( modifierData, modifierData.LowHealthDamageOutputMultiplier)
				end
				if modifierData.TargetHighHealthDamageOutputMultiplier ~= nil and (victim.Health / victim.MaxHealth) < modifierData.TargetHighHealthThreshold then
					addDamageMultiplier( modifierData, modifierData.TargetHighHealthDamageOutputMultiplier)
				end
				if modifierData.FriendMultiplier and ( victim == attacker or ( attacker.Charmed and victim == CurrentRun.Hero ) or ( not attacker.Charmed and victim ~= CurrentRun.Hero and not HeroData.DefaultHero.HeroAlliedUnits[victim.Name] )) then
					addDamageMultiplier( modifierData, modifierData.FriendMultiplier )
				end
				if modifierData.PlayerMultiplier and victim == CurrentRun.Hero then
					addDamageMultiplier( modifierData, modifierData.PlayerMultiplier )
				end
				if modifierData.NonPlayerMultiplier and victim ~= CurrentRun.Hero and not HeroData.DefaultHero.HeroAlliedUnits[victim.Name] then
					addDamageMultiplier( modifierData, modifierData.NonPlayerMultiplier )
				end
				if modifierData.FinalShotMultiplier and CurrentRun.CurrentRoom.ZeroAmmoVolley and CurrentRun.CurrentRoom.ZeroAmmoVolley[ triggerArgs.ProjectileVolley ] then
					addDamageMultiplier( modifierData, modifierData.FinalShotMultiplier)
				end
				if modifierData.LoadedAmmoMultiplier and CurrentRun.CurrentRoom.LoadedAmmo and CurrentRun.CurrentRoom.LoadedAmmo > 0 then
					addDamageMultiplier( modifierData, modifierData.LoadedAmmoMultiplier)
				end
				if modifierData.SpeedDamageMultiplier then
					local baseSpeed = GetBaseDataValue({ Type = "Unit", Name = "_PlayerUnit", Property = "Speed" })
					local speedModifier = CurrentRun.CurrentRoom.SpeedModifier or 1
					local currentSpeed = GetUnitDataValue({ Id = CurrentRun.Hero.ObjectId, Property = "Speed" }) * speedModifier
					if currentSpeed < baseSpeed then
                        modifierData.Additive = true
						addDamageMultiplier( modifierData, 1 + modifierData.SpeedDamageMultiplier * ( currentSpeed/baseSpeed - 1 ))
					end
				end

				if modifierData.ActiveDashWeaponMultiplier and triggerArgs.BlinkWeaponActive then
					addDamageMultiplier( modifierData, modifierData.ActiveDashWeaponMultiplier )
				end

				if modifierData.EmptySlotMultiplier and modifierData.EmptySlotValidData then
					local filledSlots = {}

					for i, traitData in pairs( attacker.Traits ) do
						if traitData.Slot then
							filledSlots[traitData.Slot] = true
						end
					end

					for key, weaponList in pairs( modifierData.EmptySlotValidData ) do
						if not filledSlots[key] and Contains( weaponList, triggerArgs.SourceWeapon ) then
							addDamageMultiplier( modifierData, modifierData.EmptySlotMultiplier )
						end
					end
				end
			end
		end
	end

	if weaponData ~= nil then
		if attacker == victim and weaponData.SelfMultiplier then
			addDamageMultiplier( { Name = weaponData.Name, Multiplicative = true }, weaponData.SelfMultiplier)
		end

		if weaponData.OutgoingDamageModifiers ~= nil and not weaponData.IgnoreOutgoingDamageModifiers then
			for i, modifierData in pairs(weaponData.OutgoingDamageModifiers) do
				if modifierData.NonPlayerMultiplier and victim ~= CurrentRun.Hero and not HeroData.DefaultHero.HeroAlliedUnits[victim.Name] then
					addDamageMultiplier( modifierData, modifierData.NonPlayerMultiplier)
				end
				if modifierData.PlayerMultiplier and ( victim == CurrentRun.Hero or HeroData.DefaultHero.HeroAlliedUnits[victim.Name] ) then
					addDamageMultiplier( modifierData, modifierData.PlayerMultiplier)
				end
				if modifierData.PlayerSummonMultiplier and HeroData.DefaultHero.HeroAlliedUnits[victim.Name] then
					addDamageMultiplier( modifierData, modifierData.PlayerSummonMultiplier)
				end
			end
		end
	end

	if ConfigOptionCache.LogCombatMultipliers and triggerArgs and triggerArgs.AttackerName and triggerArgs.DamageAmount then
		DebugPrint({Text = triggerArgs.AttackerName .. ": Base Damage : " .. triggerArgs.DamageAmount .. " Damage Bonus: " .. damageMultipliers .. ", Damage Reduction: " .. damageReductionMultipliers })
	end
	return damageMultipliers * damageReductionMultipliers
end, RedressOfHermes)

--- random hermes loot
ModUtil.WrapBaseFunction("CreateLoot", function( baseFunc, args )
    local lootData = args.LootData or LootData[args.Name]
    local numUpgrades =  CurrentRun.LootTypeHistory.HermesUpgrade or 0

    if lootData.GodLoot and numUpgrades > 0 and RandomChance(0.35) then
        args.LootData = LootData["HermesUpgrade"]
    end

    return baseFunc(args)

end, RedressOfHermes)

-- can't sell hermes boons
ModUtil.BaseOverride("CreateSellButtons", function()
    local itemLocationY = 370
	local itemLocationX = ScreenCenterX - 355
	local firstOption = true
	local buttonOffsetX = 350
	local components = ScreenAnchors.SellTraitScreen.Components
	local sellList = {}
	local upgradeOptionsTable = {}
	for itemIndex, sellData in pairs( CurrentRun.CurrentRoom.SellOptions ) do
		for index, traitData in pairs (CurrentRun.Hero.Traits) do
			if sellData.Name == traitData.Name and traitData.Rarity and ( upgradeOptionsTable[traitData.Name] == nil or GetRarityValue(upgradeOptionsTable[traitData.Name].Rarity) > GetRarityValue(traitData.Rarity) ) then
				upgradeOptionsTable[traitData.Name] = { Data = traitData, Value = sellData.Value }
			end
		end
	end

	for i, value in pairs(upgradeOptionsTable) do
		table.insert( sellList, value )
	end

	for itemIndex, sellData in pairs( sellList ) do
		local itemData = sellData.Data
		if itemData ~= nil then
			local itemBackingKey = "Backing"..itemIndex
			components[itemBackingKey] = CreateScreenComponent({ Name = "TraitBacking", Group = "Combat_Menu", X = ScreenCenterX, Y = itemLocationY })
			SetScaleY({ Id = components[itemBackingKey].Id, Fraction = 1.25 })
			local upgradeData = nil
			local upgradeTitle = nil
			local upgradeDescription = nil
			local upgradeData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemData.Name, Rarity = itemData.Rarity })
			local tooltipData = upgradeData
			SetTraitTextData( tooltipData, { OldOnly = true })
			upgradeTitle = GetTraitTooltipTitle( upgradeData )
			upgradeDescription = GetTraitTooltip( upgradeData, { ForTraitTray = true, Initial = true })
			-- Setting button graphic based on boon type
			local purchaseButtonKey = "PurchaseButton"..itemIndex

			local iconOffsetX = -338
			local iconOffsetY = -2
			local exchangeIconPrefix = nil
			local overlayLayer = "Combat_Menu_Overlay"

			components[purchaseButtonKey] = CreateScreenComponent({ Name = "SellSlot"..itemIndex, Group = "Combat_Menu", Scale = 1, X = itemLocationX + buttonOffsetX, Y = itemLocationY })
			if upgradeData.CustomRarityColor then
				components[purchaseButtonKey.."Patch"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX + 35, Y = iconOffsetY + itemLocationY })
				SetAnimation({ DestinationId = components[purchaseButtonKey.."Patch"].Id, Name = "BoonRarityPatch"})
				SetColor({ Id = components[purchaseButtonKey.."Patch"].Id, Color = upgradeData.CustomRarityColor })
			elseif itemData.Rarity ~= "Common" and itemData.Rarity then
				components[purchaseButtonKey.."Patch"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX + 35, Y = iconOffsetY + itemLocationY })
				SetAnimation({ DestinationId = components[purchaseButtonKey.."Patch"].Id, Name = "BoonRarityPatch"})
				SetColor({ Id = components[purchaseButtonKey.."Patch"].Id, Color = Color["BoonPatch" .. itemData.Rarity] })
			end

			if upgradeData.Icon ~= nil then
				components[purchaseButtonKey.."Icon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
				SetAnimation({ DestinationId = components[purchaseButtonKey.."Icon"].Id, Name = upgradeData.Icon .. "_Large" })
				SetScale({ DestinationId = components[purchaseButtonKey.."Icon"].Id, Fraction = 0.85 })
			end
			components[purchaseButtonKey.."IconOverlay"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."IconOverlay"].Id, Name = "Frame_Sell_Overlay" })
			SetAlpha({ Id = components[purchaseButtonKey.."IconOverlay"].Id, Fraction = 0, Duration = 0 })
			SetScale({ Id = components[purchaseButtonKey.."IconOverlay"].Id, Fraction = 0.85 })

			components[purchaseButtonKey.."Frame"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = iconOffsetX + itemLocationX + buttonOffsetX, Y = iconOffsetY + itemLocationY })
			SetAnimation({ DestinationId = components[purchaseButtonKey.."Frame"].Id, Name = "Frame_Sell"})
			SetScale({ Id = components[purchaseButtonKey.."Frame"].Id, Fraction = 0.85 })

			-- Button data setup
			components[purchaseButtonKey].OnPressedFunctionName = "HandleSellChoiceSelection"
			components[purchaseButtonKey].UpgradeName = upgradeData.Name
			components[purchaseButtonKey].Index = itemIndex
			components[purchaseButtonKey].Rarity = upgradeData.Rarity
			components[purchaseButtonKey].IsDuoBoon = upgradeData.IsDuoBoon
			if HasHeroTraitValue( "BlockMoney" ) then
				components[purchaseButtonKey].Value = 0
			else
				components[purchaseButtonKey].Value = sellData.Value
			end
			components[components[purchaseButtonKey].Id] = purchaseButtonKey
			-- Creates upgrade slot text
			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 665 })
			local selectionString = "UpgradeChoiceMenu_PermanentItem"
			local selectionStringColor = Color.Black

			local traitData = TraitData[itemData.Name]
			if traitData.Slot ~= nil then
				selectionString = "UpgradeChoiceMenu_"..traitData.Slot
			end

			local textOffset = 115 - buttonOffsetX
			local exchangeIconOffset = 0
			local lineSpacing = 8
			local traitNameOffset = LocalizationData.SellTraitScripts.UpgradeTitle.TraitNameOffsetX[GetLanguage({})] or 75
			local text = "Boon_Common"
			local overlayLayer = ""
			local color = Color.White
			if itemData.Rarity then
				text = "Boon_"..tostring(itemData.Rarity)
				color = Color["BoonPatch" .. itemData.Rarity ]
				if upgradeData.CustomRarityColor then
					color = upgradeData.CustomRarityColor
				end
			end
			if upgradeData.CustomRarityName then
				text = upgradeData.CustomRarityName
			end
			CreateTextBox(MergeTables(LocalizationData.SellTraitScripts.ShopButton,{
				Id = components[purchaseButtonKey].Id, Text = text,
				FontSize = 25,
				OffsetX = textOffset + 630, OffsetY = -60,
				Width = 720,
				Color = color,
				Font = "AlegreyaSansSCLight",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Right",
			}))

			CreateTextBox(MergeTables(LocalizationData.SellTraitScripts.ShopButton,{
				Id = components[purchaseButtonKey].Id,
				Text = "SellTraitPrefix",
				FontSize = 20,
				OffsetX = textOffset + exchangeIconOffset, OffsetY = -65,
				Color = Color.CostUnaffordableLight,
				Font = "AlegreyaSansSCRegular",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
			}))

			CreateTextBox(MergeTables(LocalizationData.SellTraitScripts.ShopButton,{
				Id = components[purchaseButtonKey].Id,
				Text = upgradeTitle,
				FontSize = 25,
				OffsetX = textOffset + exchangeIconOffset + traitNameOffset, OffsetY = -65,
				Color = color,
				Font = "AlegreyaSansSCLight",
				ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
				Justification = "Left",
				LuaKey = "TooltipData", LuaValue = tooltipData,
			}))

			CreateTextBox(MergeTables(LocalizationData.SellTraitScripts.ShopButton,{
				Id = components[purchaseButtonKey].Id, Text = "Sell_ItemCost", TextSymbolScale = 0.6, LuaKey = "TempTextData", LuaValue = { Amount = components[purchaseButtonKey].Value }, FontSize = 24,
				OffsetY = GetLocalizedValue(60, { { Code = "ja", Value = 75}, }),
				OffsetX = 430,
				Color = Color.Gold,
				Justification = "RIGHT",
				Font="AlegreyaSansSCBold",
				FontSize=26,
				LangJaScaleModifier = 0.85,
				ShadowColor = {0,0,0,1},
				ShadowOffsetY=2,
				ShadowOffsetX=0,
				ShadowAlpha=1,
				ShadowBlur=0,
				OutlineColor={0,0,0,1},
				OutlineThickness=2,
			}))

			CreateTextBoxWithFormat(MergeTables(LocalizationData.SellTraitScripts.ShopButton,{
				Id = components[purchaseButtonKey].Id,
				Text = upgradeDescription,
				OffsetX = textOffset, OffsetY = -40,
				Width = GetLocalizedValue(675, { { Code = "ja", Value = 670 }, }),
				Justification = "Left",
				VerticalJustification = "Top",
				LineSpacingBottom = lineSpacing,
				UseDescription = true,
				LuaKey = "TooltipData", LuaValue = tooltipData,
				Format = "BaseFormat",
				VariableAutoFormat = "BoldFormatGraft",
				TextSymbolScale = 0.8,
			}))

			if firstOption then
				TeleportCursor({ OffsetX = itemLocationX + buttonOffsetX, OffsetY = itemLocationY, ForceUseCheck = true, })
				firstOption = false
			end
            -- new code
            if string.find(upgradeData.Icon, "Hermes") then
                itemData.Blocked = true
                overlayLayer = "Combat_Menu"
                UseableOff({ Id = components[purchaseButtonKey].Id })
                ModifyTextBox({ Ids = components[purchaseButtonKey].Id, BlockTooltip = true })
                CreateTextBox({ Id = components[purchaseButtonKey].Id,
                Text = "ReducedLootChoicesKeyword",
                OffsetX = textOffset, OffsetY = -40,
                Color = Color.Transparent,
                Width = 675,
                })
                thread( TraitLockedPresentation, { Components = components, Id = purchaseButtonKey, OffsetX = itemLocationX + buttonOffsetX, OffsetY = iconOffsetY + itemLocationY } )
            end
		end
		itemLocationY = itemLocationY + 220
	end


	if IsMetaUpgradeSelected("RerollPanelMetaUpgrade") then
		local increment = 0
		if CurrentRun.CurrentRoom.SpentRerolls then
			increment = CurrentRun.CurrentRoom.SpentRerolls[ScreenAnchors.SellTraitScreen.Name] or 0
		end
		local cost = RerollCosts.SellTrait + increment
		if IsEmpty( CurrentRun.CurrentRoom.SellValues ) then
			cost = -1
		end
		local color = Color.White
		if CurrentRun.NumRerolls < cost then
			color = Color.CostUnaffordable
		end

		local name = "RerollPanelMetaUpgrade_ShortTotal"
		local tooltip = "MetaUpgradeRerollHint"
		if cost < 0 then
			name = "RerollPanel_Blocked"
			tooltip = "MetaUpgradeRerollBlockedHint"
		end

		components["RerollPanel"] = CreateScreenComponent({ Name = "ShopRerollButton", Scale = 1.0, Group = "Combat_Menu" })
		Attach({ Id = components["RerollPanel"].Id, DestinationId = components.ShopBackground.Id, OffsetX = -200, OffsetY = 440 })
		components["RerollPanel"].OnPressedFunctionName = "AttemptPanelReroll"
		components["RerollPanel"].RerollFunctionName = "RerollSellTraitScreen"
		components["RerollPanel"].Cost = cost
		components["RerollPanel"].RerollColor = Color.DarkRed
		components["RerollPanel"].RerollId = ScreenAnchors.SellTraitScreen.Name
		CreateTextBox({ Id = components["RerollPanel"].Id, Text = name, OffsetX = 28, OffsetY = -5,
		ShadowColor = {0,0,0,1}, ShadowOffset={0,3}, OutlineThickness = 3, OutlineColor = {0,0,0,1},
		FontSize = 28, Color = color, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
		SetInteractProperty({ DestinationId = components["RerollPanel"].Id, Property = "TooltipOffsetX", Value = 850 })
		CreateTextBox({ Id = components["RerollPanel"].Id, Text = tooltip, FontSize = 1, Color = Color.Transparent, Font = "AlegreyaSansSCExtraBold", LuaKey = "TempTextData", LuaValue = { Amount = cost }})
	end
end, RedressOfHermes)

ModUtil.LoadOnce( function()
    if RedressOfHermes.Config.Enabled then
        -- cutting lameo hermes boons
        ModUtil.MapNilTable(LootData, {
            HermesUpgrade = {
                Traits = true
            }
        })
        ModUtil.MapSetTable(LootData, {
            HermesUpgrade = {
                Traits = { "RegeneratingSuperTrait", "ChamberGoldTrait", "AmmoReloadTrait", "HermesShoutDodge", "HermesWeaponTrait", "HermesSecondaryTrait", "MoveSpeedTrait", "RushSpeedBoostTrait", "RapidCastTrait", "BonusDashTrait", "AmmoReclaimTrait" },
                LinkedUpgrades = {
                    SpeedDamageTrait = {
                        PriorityChance = 1.0
                    }
                }
            }
        })
        -- hermes boon appears first room
        ModUtil.MapSetTable(RoomSetData, {
            Tartarus = {
                RoomOpening = {
                    ForcedReward = "HermesUpgrade"
                }
            }
        })
        -- setting hermes rarity
        ModUtil.MapSetTable(HeroData, {
            DefaultHero = {
                HermesData =
                    {
                        ForceCommon = false,
                        RareChance = 0.30,
                        EpicChance = 0.15,
                        LegendaryChance = 0.20,
                    }
            }
        })
        -- making hermes boons appear without limit
        ModUtil.MapNilTable(RewardStoreData, {
            RunProgress = true
        })
        ModUtil.MapSetTable(RewardStoreData, {
            RunProgress = {
                    {
                        Name = "RoomRewardMaxHealthDrop",
                        GameStateRequirements =
                        {
                            -- None
                        },
                    },
                    {
                        Name = "RoomRewardMaxHealthDrop",
                        GameStateRequirements =
                        {
                            RequiredUpgradeableGodTraits = 1,
                        }
                    },
                    {
                        Name = "RoomRewardMoneyDrop",
                        GameStateRequirements =
                        {
                            -- None
                        },
                    },
                    {
                        Name = "RoomRewardMoneyDrop",
                        GameStateRequirements =
                        {
                            RequiredUpgradeableGodTraits = 1,
                        },
                    },
                    {
                        Name = "Boon",
                        AllowDuplicates = true,
                        GameStateRequirements =
                        {
                            -- None
                        },
                    },
                    {
                        Name = "Boon",
                        AllowDuplicates = true,
                        GameStateRequirements =
                        {
                            -- None
                        },
                    },
                    {
                        Name = "Boon",
                        AllowDuplicates = true,
                        GameStateRequirements =
                        {
                            -- None
                        },
                    },
                    {
                        Name = "Boon",
                        AllowDuplicates = true,
                        GameStateRequirements =
                        {
                            -- None
                        },
                    },
                    {
                        Name = "StackUpgrade",
                        GameStateRequirements =
                        {
                            RequiredUpgradeableGodTraits = 1,
                        }
                    },
                    {
                        Name = "StackUpgrade",
                        GameStateRequirements =
                        {
                            RequiredUpgradeableGodTraits = 2,
                        }
                    },
                    {
                        Name = "WeaponUpgrade",
                        GameStateRequirements =
                        {
                            RequiredMaxWeaponUpgrades = 0,
                            RequiredNotInStore = "WeaponUpgradeDrop",
                            RequiredMinCompletedRuns = 3,
                        }
                    },
                    {
                        Name = "WeaponUpgrade",
                        GameStateRequirements =
                        {
                            RequiredFalseConsumablesThisRun = { "ChaosWeaponUpgrade" },
                            RequiredMaxWeaponUpgrades = 1,
                            RequiredNotInStoreNames = { "ChaosWeaponUpgrade", "WeaponUpgradeDrop" },
                            RequiredMinCompletedRuns = 3,
                            RequiredMinDepth = 26,
                        }
                    },
                    {
                        Name = "HermesUpgrade",
                        GameStateRequirements =
                        {
                            AllowDuplicates = true,
                            --RequiredMaxHermesUpgrades = 1,
                            RequiredNotInStore = "HermesUpgradeDrop",
                            RequiredMinCompletedRuns = 3,
                            RequiredMinDepth = 12,
                        }
                    },
                    {
                        Name = "HermesUpgrade",
                        GameStateRequirements =
                        {
                            AllowDuplicates = true,
                            --RequiredMaxHermesUpgrades = 1,
                            RequiredNotInStore = "HermesUpgradeDrop",
                            RequiredMinCompletedRuns = 3,
                            RequiredMinDepth = 23,
                        }
                    },
                }
            })
        -- modifying traitdata
        ModUtil.MapNilTable(TraitData, {
            HermesShoutDodge = {
                PropertyChanges = true
            },
            RushSpeedBoostTrait = {
                PropertyChanges = true
            },
            BonusDashTrait = {
                PropertyChanges = true
            },
            DodgeChanceTrait = {
                PropertyChanges = true
            },
            UnstoredAmmoDamageTrait = {
                AddOutgoingDamageModifiers = true
            }
        })
        ModUtil.MapSetTable(TraitData, {
            RegeneratingSuperTrait = { --checked,
                SetupFunction = {
                    Args = {
                        Amount = -1
                    }
                }
            },
            ChamberGoldTrait = { 
                MoneyPerRoom = {
                    BaseValue = -10
                }
            },
            AmmoReloadTrait = { -- checked
                AmmoReloadTimeDivisor = {
                    BaseValue = 2.75/3
                }
            },
            HermesShoutDodge = {
                PropertyChanges = {
                    {
                        WeaponName = "HermesWrathBuff",
                        EffectName = "SpeedBonus",
                        EffectProperty = "Modifier",
                        BaseValue = -0.3,
                        ChangeType = "Add",
                        ExtractValue =
                        {
                            ExtractAs = "TooltipBonus",
                            Format = "Percent"
                        }
                    },
                    {
                        WeaponName = "HermesWrathBuff",
                        EffectName = "DodgeBonus",
                        EffectProperty = "DodgeChance",
                        BaseValue = -0.3,
                        ChangeType = "Add",
                    },
                    {
                        WeaponName = "HermesWrathBuff",
                        EffectName = "SpeedBonus",
                        EffectProperty = "Duration",
                        ChangeValue = 10,
                        ChangeType = "Absolute",
                        ExtractValue =
                        {
                            ExtractAs = "TooltipDuration",
                            SkipAutoExtract = true
                        }
                    },
                    {
                        WeaponName = "HermesWrathBuff",
                        EffectName = "DodgeBonus",
                        EffectProperty = "Duration",
                        ChangeValue = 10,
                        ChangeType = "Absolute",
                    },
                },
            },
            HermesWeaponTrait = {
                RarityLevels = {
                        Common =
                        {
                            MinMultiplier = 1.1/0.7,
                            MaxMultiplier = 1.1/0.7,
                        },
                        Rare =
                        {
                            MinMultiplier = 1.2/0.7,
                            MaxMultiplier = 1.2/0.7,
                        },
                        Epic =
                        {
                            MinMultiplier = 1.3/0.7,
                            MaxMultiplier = 1.3/0.7,
                        },
                        Heroic =
                        {
                            MinMultiplier = 1.4/0.7,
                            MaxMultiplier = 1.4/0.7,
                        },
                    },
                    ExtractEntry = {
                        BaseValue = 0.70
                    },
            },
            HermesSecondaryTrait = {
                RarityLevels = {
                    Common =
                    {
                        MinMultiplier = 1,
                        MaxMultiplier = 1,
                    },
                    Rare =
                    {
                        MinMultiplier = 2,
                        MaxMultiplier = 2,
                    },
                    Epic =
                    {
                        MinMultiplier = 3,
                        MaxMultiplier = 3,
                    },
                    Heroic =
                    {
                        MinMultiplier = 4,
                        MaxMultiplier = 4,
                    },
                },
                PropertyChanges = {
                    {
                        WeaponName = "SwordParry",
                        WeaponProperty = "ChargeStartAnimation",
                        ChangeValue = "ZagreusSwordParryChargeFast",
                        ChangeType = "Absolute",
                    },
                    {
                        TraitName = "DislodgeAmmoTrait",
                        WeaponName = "SwordParry",
                        WeaponProperty = "ChargeStartAnimation",
                        ChangeValue = "ZagreusSwordAlt02ParryChargeFast",
                        ChangeType = "Absolute",
                    },
                    {
                        TraitName = "SwordCriticalParryTrait",
                        WeaponName = "SwordParry",
                        WeaponProperty = "ChargeStartAnimation",
                        ChangeValue = "ZagreusSwordAlt01ParryChargeFast",
                        ChangeType = "Absolute",
                    },
                    {
                        TraitName = "SwordConsecrationTrait",
                        WeaponName = "SwordParry",
                        WeaponProperty = "ChargeStartAnimation",
                        ChangeValue = "ZagreusSwordAlt03ParryCharge", -- this is different from the others on purpose
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponName = "SwordParry",
                        EffectName = "SwordParryDisable",
                        EffectProperty = "Active",
                        ChangeValue = false,
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponName = "SwordParry",
                        EffectName = "SwordParryDisableCancelable",
                        EffectProperty = "Active",
                        ChangeValue = false,
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponName = "SwordParry",
                        EffectName = "SwordParryDisableFast",
                        EffectProperty = "Active",
                        ChangeValue = true,
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponName = "SwordParry",
                        EffectName = "SwordParryDisableFastCancelable",
                        EffectProperty = "Active",
                        ChangeValue = true,
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponName = "SwordParry",
                        WeaponProperty = "ChargeTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "SwordParry",
                        WeaponProperty = "Cooldown",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "SwordParry",
                        WeaponProperty = "CooldownWeaponSlotThree",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },

                    {
                        WeaponName = "SwordParry",
                        ProjectileProperty = "StartFx2",
                        ChangeValue = "HermesWings_SwordParry",
                        ChangeType = "Absolute",
                    },

                    {
                        WeaponName = "SpearWeaponThrow",
                        WeaponProperty = "ReloadTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },

                    {
                        WeaponName = "SpearWeaponThrow",
                        WeaponProperty = "ChargeTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponNames = { "SpearWeaponThrow", "SpearWeaponThrowReturn" },
                        ProjectileProperty = "Speed",
                        BaseValue = 0.9,
                        ChangeType = "Multiply",
                        SourceIsMultiplier = true,
                    },
                    --[[
                    {
                        WeaponName = "SpearWeaponThrow",
                        EffectName = "SpearThrowDisable",
                        EffectProperty = "Active",
                        ChangeValue = false,
                        ChangeType = "Absolute",
                    },
                    ]]
                    {
                        WeaponName = "SpearWeaponThrow",
                        EffectName = "SpearThrowDisableCancelable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "SpearWeaponThrowReturn",
                        EffectName = "SpearThrowReturnDisable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "SpearWeaponThrow",
                        ProjectileProperty = "StartFx2",
                        ChangeValue = "HermesWings_Bow",
                        ChangeType = "Absolute",
                    },

                    {
                        WeaponName = "SpearWeaponThrowReturn",
                        ProjectileProperty = "StartFx2",
                        ChangeValue = "null",
                        ChangeType = "Absolute",
                    },


                    {
                        WeaponNames = { "ShieldThrow", "ShieldThrowDash" },
                        WeaponProperty = "ReloadTime",
                        BaseValue =1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponNames = { "ShieldThrow", "ShieldThrowDash" },
                        WeaponProperty = "DisableOwnerForDuration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponNames = { "ShieldThrow", "ShieldThrowDash" },
                        ProjectileProperty = "Speed",
                        BaseValue = 0.9,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },

                    {
                        WeaponNames = { "ShieldThrow", "ShieldThrowDash" },
                        ProjectileProperty = "Acceleration",
                        BaseValue = 1/1.4,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponNames = { "ShieldThrow", "ShieldThrowDash" },
                        ProjectileProperty = "StartFx",
                        ChangeValue = "HermesShieldTrail",
                        ChangeType = "Absolute",
                    },

                    {
                        WeaponNames = { "ShieldThrow", "ShieldThrowDash" },
                        ProjectileProperty = "StartFx2",
                        ChangeValue = "HermesWings_Bow",
                        ChangeType = "Absolute",
                    },
                    {
                        TraitName = "ShieldTwoShieldTrait",
                        WeaponName = "ShieldThrow",
                        ProjectileProperty = "StartFx",
                        ChangeValue = "null",
                        ChangeType = "Absolute",
                    },

                    {
                        WeaponName = "BowSplitShot",
                        WeaponProperty = "ReloadTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        TraitName = "BowBondTrait",
                        WeaponName = "BowSplitShot",
                        WeaponProperty = "ChargeTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        TraitName = "BowBondTrait",
                        WeaponName = "BowSplitShot",
                        EffectName = "SplitShotDisable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "BowSplitShot",
                        WeaponProperty = "CooldownWeaponSlotThree",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponName = "BowSplitShot",
                        EffectName = "SplitShotDisable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "BowSplitShot",
                        EffectName = "SplitShotDisableCancelable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },

                    {
                        WeaponName = "BowSplitShot",
                        ProjectileProperty = "StartFx2",
                        ChangeValue = "HermesWings_Bow",
                        ChangeType = "Absolute",
                    },

                    {
                        WeaponName = "GunGrenadeToss",
                        WeaponProperty = "ReloadTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponName = "GunGrenadeToss",
                        EffectName = "GrenadeDisableCancelable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    -- this is for GunGrenadeFastTrait
                    {
                        WeaponName = "GunGrenadeToss",
                        WeaponProperty = "ClipRegenInterval",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },

                    {
                        WeaponName = "GunGrenadeToss",
                        ProjectileProperty = "StartFx2",
                        ChangeValue = "HermesWings_GunGrenade",
                        ChangeType = "Absolute",
                    },

                    {
                        WeaponName = "FistWeaponSpecial",
                        WeaponProperty = "ChargeTime",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "FistWeaponSpecial",
                        WeaponProperty = "Cooldown",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },
                    {
                        WeaponName = "FistWeaponSpecial",
                        EffectName = "FistSpecialDisableCancelable",
                        EffectProperty = "Duration",
                        BaseValue = 1.1,
                        SourceIsMultiplier = true,
                        ChangeType = "Multiply",
                    },

                },
                ExtractEntry = {
                    BaseValue = 1.1,
                }
            },
            RushRallyTrait = {
                RarityLevels = {
                    Common =
                    {
                        MinMultiplier = -0.30,
                        MaxMultiplier = -0.30,
                    },
                    Rare =
                    {
                        MinMultiplier = -0.40,
                        MaxMultiplier = -0.40,
                    },
                    Epic =
                    {
                        MinMultiplier = -0.50,
                        MaxMultiplier = -0.50,
                    },
                    Heroic =
                    {
                        MinMultiplier = -0.60,
                        MaxMultiplier = -0.60,
                    },
                }
            },
            MoveSpeedTrait = {
                RarityLevels = {
                    Common =
                    {
                        MinMultiplier = 0.8/1.2,
                        MaxMultiplier = 0.8/1.2,
                    },
                    Rare =
                    {
                        MinMultiplier = 0.7/1.2,
                        MaxMultiplier = 0.7/1.2,
                    },
                    Epic =
                    {
                        MinMultiplier = 0.6/1.2,
                        MaxMultiplier = 0.6/1.2,
                    },
                    Heroic =
                    {
                        MinMultiplier = 0.5/1.2,
                        MaxMultiplier = 0.5/1.2,
                    },
                }
            },
            RushSpeedBoostTrait = {
                PropertyChanges = {
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName = "RushWeaponSpeedBoost",
                        EffectProperty = "Active",
                        ChangeValue = true,
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName = "RushHyperArmor",
                        EffectProperty = "Active",
                        ChangeValue = true,
                        ChangeType = "Absolute",
                    },
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName = "RushHyperArmor",
                        EffectProperty = "Active",
                        ChangeValue = true,
                        ChangeType = "Absolute",
                        ExcludeLinked = true,
                    },
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName= "RushHyperArmor",
                        EffectProperty = "Modifier",
                        BaseMin = 1.3,
                        BaseMax = 1.3,
                        SourceIsMultiplier = true,
                        ChangeType = "Absolute",
                        ExtractValue =
                        {
                            ExtractAs = "TooltipDamageReduction",
                            Format = "NegativePercentDelta",
                        }
                    },
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName= "RushHyperArmor",
                        EffectProperty = "Duration",
                        BaseValue = 0.5,
                        ChangeType = "Absolute",
                    },
                                {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName = "RushWeaponSpeedBoost",
                        EffectProperty = "Duration",
                        BaseValue = 0.5,
                        ChangeType = "Absolute",
                        ExtractValue =
                        {
                            ExtractAs = "TooltipDuration",
                            DecimalPlaces = 2,
                        },
                    },
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        EffectName = "RushWeaponSpeedBoost",
                        EffectProperty = "Modifier",
                        ChangeValue = 0.5,
                        ChangeType = "Absolute",
                        SourceIsMultiplier = true,
                        ExtractValue =
                        {
                            ExtractAs = "TooltipSpeedBoost",
                            Format = "PercentDelta",
                        },
                    },
                },
            },
            RapidCastTrait = {
                RarityLevels = {
                    Common =
                    {
                        MinMultiplier = 1.2/0.8,
                        MaxMultiplier = 1.2/0.8,
                    },
                    Rare =
                    {
                        MinMultiplier = 1.4/0.8,
                        MaxMultiplier = 1.4/0.8,
                    },
                    Epic =
                    {
                        MinMultiplier = 1.6/0.8,
                        MaxMultiplier = 1.6/0.8,
                    },
                    Heroic =
                    {
                        MinMultiplier = 1.8/0.8,
                        MaxMultiplier = 1.8/0.8,
                    },
		        },
            },
            BonusDashTrait = {
                RarityLevels = {
                    Common =
                    {
                        Multiplier = 1.00,
                    },
                    Rare =
                    {
                        Multiplier = 1.00,
                    },
                    Epic =
                    {
                        Multiplier = 1.00,
                    },
                    Heroic =
                    {
                        Multiplier = 1.00,
                    }
		        },
                PropertyChanges = {
                    {
                        WeaponNames = WeaponSets.HeroRushWeapons,
                        WeaponProperty = "ClipSize",
                        BaseValue = 1,
                        ChangeType = "Absolute"
                    },
                }
            },
            DodgeChanceTrait = {
                PropertyChanges = {
                    {
                        LifeProperty = "DodgeChance",
                        BaseValue = -0.10,
                        ChangeType = "Add",
                        DataValue = false,
                        ExtractValue =
                        {
                            ExtractAs = "TooltipChance",
                            Format = "Percent"
                        },
                    },
                }
            },
            AmmoReclaimTrait = {
                RarityLevels = {
                    Common =
                    {
                        MinMultiplier = 0.5,
                        MaxMultiplier = 0.5,
                    },
                    Rare =
                    {
                        MinMultiplier = 1.0/2.5,
                        MaxMultiplier = 1.0/2.5,
                    },
                    Epic =
                    {
                        MinMultiplier = 0.3333,
                        MaxMultiplier = 0.3333,
                    },
                    Heroic =
                    {
                        Multiplier = 1.0/3.5,
                    }
                },
            },
            -- shouldn't need to change RD since all the buffs are negative,
            -- need to make sure negative speed applies though. we'll let ichor/hades call do their thing :)
            -- SpeedDamageTrait = {
            --     SpeedDamageMultiplier = {
            --         BaseValue = -0.5
            --     },
            -- },
            MagnetismTrait = {
                AmmoDropUseDelay = {
                    BaseValue = 1000
                }
            },
            UnstoredAmmoDamageTrait = {
                AddOutgoingDamageModifiers = {
                    UnstoredAmmoMultiplier = 0.5,
                    ExtractValues =
                    {
                        {
                            Key = "UnstoredAmmoMultiplier",
                            ExtractAs = "TooltipDamage",
                            Format = "PercentDelta",
                        },
                    }
		        },
            },
            FastClearDodgeBonusTrait = {
                FastClearDodgeBonus = {
                    BaseValue = -0.01
                },
                FastClearSpeedBonus = {
                    BaseValue = -0.01
                }
            }
            
        })
    end

end)