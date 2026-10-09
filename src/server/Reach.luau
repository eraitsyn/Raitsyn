-- Reach: server-side distance checks for anything a player triggers in the world.

local Reach = {}

-- The player's HumanoidRootPart if their character is alive, else nil.
function Reach.Root(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Reach.Within(player: Player, position: Vector3, distance: number): boolean
	local root = Reach.Root(player)
	return root ~= nil and (root.Position - position).Magnitude <= distance
end

return Reach
