-- Read-only: reports every synced script to tools/audit_studio.py.
local HttpService = game:GetService("HttpService")

local ROOTS = {
	game:GetService("ServerScriptService"),
	game:GetService("ReplicatedStorage"),
	game:GetService("StarterPlayer"),
}

local items = {}
for _, root in ROOTS do
	for _, item in root:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			table.insert(items, { path = item:GetFullName(), chars = #item.Source })
		end
	end
end

HttpService:RequestAsync({
	Url = "http://localhost:8765/audit",
	Method = "POST",
	Headers = { ["Content-Type"] = "application/json" },
	Body = HttpService:JSONEncode(items),
})
