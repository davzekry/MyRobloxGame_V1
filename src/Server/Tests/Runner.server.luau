--!strict
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local SPEC_SUFFIX = ".spec"

local passed = 0
local failed = 0

local function fail(name: string, message: unknown)
	failed += 1
	warn(`FAIL {name}: {message}`)
end

for _, child in (script.Parent :: Instance):GetChildren() do
	if not child:IsA("ModuleScript") or child.Name:sub(-#SPEC_SUFFIX) ~= SPEC_SUFFIX then
		continue
	end

	local loaded, tests = pcall((require :: any), child)
	if not loaded then
		fail(child.Name, tests)
		continue
	end

	for testName, test in tests do
		local ok, message = pcall(test)
		if ok then
			passed += 1
		else
			fail(`{child.Name} > {testName}`, message)
		end
	end
end

print(`Tests: {passed} passed, {failed} failed`)
