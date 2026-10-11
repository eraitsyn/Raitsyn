--!strict
-- Player-facing number and time formatting, used everywhere so the same value
-- always reads the same way (HUD, pet labels, prices, hex tiles).

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

-- 999 -> "999", 1234 -> "1.23K", 45_600_000 -> "45.6M".
-- Always three significant digits above 1,000 and never rounds up past a
-- boundary into the wrong suffix (999,999 -> "999K", not "1000K").
function Format.number(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	local n = math.abs(value)
	local text: string
	if n < 1000 then
		text = tostring(math.floor(n))
	else
		local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
		local scaled = n / 1000 ^ tier
		-- Truncate (not round) to 3 significant digits so we never show 1000K.
		local digits = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
		local factor = 10 ^ digits
		scaled = math.floor(scaled * factor) / factor
		text = string.format(`%.{digits}f`, scaled)
		if digits > 0 then
			text = string.gsub(text, "%.?0+$", "")
		end
		text ..= SUFFIXES[tier + 1]
	end
	return if negative then "-" .. text else text
end

function Format.coins(value: number): string
	return "$" .. Format.number(value)
end

function Format.rate(perSecond: number): string
	return "$" .. Format.number(perSecond) .. "/s"
end

-- 0.0123 -> "1.23%", 0.00001 -> "0.001%". Small chances keep enough digits.
function Format.percent(chance: number): string
	local pct = chance * 100
	if pct >= 10 then
		return (string.gsub(string.format("%.1f%%", pct), "%.0%%", "%%"))
	elseif pct >= 1 then
		return (string.gsub(string.format("%.2f", pct), "%.?0+$", "")) .. "%"
	end
	local text = string.format("%.3g", pct)
	if string.find(text, "e") then
		text = string.format("%.6f", pct)
		text = string.gsub(text, "0+$", "")
	end
	return text .. "%"
end

-- 3725 -> "1h 2m", 95 -> "1m 35s", 4.2 -> "4.2s".
function Format.duration(seconds: number): string
	if seconds < 10 then
		return (string.gsub(string.format("%.1f", math.max(0, seconds)), "%.0$", "")) .. "s"
	end
	local s = math.floor(seconds)
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return `{h}h {m}m`
	elseif m > 0 then
		return `{m}m {sec}s`
	end
	return `{sec}s`
end

-- 1234567 -> "1,234,567" for exact displays like odds ("1 in 100,000").
function Format.commas(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if result:sub(1, 1) == "," then
		result = result:sub(2)
	end
	return if value < 0 then "-" .. result else result
end

return Format
