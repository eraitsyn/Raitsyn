--[[
	Validate: strict checks for values that arrive from clients.

	Every check is a function (value) -> boolean. Validate.Args runs a list of
	checks against a remote's arguments and fails on any extra or missing one.
	This module has no Roblox dependencies so it can be unit tested outside Studio.
]]

local Validate = {}

export type Check = (value: any) -> boolean

-- A non-empty, valid UTF-8 string of at most maxLength bytes.
function Validate.String(maxLength: number): Check
	return function(value)
		return type(value) == "string" and #value > 0 and #value <= maxLength and utf8.len(value) ~= nil
	end
end

-- A whole number between min and max inclusive. Rejects NaN and infinities.
function Validate.Integer(min: number, max: number): Check
	return function(value)
		return type(value) == "number"
			and value == value
			and value ~= math.huge
			and value ~= -math.huge
			and value % 1 == 0
			and value >= min
			and value <= max
	end
end

-- One of a fixed set of strings.
function Validate.OneOf(options: { string }): Check
	local allowed = {}
	for _, option in options do
		allowed[option] = true
	end
	return function(value)
		return type(value) == "string" and allowed[value] == true
	end
end

-- True when exactly #checks arguments were passed and each passes its check.
function Validate.Args(checks: { Check }, ...: any): boolean
	if select("#", ...) ~= #checks then
		return false
	end
	for index, check in checks do
		if not check((select(index, ...))) then
			return false
		end
	end
	return true
end

return Validate
