-- Runs every *.spec.luau in this folder: `lune run tests/run`

local fs = require("@lune/fs")
local process = require("@lune/process")

local specs = {
	"ButtonGraph",
	"DataSchema",
	"RateLimiter",
	"Validate",
}

local passed, failed = 0, 0
for _, name in specs do
	local cases = require(`./{name}.spec`)
	local names = {}
	for caseName in cases do
		table.insert(names, caseName)
	end
	table.sort(names)
	for _, caseName in names do
		local ok, err = pcall(cases[caseName])
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {name}: {caseName}\n  {err}`)
		end
	end
end

-- Catch specs added to the folder but not to the list above.
for _, file in fs.readDir("tests") do
	local name = string.match(file, "^(.+)%.spec%.luau$")
	if name and not table.find(specs, name) then
		failed += 1
		print(`FAIL {file} is not listed in tests/run.luau`)
	end
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed == 0 then 0 else 1)
