--[[
	Format: short number text for signs and the HUD ("$1.25K", "$3.4M").
	No Roblox dependencies, so it is unit tested outside Studio.
]]

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn" }

local Format = {}

-- 999 -> "999", 1250 -> "1.25K", 3400000 -> "3.4M". Whole numbers under 1000 stay exact.
function Format.Short(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	local tier = 1
	while value >= 1000 and tier < #SUFFIXES do
		value /= 1000
		tier += 1
	end
	-- Two decimals, then trim trailing zeros ("1.50" -> "1.5", "2.00" -> "2").
	local rounded = math.floor(value * 100 + 1e-6) / 100
	local text = string.format("%.2f", rounded)
	text = string.gsub(text, "%.?0+$", "")
	return sign .. text .. SUFFIXES[tier]
end

function Format.Cash(value: number): string
	return "$" .. Format.Short(value)
end

return Format
