-- Minimal test helpers for Lune. Each spec returns a table of name -> function.

local TestKit = {}

function TestKit.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function TestKit.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function TestKit.falsy(value: any, message: string?)
	if value then
		error(message or "expected a falsy value", 2)
	end
end

return TestKit
