-- Damager.lua (Server, modular, fully wired)
local module = {}

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules

-- State modules
local Light = require(script.Light)
local Heavy = require(script.Heavy)
local Kick = require(script.Kick)
local Blocking = require(script.Blocking)

-- FX modules (if you want to trigger from here for universal effects, otherwise call in state)
local GuardbreakFX = require(script.Parent.FX.Guardbreak)

-- Utility
local Global = require(Modules.Global)

-- Route Light Attack
function module.HandleLightAttack(player, char, data)
	if Global.CheckStates(char, {"Stun", "GB", "PBSTUN", "Skill", "MovementSkill", "CantDoAnything", "Endlag"}) then return end

	local hitList = data.hb or {}
	local combo = data.combo or 1

	for _, target in ipairs(hitList) do
		if target and target ~= char then
			if target:FindFirstChild("Block") and target.Block.Value == true then
				-- Guardbreak on 5th hit
				if combo == 5 then
					GuardbreakFX.PlayGuardbreakFX(target)
				end
				Blocking.ATK(char, target, combo, 0, 0)
			else
				Light.ATK(char, target, combo, 0)
			end
		end
	end
end

-- Route Heavy Attack (includes kick logic)
function module.HandleHeavyAttack(player, char, data)
	if Global.CheckStates(char, {"Stun", "GB", "PBSTUN", "Skill", "MovementSkill", "CantDoAnything", "Endlag"}) then return end

	local hitList = data.hb or {}
	local combo = data.combo or 5

	for _, target in ipairs(hitList) do
		if target and target ~= char then
			-- If heavy attack at combo 5 = KICK
			if combo == 5 then
				Kick.ATK(char, target, combo, 0)
			elseif target:FindFirstChild("Block") and target.Block.Value == true then
				-- Guardbreak for heavy on block
				GuardbreakFX.PlayGuardbreakFX(target)
				Blocking.ATK(char, target, combo, 0, 0)
			else
				Heavy.ATK(char, target, combo, 0)
			end
		end
	end
end

-- Route Block
function module.HandleBlock(player, char, data)
	if char:FindFirstChild("Block") then
		char.Block.Value = true
	else
		local block = Instance.new("BoolValue")
		block.Name = "Block"
		block.Value = true
		block.Parent = char
	end
	char:SetAttribute("Blocking", true)
end

function module.HandleUnblock(player, char, data)
	if char:FindFirstChild("Block") then
		char.Block.Value = false
	end
	char:SetAttribute("Blocking", false)
end

return module
