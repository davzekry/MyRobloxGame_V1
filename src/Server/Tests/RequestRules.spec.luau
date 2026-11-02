--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local RequestRules = require(ServerScriptService.Rules.RequestRules)

return {
	["exact argument count passes"] = function()
		assert(RequestRules.hasExactArgs(1, 1), "1 of 1 should pass")
	end,

	["extra argument fails"] = function()
		assert(not RequestRules.hasExactArgs(2, 1), "2 of 1 should fail")
	end,

	["missing argument fails"] = function()
		assert(not RequestRules.hasExactArgs(0, 1), "0 of 1 should fail")
	end,

	["explicit nil counts as an extra argument"] = function()
		local count = select("#", "crate_hat", nil)
		assert(not RequestRules.hasExactArgs(count, 1), "a trailing nil should fail")
	end,

	["number is not an item id"] = function()
		assert(not RequestRules.isItemId(12345), "number should fail")
	end,

	["empty string is not an item id"] = function()
		assert(not RequestRules.isItemId(""), "empty string should fail")
	end,

	["string over 64 characters is not an item id"] = function()
		assert(not RequestRules.isItemId(string.rep("a", 65)), "65 characters should fail")
	end,

	["valid id passes"] = function()
		assert(RequestRules.isItemId("crate_hat"), "crate_hat should pass")
	end,

	["log id is cut to 40 characters"] = function()
		local logged = RequestRules.logSafeItemId(string.rep("a", 100))
		assert(logged and #logged == 40, "long id should be 40 characters")
	end,

	["log id is nil for a non-string"] = function()
		assert(RequestRules.logSafeItemId(12345) == nil, "number should be nil")
	end,
}
