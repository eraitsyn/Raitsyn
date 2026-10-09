-- Tunable numbers. All are starting defaults to adjust in play.

return {
	MaxCash = 2 ^ 53, -- largest whole number a double holds exactly
	SlotsPerBase = 8,
	SellRefund = 0.5, -- share of the price returned when selling a god

	-- Conveyor
	LaneSpawnInterval = 2.5, -- seconds between new gods
	LaneSpeed = 6, -- studs per second
	MaxGodsOnLane = 16,

	-- Prompts
	PromptDistance = 10, -- studs, ProximityPrompt.MaxActivationDistance
	ReachDistance = 14, -- studs, server backstop for every prompt

	-- Stealing
	StealHoldDuration = 2, -- seconds the thief must hold the prompt
	StealTimeout = 60, -- seconds to get home before the god returns
	CarryWalkSpeed = 12, -- thief's WalkSpeed while carrying
	MaxCarrySpeed = 20, -- studs per second; arriving faster than this cancels the steal

	-- Base lock
	LockDuration = 30,
	LockCooldown = 90, -- measured from when the lock started
}
