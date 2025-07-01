local remote = game.ReplicatedStorage.Remotes.Combat
local fxremote = game.ReplicatedStorage.Remotes.CombatFX
local rs = game:GetService("ReplicatedStorage")
local t = game:GetService("TweenService")
local weaponmodule = require(game.ReplicatedStorage.Modules.Weapons)

local TRADE_WINDOW = 0.08 -- (Adjust this value for how tight you want the clash timing)

-- Server-side combat state for each player
local playerCombatState = {}
local heavyAttackCooldowns = {} -- [player] = lastHeavyTime


local textures = {
	'rbxassetid://8821193347',
	'rbxassetid://8821230983',
	'rbxassetid://8821246947',
	'rbxassetid://8821254467',
	'rbxassetid://8821272181',
	'rbxassetid://8821280832',
	'rbxassetid://8821300395',
	'rbxassetid://8821311218',
	'rbxassetid://8896641723',
}

game.Players.PlayerRemoving:Connect(function(player)
	playerCombatState[player] = nil
	heavyAttackCooldowns[player] = nil
end)


local function ensureBlockTagMatchesState(char)
	-- If not blocking, forcibly disable Block tag if present
	if char:FindFirstChild("Block") and not char:GetAttribute("Blocking") then
		char.Block.Value = false
	end
end

local function handleHit(p, data)
	local now = tick()
	local clashList = {}

	for i, v in pairs(data.hb) do
		local attackerChar = p.Character
		local victimChar = v

		local tradeLock = victimChar:FindFirstChild("TradeLock")
		if tradeLock then
			if now - tradeLock.Value < TRADE_WINDOW then
				fxremote:FireAllClients("ClashFX", attackerChar, victimChar)
				table.insert(clashList, victimChar)
				continue
			else
				tradeLock:Destroy()
			end
		end

		local newLock = Instance.new("NumberValue")
		newLock.Name = "TradeLock"
		newLock.Value = now
		newLock.Parent = victimChar
		game.Debris:AddItem(newLock, TRADE_WINDOW)

		if v.Parent == game.Workspace.dummies then
			if v:FindFirstChild("HitCooldown") then
				continue -- Skip if it has a cooldown
			end
			local hitCooldown = Instance.new("BoolValue")
			hitCooldown.Name = "HitCooldown"
			hitCooldown.Parent = v
			game.Debris:AddItem(hitCooldown, 0.3) -- Cooldown duration

			if v:FindFirstChild("Triggered") then
				v:FindFirstChild("Triggered"):Destroy()
			end
			local triggered = Instance.new("BoolValue", v)
			triggered.Name = 'Triggered'
			game.Debris:AddItem(triggered, 60)

			local playername = p.Name
			if not v.Damaged:FindFirstChild(playername) then
				local creatortag = Instance.new("NumberValue", v.Damaged)
				creatortag.Name = playername
				creatortag.Value = 0
			end
		end

		if v:FindFirstChild("PB") then
			-- Add PBSTUN BoolValue
			local pbStun = Instance.new("BoolValue")
			pbStun.Name = "PBSTUN"
			pbStun.Parent = p.Character
			game.Debris:AddItem(pbStun, 1.75)

			local pbsnd = rs.Sounds.PB:Clone()
			local pbAnim = Instance.new("Animation")
			pbAnim.AnimationId = 'rbxassetid://73512030889657'
			local playpb = p.Character.Humanoid:LoadAnimation(pbAnim)
			playpb:Play()
			pbsnd.Parent = p.Character.HumanoidRootPart
			pbsnd:Play()
			game.Debris:AddItem(pbsnd, 1.2)
			pbAnim:Destroy()
		elseif v:FindFirstChild("Block") then
			if v.Block.Value == true then
				if data.combo == 5 then
					local gb = Instance.new("BoolValue", v)
					gb.Name = "GB"
					gb.Value = false

					local gbeff = game.ReplicatedFirst.Combat.Sword.Fx.GB:Clone()
					gbeff.Anchored = false
					local weld = Instance.new("Weld", gbeff)
					weld.Part0 = v:FindFirstChild("HumanoidRootPart")
					weld.Part1 = gbeff
					weld.C1 = weld.C1 * CFrame.Angles(0,0,math.rad(math.random(-300,300)))
					gbeff.Parent = v:FindFirstChild("HumanoidRootPart")
					wait(.05)
					for i,vv in pairs(gbeff.Attachment:GetChildren()) do
						if vv:IsA("ParticleEmitter") then
							vv:Emit(1)
						end
					end
					local gbsnd = rs.Sounds.guardbreak:Clone()
					gbsnd.Parent = v.HumanoidRootPart
					gbsnd:Play()
					game.Debris:AddItem(gbsnd, 1)
					game.Debris:AddItem(gbeff, 1)
					v.ChildAdded:Connect(function(bb)
						if v:FindFirstChild("GB") then
							v.Block.Value = false
							if v:FindFirstChild("Blocking") then
								v:FindFirstChild("Blocking"):Destroy()
							end
						end
					end)
					game.Debris:AddItem(gb, 2)
					v.ChildRemoved:Connect(function(bb)
						if v:FindFirstChild("GB") then
							v.Block.Value = false
							if v:FindFirstChild("Blocking") then
								v:FindFirstChild("Blocking"):Destroy()
							end
						else
							wait(1)
						end
					end)
				end
				local parryAnim = Instance.new("Animation")
				parryAnim.AnimationId = data.parry
				local playpar = v.Humanoid:LoadAnimation(parryAnim)
				playpar:Play()
				local blocksnd = rs.Sounds["Sword Parry"]:Clone()
				blocksnd.Parent = v.HumanoidRootPart
				blocksnd:Play()
				local blockpri = Instance.new('BoolValue', p.Character)
				blockpri.Name = 'hit block'
				game.Debris:AddItem(blockpri, .5)

				coroutine.resume(coroutine.create(function()
					wait(.3)
					playpar:Stop()
				end))
				parryAnim:Destroy()
				game.Debris:AddItem(blocksnd, .5)
			else
				local hitAnim = Instance.new("Animation")
				hitAnim.AnimationId = data.hit
				local playhit = v.Humanoid:LoadAnimation(hitAnim)
				playhit:Play()

				local choices = {
					rs.Sounds["Sword hit"]:Clone(),
					rs.Sounds["another hit"]:Clone()
				}

				local hitsnd
				if data.isKick then
					hitsnd=game.ReplicatedStorage.Sounds.Weapons.SwordKick:Clone()
				else
					hitsnd= choices[math.random(1,2)]
				end

				local hitsnd = choices[math.random(1,2)]
				local hpr = v:FindFirstChild("HumanoidRootPart")
				if hpr then
					hitsnd.Parent = hpr
				end
				hitsnd:Play()

				local dmg
				local weaponInstance = p.Character:FindFirstChild("CurrentWeapon")
				if weaponInstance and weaponInstance.Value then
					local weapon = weaponInstance.Value
					local weaponData = weaponmodule[weapon]
					if weaponData then
						dmg = weaponData.Damage
					else
						warn("Weapon data not found in weaponmodule for: " .. tostring(weapon))
					end
				else
					warn("CurrentWeapon not found or has no value!")
				end
				local sworddamagebuff = p.Character:FindFirstChild("Stats").SwordDamage.Value or 1

				v.Humanoid:TakeDamage(dmg * sworddamagebuff)
				if v:FindFirstChild('Damaged') then
					if v.Damaged:FindFirstChild(p.Name) then
						v.Damaged[p.Name].Value += dmg
					end
				end
				game.Debris:AddItem(hitsnd, .5)
			end
		else
			local hitAnims = {
				'rbxassetid://106066883606093',
				'rbxassetid://75949832039549',
			}
			local hitAnim = Instance.new("Animation")
			hitAnim.AnimationId = hitAnims[math.random(1, #hitAnims)]

			local playhit = v.Humanoid:LoadAnimation(hitAnim)
			playhit:Play()
			local choices = {
				rs.Sounds["Sword hit"]:Clone(),
				rs.Sounds["Sword hit"]:Clone()
			}
			local hitsnd
			if data.isKick then
				hitsnd=game.ReplicatedStorage.Sounds.Weapons.SwordKick:Clone()
			else
				hitsnd= choices[math.random(1,2)]
			end


			local hpr = v:FindFirstChild("HumanoidRootPart")
			if hpr then
				hitsnd.Parent = hpr
			end
			hitsnd:Play()


			local weaponInstance = p.Character:FindFirstChild("CurrentWeapon")
			local dmg
			if weaponInstance and weaponInstance.Value then
				local weapon = weaponInstance.Value
				local weaponData = weaponmodule[weapon]
				if weaponData then
					dmg = weaponData.Damage
				else
					warn("Weapon data not found in weaponmodule for: " .. tostring(weapon))
				end
			else
				warn("CurrentWeapon not found or has no value!")
			end
			if v:FindFirstChild('Damaged') then
				if v.Damaged:FindFirstChild(p.Name) then
					v.Damaged[p.Name].Value += dmg
				end
			end
			local sworddamagebuff = p.Character:FindFirstChild("Stats").SwordDamage.Value or 1

			v.Humanoid:TakeDamage(dmg * sworddamagebuff)
			game.Debris:AddItem(hitsnd, .5)
		end

		local bv = Instance.new("BodyVelocity", v:FindFirstChild("HumanoidRootPart"))
		bv.MaxForce = Vector3.new(99999, 0, 99999)
		bv.Name = 'v'
		bv.P = 10
		game.Debris:AddItem(bv, .2)

		local chp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if data.combo == 5 and v:FindFirstChild("GB") == nil and v:FindFirstChild("PB") == nil then
			bv.Velocity = chp.CFrame.LookVector * 120
			for _, j in v:GetChildren() do
				if j.Name == 'Stun' then
					game.Debris:AddItem(j, 0.1)
				end
			end
		end

		local isBlocking = v:FindFirstChild("Block") and v.Block.Value == true
		if not isBlocking then
			local weaponName = tostring(p.Character:FindFirstChild("CurrentWeapon") and p.Character.CurrentWeapon.Value or "")
			local weaponData = weaponmodule[weaponName]
			local stunTime = (weaponData and weaponData.StunTime) or 0.7

			local stun = Instance.new("BoolValue", v)
			stun.Name = "Stun"
			stun.Value = false
			game.Debris:AddItem(stun, stunTime)

			if victimChar:FindFirstChild("Attacking") then
				victimChar.Attacking:Destroy()
			end
		end
		ensureBlockTagMatchesState(v)
	end
	data.clashList = {}
	for _, clashChar in ipairs(clashList) do
		table.insert(data.clashList, clashChar.Name)
	end
	remote:FireAllClients(data)
end

local function handleCombatRemote(p, data)
	if not p.Character or not p.Character:FindFirstChild("Humanoid") then return end

	-- ========== Block/unblock actions ==========
	if data.action == "SetAttribute" and data.attribute and data.value ~= nil then
		p.Character:SetAttribute(data.attribute, data.value)
		return
	end

	if data.action == 'block' then
		local pbWindow = Instance.new("BoolValue", p.Character)
		pbWindow.Name = "PB"
		pbWindow.Value = false
		local blockWin = Instance.new("BoolValue", p.Character)
		blockWin.Name = "Blocking"
		blockWin.Value = false
		game.Debris:AddItem(pbWindow, .2)
		if p.Character:FindFirstChild("Block") then
			p.Character.Block.Value = true
		else
			local block = Instance.new("BoolValue", p.Character)
			block.Value = true
			block.Name = 'Block'
		end
		p.Character:SetAttribute("Blocking", true)
		ensureBlockTagMatchesState(p.Character)
		return
	elseif data.action == 'unblock' then
		if p.Character:FindFirstChild("Block") then
			p.Character.Block.Value = false
			if p.Character:FindFirstChild("Blocking") then
				p.Character:FindFirstChild("Blocking"):Destroy()
			end
		end
		p.Character:SetAttribute("Blocking", false)
		ensureBlockTagMatchesState(p.Character)
		return
	end

	-- ========== SERVER-AUTHORIZED ATTACK INPUT ==========
	if data.action == "Attack" then
		local weaponName = tostring(p.Character:FindFirstChild("CurrentWeapon") and p.Character.CurrentWeapon.Value or "")
		local weaponData = weaponmodule[weaponName] or {}
		local atkSpeed = weaponData.AtkSpeed or 0.2
		local comboResetTime = 1.4

		local state = playerCombatState[p]
		local now = tick()
		if not state then
			state = {lastAttack = 0, combo = 1}
		end

		-- Reset combo if waited too long
		if now - state.lastAttack > comboResetTime then
			state.combo = 1
		end

		-- Gate by cooldown
		if now - state.lastAttack  < atkSpeed then
			return -- Attack too soon
		end

		state.lastAttack = now
		local currentCombo = state.combo

		print("[DEBUG][Attack] Combo before increment:", currentCombo)

		-- Broadcast to all clients
		remote:FireAllClients({
			action = "Slash",
			attacker = p.Name,
			combo = currentCombo
		})

		-- Next combo or reset
		-- Set SwordSlowed to true (slows the player)
		if p.Character then
			p.Character:SetAttribute("SwordSlowed", true)
		end

		if currentCombo < 5 then
			state.combo = currentCombo + 1
			state.lastAttack = now
		else
			state.combo = 1
			state.lastAttack = now + 1.75 - atkSpeed -- Still enforce reset, but not SwordSlowed!
		end
		print("[DEBUG][Attack] Combo after increment:", state.combo)
		playerCombatState[p] = state

		-- Unslow after attack speed for ALL hits, including 5th
		task.delay(atkSpeed, function()
			if p.Character then
				p.Character:SetAttribute("SwordSlowed", false)
			end
		end)

		-- Play swing sound
		local swingsnd = rs.Sounds.Weapons["Basic Swing"]:Clone()
		swingsnd.Parent = p.Character.HumanoidRootPart
		swingsnd:Play()
		game.Debris:AddItem(swingsnd, .5)
		ensureBlockTagMatchesState(p.Character)
		return
	end

	-- ========== HEAVY ATTACK (right-click) ==========
	if data.action == "Heavy" then

		local state = playerCombatState[p]

		if not state then
			state = {lastAttack = 0, combo = 1}
		end
		print("[DEBUG][Heavy] Combo at heavy:", state.combo)

		--kick logic

		if state.combo == 5 then
			print("[DEBUG][Heavy] KICK!")
			local c = p.Character
			local hum = c:FindFirstChildOfClass("Humanoid")
			local hrp = c:FindFirstChild("HumanoidRootPart")
			if not hum or not hrp then return end

			-- Endlag and SwordSlowed ON
			p.Character:SetAttribute("SwordSlowed", true)
			local endlag = Instance.new("BoolValue")
			endlag.Name = "Endlag"
			endlag.Parent = p.Character

			-- Play windup animation and effects
			local windupAnim = Instance.new("Animation")
			windupAnim.AnimationId = "rbxassetid://103890244240263"
			local windupTrack = hum:LoadAnimation(windupAnim)
			windupTrack:Play()
			local sound1 = game.ReplicatedStorage.Sounds.M2:Clone()
			sound1.Parent = hrp
			sound1:Play()
			game.Debris:AddItem(sound1, 5)

			local heavyfx = game.ReplicatedFirst.Combat.Sword.Fx.M2:Clone()
			heavyfx.Parent = workspace.Fx
			heavyfx.CFrame = hrp.CFrame
			local weld = Instance.new("Weld", heavyfx)
			weld.Part0 = heavyfx
			weld.Part1 = hrp
			wait(.05)
			game.Debris:AddItem(heavyfx, 5)
			for _, v in heavyfx:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Emit(2)
				end
			end

			-- Windup with stun cancel check (same as heavy)
			local windupTime = 0.2
			local elapsed = 0
			local interrupt = false
			while elapsed < windupTime do
				if c:FindFirstChild("Stun") then
					interrupt = true
					break
				end
				task.wait(0.05)
				elapsed = elapsed + 0.05
			end
			windupTrack:Stop()
			windupAnim:Destroy()

			if interrupt then
				p.Character:SetAttribute("SwordSlowed", false)
				if endlag then endlag:Destroy() end
				state.combo = 1
				playerCombatState[p] = state
				return
			end

			-- Kick animation
			local kickAnim = Instance.new("Animation")
			kickAnim.AnimationId = "rbxassetid://118361413889169" -- Replace with your kick anim id!
			local kickTrack = hum:LoadAnimation(kickAnim)
			kickTrack:Play()

			-- Optional: Play a kick sound
			local kicksound = game.ReplicatedStorage.Sounds.Weapons.Kick and game.ReplicatedStorage.Sounds.Weapons.Kick:Clone()
			if kicksound then
				kicksound.Parent = hrp
				kicksound:Play()
				game.Debris:AddItem(kicksound, 2)
			end

			-- Wait for kick to be "active" (adjust timing for your anim, here we use 0.15s as example)
			task.wait(.05)

			-- Spawn the hitbox (5,5,5) in front of character
			-- Spawn the hitbox (5,5,5) in front of character
			local kickbox = Instance.new("Part")
			kickbox.Size = Vector3.new(5, 5, 5)
			kickbox.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
			kickbox.Anchored = true
			kickbox.CanCollide = false
			kickbox.Transparency = 1
			kickbox.Parent = workspace.Fx
			kickbox.Name = "KickHitbox"
			kickbox.Material = Enum.Material.ForceField
			game.Debris:AddItem(kickbox, 0.12) -- just like your other hitboxes

			-- Instantly get overlap parts (NO need for waits or heartbeats)
			local overlaps = workspace:GetPartsInPart(kickbox)
			local hits = {}
			for _, part in ipairs(overlaps) do
				local char = part.Parent
				if char and char:IsA("Model") and char ~= c and char:FindFirstChildWhichIsA("Humanoid") and char.Parent.Name ~= "NPCS" then
					if not table.find(hits, char) then
						table.insert(hits, char)
					end
				end
			end
			print("Kick hits:", hits)


			-- Send hit data to hit handler (reuse your hit logic)
			handleCombatRemote(p, {
				action = "hit",
				hb = hits,
				hit = "rbxassetid://106066883606093",
				parry = "rbxassetid://75949832039549",
				combo = 5,
				isKick = true, -- <<<< ADD THIS
			})


			-- Endlag and SwordSlowed OFF after kick duration (adjust to match animation, e.g. 1s)
			task.delay(0.7, function()
				if p.Character then
					p.Character:SetAttribute("SwordSlowed", false)
					if endlag then endlag:Destroy() end
				end
			end)

			-- Reset combo (already at top)
			state.combo = 1
			playerCombatState[p] = state

			return
		end


		-- Set default animations for heavy if not provided
		data.hit = data.hit or 'rbxassetid://106066883606093'
		data.parry = data.parry or 'rbxassetid://75949832039549'

		local now = tick()
		local heavyCD = 2




		local weaponName = tostring(p.Character:FindFirstChild("CurrentWeapon") and p.Character.CurrentWeapon.Value or "")
		local weaponData = weaponmodule[weaponName] or {}
		local atkSpeed = weaponData.AtkSpeed or 0.2

		local lastAttack = (playerCombatState[p] and playerCombatState[p].lastAttack) or 0
		local lastHeavy = heavyAttackCooldowns[p] or 0

		local sound1 = game.ReplicatedStorage.Sounds.M2:Clone()
		local sound2 = game.ReplicatedStorage.Sounds.HeavyDash:Clone()
		local sound3 = game.ReplicatedStorage.Sounds.Weapons.Heavy:Clone()



		if now - lastAttack < atkSpeed then

			remote:FireClient(p, {action = "HeavyFail", reason = "m1_cooldown"})
			return
		end

		if now - lastHeavy < heavyCD then

			remote:FireClient(p, {action = "HeavyFail", reason = "cooldown"})
			return
		end

		heavyAttackCooldowns[p] = now


		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not hrp then print("[DEBUG] No HRP!"); return end

		p.Character:SetAttribute("SwordSlowed", true)
		local endlag = Instance.new("BoolValue", p.Character)
		endlag.Name='Endlag'

		-- Play windup animation
		local hum = c:FindFirstChildOfClass("Humanoid")
		local windupAnim = Instance.new("Animation")
		windupAnim.AnimationId = "rbxassetid://135575375450810"
		local windupTrack = hum:LoadAnimation(windupAnim)
		windupTrack:Play()


		sound1.Parent=hrp
		sound1:Play()
		game.Debris:AddItem(sound1,5)

		local heavyfx = game.ReplicatedFirst.Combat.Sword.Fx.M2:Clone()
		heavyfx.Parent = workspace.Fx
		heavyfx.CFrame = hrp.CFrame
		local weld = Instance.new("Weld", heavyfx)
		weld.Part0 = heavyfx
		weld.Part1 = hrp
		local slashfx = game.ReplicatedFirst.Combat.Sword.Fx.HeavySlashReal:Clone()
		wait(.05)
		game.Debris:AddItem(heavyfx,5)
		for _,v in heavyfx:GetDescendants() do
			if v:IsA("ParticleEmitter") then


				v:Emit(2)
			end
		end

		-- Windup time in seconds
		local windupTime = 0.3
		local elapsed = 0
		local interrupt = false

		while elapsed < windupTime do
			if c:FindFirstChild("Stun") then
				interrupt = true
				break
			end
			task.wait(0.05)
			elapsed = elapsed + 0.05
		end

		windupTrack:Stop()
		windupAnim:Destroy()

		if interrupt then
			-- Optionally notify the client if you want to play a cancel animation/sound
			p.Character:SetAttribute("SwordSlowed", false)
			endlag:Destroy()
			return -- Stop heavy attack, don't do dash/hitbox/damage
		end

		windupTrack:Stop()
		windupAnim:Destroy()

		local dashAnim = Instance.new("Animation")
		dashAnim.AnimationId = "rbxassetid://96799853488151"
		local dashTrack = hum:LoadAnimation(dashAnim)
		dashTrack:Play()

		local dasheff = game.ReplicatedFirst.Combat.Sword.Fx.Dash:Clone()
		dasheff.Parent=workspace.Fx
		dasheff.CFrame=hrp.CFrame*CFrame.new(0,0,-5)
		dasheff.Anchored=true
		coroutine.resume(coroutine.create(function()
			wait(.05)
			sound2.Parent=hrp
			sound2:Play()
			game.Debris:AddItem(sound2,5)
			game.Debris:AddItem(dasheff,5)
			for _,v in dasheff:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Emit()
				end
			end
		end))

		-- Dash setup
		local dashDistance = 10
		local dashDuration = 0.35
		local lookVector = hrp.CFrame.LookVector
		local dashStart = hrp.Position
		local dashEnd = dashStart + (lookVector * dashDistance)

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {c, workspace.Fx}
		local rayResult = workspace:Raycast(dashStart, lookVector * dashDistance, rayParams)
		if rayResult then

			dashEnd = rayResult.Position - (lookVector * 2)
		end

		local endCFrame = CFrame.new(dashEnd, dashEnd + hrp.CFrame.LookVector)
		local dashTween = t:Create(hrp, TweenInfo.new(dashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = endCFrame})

		local alreadyHit = {}

		coroutine.resume(coroutine.create(function()

			wait(0.15)
			sound3.Parent=hrp
			sound3:Play()
			game.Debris:AddItem(sound3,5)
			slashfx.Parent = workspace.Fx
			game.Debris:AddItem(slashfx,5)
			slashfx.CFrame = hrp.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, 0, math.rad(35))
			slashfx.Slash1Sparks.CFrame=hrp.CFrame * CFrame.new(0, 0, -8) * CFrame.Angles(0, 0, math.rad(35))
			slashfx.Anchored=true
			slashfx.Slash1Sparks.Anchored=true
			wait(.05)
			for _, v in ipairs(slashfx:GetDescendants()) do
				if v:IsA("ParticleEmitter") then

					v:Emit()
				end
			end
		end))

		-- === HITBOX 1: At start ===
		local dashVec = dashEnd - dashStart
		local dashLen = dashVec.Magnitude
		local dashDir = dashVec.Unit

		-- Box 1: from player to half + 1 stud
		local box1Len = (dashLen / 2) + 1
		local box1Start = dashStart + (dashDir * 2.5) -- 2.5 = half of box width (5) to start right in front
		local box1Center = box1Start + (dashDir * (box1Len / 2))
		local box1 = Instance.new("Part")
		box1.Parent = workspace.Fx
		box1.Anchored = true
		box1.CanCollide = false
		box1.Transparency = 1
		box1.Name = "HeavyBox1"
		box1.Material = Enum.Material.ForceField
		box1.Size = Vector3.new(5, 7, box1Len)
		box1.CFrame = CFrame.new(box1Center, box1Center + dashDir)
		game.Debris:AddItem(box1,.1)

		task.wait()

		local overlaps1 = workspace:GetPartsInPart(box1)
		for _, part in ipairs(overlaps1) do
			local char = part.Parent
			if char and char:IsA("Model") and char ~= c and char:FindFirstChildWhichIsA("Humanoid") and char.Parent.Name ~= "NPCS" then
				alreadyHit[char] = true

			end
		end

		dashTween:Play()

		-- Box 2: from end of Box1 to dashEnd + 2 studs
		task.wait(dashDuration / 2)

		local box2Len = (dashLen / 2)
		local box2Start = box1Start + (dashDir * box1Len)
		local box2Center = box2Start + (dashDir * (box2Len / 2))
		local box2 = Instance.new("Part")
		box2.Parent = workspace.Fx
		box2.Anchored = true
		box2.CanCollide = false
		box2.Transparency = 1
		box2.Name = "HeavyBox2"
		box2.Material = Enum.Material.ForceField
		box2.Size = Vector3.new(5, 7, box2Len)
		box2.CFrame = CFrame.new(box2Center, box2Center + dashDir)
		game.Debris:AddItem(box2,.1)

		task.wait()

		local overlaps2 = workspace:GetPartsInPart(box2)
		for _, part in ipairs(overlaps2) do
			local char = part.Parent
			if char and char:IsA("Model") and char ~= c and char:FindFirstChildWhichIsA("Humanoid") and char.Parent.Name ~= "NPCS" then
				alreadyHit[char] = true

			end
		end

		task.wait(dashDuration / 2)

		for char, _ in pairs(alreadyHit) do

		end





		task.delay(0.5, function()
			if p.Character then
				p.Character:SetAttribute("SwordSlowed", false)
				endlag:Destroy()
			end
		end)

		local heavyHits = {}
		for char, _ in pairs(alreadyHit) do
			table.insert(heavyHits, char)
		end

		handleCombatRemote(p, {
			action = "hit",
			hb = heavyHits,
			hit = data.hit,
			parry = data.parry,
			combo = 5,
		})

		remote:FireAllClients({
			action = "Heavy",
			attacker = p.Name,
			hb = heavyHits
		})

		return
	end

	-- ========== HIT LOGIC ==========
	if data.action == "hit" then
		handleHit(p, data)
		return
	end

	-- [Any other mechanics: unchanged]
end
remote.OnServerEvent:Connect(handleCombatRemote)


-- Debounce table for FX
local fxDebounces = {}  -- fxDebounces[player][fxName] = lastTimeFired

local function canFireFX(player, fxName, debounceTime)
	fxDebounces[player] = fxDebounces[player] or {}
	local last = fxDebounces[player][fxName] or 0
	local now = tick()
	if now - last < (debounceTime or 0.3) then  -- 0.3s debounce (adjust as needed)
		return false
	end
	fxDebounces[player][fxName] = now
	return true
end

-- Clean up on leave:
game.Players.PlayerRemoving:Connect(function(player)
	fxDebounces[player] = nil
end)



fxremote.OnServerEvent:Connect(function(p,data,v)
	
	if type(data) ~= "string" then return end
	local fxName = data

	-- List the effects that need debounce
	local debounceFX = {
		["PBFX"] = 0.25,
		["ClashFX"] = 0.25,
		["BlockFX"] = 0.25,
		["HitFX"] = 0.15,
		["KickVFX"] = 0.2,
	}
	local debounceTime = debounceFX[fxName]
	if debounceTime then
		if not canFireFX(p, fxName, debounceTime) then
			-- Optionally print/debug here
			return
		end
	end
	
	
	if data=='PBFX' then

		local fx = game.ReplicatedFirst.Combat.Sword.Fx["Perfect Block"]:Clone()
		fx.Anchored=false
		local weld = Instance.new("Weld", fx)
		weld.Part0=v:FindFirstChild("HumanoidRootPart")
		weld.Part1=fx
		fx.Parent=v:FindFirstChild("HumanoidRootPart")
		fx.Position = v:FindFirstChild("HumanoidRootPart").Position + Vector3.new(0,0,-1)

		for _,d in fx:FindFirstChildWhichIsA("Attachment"):GetChildren() do
			d:Emit(1)
		end
		local attachment = fx:FindFirstChildWhichIsA("Attachment")
		if attachment then
			for _, particle in attachment:GetChildren() do
				if particle:IsA("ParticleEmitter") then
					local transparencyTween = t:Create(
						particle, 
						TweenInfo.new(1), 
						{Rate = 0} -- Slowly reducing emission rate to make it fade
					)
					transparencyTween:Play()

					-- Manually interpolate Transparency over time
					task.spawn(function()
						local duration = 1
						local startTime = tick()

						while tick() - startTime < duration do
							local alpha = (tick() - startTime) / duration
							particle.Transparency = NumberSequence.new(alpha) -- Fading effect
							task.wait()
						end

						particle.Transparency = NumberSequence.new(1) -- Fully faded out
					end)
				end
			end
		end
		game.Debris:AddItem(fx, 1)
	elseif data == "ClashFX" then
		local fx = game.ReplicatedFirst.Combat.Sword.Fx["Clash Effect"]:Clone()
		fx.Anchored=false
		local weld = Instance.new("Weld", fx)
		weld.Part0=v:FindFirstChild("HumanoidRootPart")
		weld.Part1=fx
		fx.Parent=v:FindFirstChild("HumanoidRootPart")
		fx.Position = v:FindFirstChild("HumanoidRootPart").Position + Vector3.new(0,0,-1)

		for _,d in fx:FindFirstChildWhichIsA("Attachment"):GetChildren() do
			d:Emit(1)
		end
		local attachment = fx:FindFirstChildWhichIsA("Attachment")
		if attachment then
			for _, particle in attachment:GetChildren() do
				if particle:IsA("ParticleEmitter") then
					local transparencyTween = t:Create(
						particle, 
						TweenInfo.new(1), 
						{Rate = 0} -- Slowly reducing emission rate to make it fade
					)
					transparencyTween:Play()

					-- Manually interpolate Transparency over time
					task.spawn(function()
						local duration = 1
						local startTime = tick()

						while tick() - startTime < duration do
							local alpha = (tick() - startTime) / duration
							particle.Transparency = NumberSequence.new(alpha) -- Fading effect
							task.wait()
						end

						particle.Transparency = NumberSequence.new(1) -- Fully faded out
					end)
				end
			end
		end
		game.Debris:AddItem(fx, 1)

	elseif data == "BlockFX" then
		local fx = game.ReplicatedFirst.Combat.Sword.Fx["Block"]:Clone()
		fx.Anchored=false
		local weld = Instance.new("Weld", fx)
		weld.Part0=v:FindFirstChild("HumanoidRootPart")
		weld.Part1=fx
		fx.Parent=v:FindFirstChild("HumanoidRootPart")
		fx.Position = v:FindFirstChild("HumanoidRootPart").Position + Vector3.new(0,0,-1)

		task.wait(.05)

		for _,d in fx:FindFirstChildWhichIsA("Attachment"):GetChildren() do
			d:Emit(1)
		end
		local attachment = fx:FindFirstChildWhichIsA("Attachment")
		if attachment then
			for _, particle in attachment:GetChildren() do
				if particle:IsA("ParticleEmitter") then
					local transparencyTween = t:Create(
						particle, 
						TweenInfo.new(1), 
						{Rate = 0} -- Slowly reducing emission rate to make it fade
					)
					transparencyTween:Play()

					-- Manually interpolate Transparency over time
					task.spawn(function()
						local duration = 1
						local startTime = tick()

						while tick() - startTime < duration do
							local alpha = (tick() - startTime) / duration
							particle.Transparency = NumberSequence.new(alpha) -- Fading effect
							task.wait()
						end

						particle.Transparency = NumberSequence.new(1) -- Fully faded out
					end)
				end
			end
		end
		game.Debris:AddItem(fx,1)
	elseif data == "HitFX" then
		local hrp = v:FindFirstChild("HumanoidRootPart")
		if not hrp then return end -- enemy is probably dead or missing parts

		local fx = game.ReplicatedFirst.Combat.Sword.Fx["Hit"]:Clone()
		fx.Anchored = false

		local weld = Instance.new("Weld")
		weld.Part0 = hrp
		weld.Part1 = fx
		weld.Parent = fx

		fx.Parent = hrp

		-- Small delay to allow replication
		task.wait(0.05)

		local attachment = fx:FindFirstChildWhichIsA("Attachment")
		if attachment then
			for _, d in attachment:GetChildren() do
				if d:IsA("ParticleEmitter") then
					d:Emit(2)
				end
			end
		end

		game.Debris:AddItem(fx, 1.6)
	elseif data=='KickVFX' then
		local hrp = v:FindFirstChild("HumanoidRootPart")
		if not hrp then return end -- enemy is probably dead or missing parts

		local fx = game.ReplicatedFirst.Combat.Sword.Fx["Kick Effect"]:Clone()
		fx.Anchored = false

		local weld = Instance.new("Weld")
		weld.Part0 = hrp
		weld.Part1 = fx
		weld.Parent = fx

		fx.Parent = hrp

		-- Small delay to allow replication
		task.wait(0.05)

		local attachment = fx:FindFirstChildWhichIsA("Attachment")
		if attachment then
			for _, d in attachment:GetChildren() do
				if d:IsA("ParticleEmitter") then
					d:Emit(2)
				end
			end
		end

		game.Debris:AddItem(fx, 1.6)		

	end

end)

