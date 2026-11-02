--!strict
-- Pure checks for raw client values. Everything a client sends is untrusted.

local MAX_ITEM_ID_LENGTH = 64
local MAX_LOGGED_ID_LENGTH = 40

local RequestRules = {}

-- Pass select("#", ...) as count, because # stops at a nil and would miss trailing nils.
function RequestRules.hasExactArgs(count: number, expected: number): boolean
	return count == expected
end

function RequestRules.isItemId(value: unknown): boolean
	return typeof(value) == "string" and #value > 0 and #value <= MAX_ITEM_ID_LENGTH
end

function RequestRules.logSafeItemId(value: unknown): string?
	if typeof(value) ~= "string" then
		return nil
	end
	return string.sub(value, 1, MAX_LOGGED_ID_LENGTH)
end

return RequestRules
