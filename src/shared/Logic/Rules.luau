--!strict
-- Time- and milestone-based rules: roll tier unlocks, daily rewards and
-- offline earnings. All times are server os.time() seconds; the client only
-- uses these to display countdowns.

local Config = script.Parent.Parent.Config
local Daily = require(Config.Daily)
local RollTiers = require(Config.RollTiers)

local Rules = {}

function Rules.tierUnlocked(tierId: string, lifetimeCoins: number, rebirths: number): boolean
	local tier = RollTiers.byId[tierId]
	if tier == nil then
		return false
	end
	return lifetimeCoins >= tier.unlockLifetimeCoins and rebirths >= tier.unlockRebirths
end

export type DailyState = {
	canClaim: boolean,
	secondsUntilClaim: number,
	nextDay: number, -- the streak day (1..7) the next claim pays
}

-- `streak` is the last claimed day (0 = never), `lastClaim` its os.time().
function Rules.daily(streak: number, lastClaim: number, now: number): DailyState
	local cooldown = Daily.claimCooldownHours * 3600
	local reset = Daily.streakResetHours * 3600
	if lastClaim <= 0 then
		return { canClaim = true, secondsUntilClaim = 0, nextDay = 1 }
	end
	local elapsed = now - lastClaim
	if elapsed < 0 then
		-- Server clocks disagree (or data came from the future): wait it out.
		return { canClaim = false, secondsUntilClaim = cooldown, nextDay = (streak % #Daily.rewards) + 1 }
	end
	if elapsed < cooldown then
		return { canClaim = false, secondsUntilClaim = cooldown - elapsed, nextDay = (streak % #Daily.rewards) + 1 }
	end
	if elapsed >= reset then
		return { canClaim = true, secondsUntilClaim = 0, nextDay = 1 }
	end
	return { canClaim = true, secondsUntilClaim = 0, nextDay = (streak % #Daily.rewards) + 1 }
end

-- Coins paid by a daily reward day, given the player's current income per second.
function Rules.dailyCoins(day: number, incomePerSecond: number): number
	local reward = Daily.rewards[day]
	if reward == nil or reward.incomeMinutes == nil then
		return 0
	end
	local fromIncome = math.max(0, incomePerSecond) * 60 * reward.incomeMinutes
	return math.floor(math.max(fromIncome, reward.minimumCoins or 0))
end

-- Offline payout from the rate saved at logout. Elapsed time is clamped to
-- [0, cap] so clock changes can never pay more than the cap.
function Rules.offlineEarnings(
	incomeAtLogout: number,
	offlineRate: number,
	capHours: number,
	logoutTime: number,
	now: number
): (number, number)
	if logoutTime <= 0 or offlineRate <= 0 or incomeAtLogout <= 0 then
		return 0, 0
	end
	local seconds = math.clamp(now - logoutTime, 0, capHours * 3600)
	return math.floor(incomeAtLogout * offlineRate * seconds), seconds
end

return Rules
