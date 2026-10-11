--!strict
-- Deterministic PRNG for statistical tests (xorshift32), so failures reproduce.

local Rng = {}

function Rng.new(seed: number): () -> number
	local state = bit32.bor(seed, 1)
	return function(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296
	end
end

return Rng
