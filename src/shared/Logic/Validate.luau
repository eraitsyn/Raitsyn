--!strict
-- Shape checks for anything that arrives from a client. Every remote handler
-- runs its arguments through these before touching game state.

local Validate = {}

function Validate.string(value: unknown, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

-- Identifier-like strings only: letters, digits and underscores.
function Validate.id(value: unknown, maxLength: number?): boolean
	if not Validate.string(value, maxLength or 64) then
		return false
	end
	return string.match(value :: string, "^[%w_]+$") ~= nil
end

-- A finite integer within [min, max]. Rejects NaN, infinities and fractions.
function Validate.integer(value: unknown, min: number, max: number): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	if n ~= n or n == math.huge or n == -math.huge then
		return false
	end
	return math.floor(n) == n and n >= min and n <= max
end

function Validate.boolean(value: unknown): boolean
	return type(value) == "boolean"
end

-- An array of ids with no duplicates and at most `maxCount` entries.
function Validate.idList(value: unknown, maxCount: number): boolean
	if type(value) ~= "table" then
		return false
	end
	local list = value :: { [unknown]: unknown }
	local count = 0
	local seen = {}
	for key, item in list do
		count += 1
		if count > maxCount or type(key) ~= "number" or not Validate.id(item) or seen[item] then
			return false
		end
		seen[item] = true
	end
	return count == #(list :: { unknown }) and count > 0
end

-- Membership in a config table such as RollTiers.byId.
function Validate.oneOf(value: unknown, lookup: { [string]: any }): boolean
	return type(value) == "string" and lookup[value :: string] ~= nil
end

return Validate
