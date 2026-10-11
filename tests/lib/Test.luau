--!strict
-- Minimal test runner: describe / it / expect, with a summary and a non-zero
-- exit code on failure so CI fails.

local Test = {}

type Case = { name: string, fn: () -> () }
type Suite = { name: string, cases: { Case } }

local suites: { Suite } = {}
local current: Suite? = nil

function Test.describe(name: string, body: () -> ())
	local suite = { name = name, cases = {} }
	table.insert(suites, suite)
	local previous = current
	current = suite
	body()
	current = previous
end

function Test.it(name: string, fn: () -> ())
	assert(current, "it() must be inside describe()")
	table.insert(current.cases, { name = name, fn = fn })
end

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Test.expect(actual: any)
	local api = {}
	function api.toBe(expected: any)
		if actual ~= expected then
			error(`expected {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function api.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			error(`expected deep equality with {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function api.toBeNear(expected: number, tolerance: number)
		if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
			error(`expected {expected} ± {tolerance}, got {show(actual)}`, 2)
		end
	end
	function api.toBeTruthy()
		if not actual then
			error(`expected a truthy value, got {show(actual)}`, 2)
		end
	end
	function api.toBeFalsy()
		if actual then
			error(`expected a falsy value, got {show(actual)}`, 2)
		end
	end
	function api.toBeGreaterThan(n: number)
		if type(actual) ~= "number" or not (actual > n) then
			error(`expected > {n}, got {show(actual)}`, 2)
		end
	end
	function api.toBeLessThan(n: number)
		if type(actual) ~= "number" or not (actual < n) then
			error(`expected < {n}, got {show(actual)}`, 2)
		end
	end
	function api.toThrow()
		local ok = pcall(actual)
		if ok then
			error("expected function to throw", 2)
		end
	end
	return api
end

function Test.run(): boolean
	local passed, failed = 0, 0
	for _, suite in suites do
		print(`\n{suite.name}`)
		for _, case in suite.cases do
			local ok, err = pcall(case.fn)
			if ok then
				passed += 1
				print(`  ok    {case.name}`)
			else
				failed += 1
				print(`  FAIL  {case.name}\n        {err}`)
			end
		end
	end
	print(`\n{passed} passed, {failed} failed`)
	return failed == 0
end

return Test
