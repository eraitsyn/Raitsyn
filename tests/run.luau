--!strict
-- Runs every spec under tests/specs. Usage (from the repo root): lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")
local Test = require("./lib/Test")

local files = fs.readDir("tests/specs")
table.sort(files)
for _, file in files do
	if string.match(file, "%.spec%.luau$") then
		local name = string.gsub(file, "%.luau$", "")
		require(`./specs/{name}`)
	end
end

process.exit(if Test.run() then 0 else 1)
