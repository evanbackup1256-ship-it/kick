-- Alleral_Diagnostics
local Diagnostics = { VERSION = "1.0.0" }
Diagnostics.Metrics = { startup = {}, errors = {}, modules = {} }

function Diagnostics.track(name, fn)
	local start = tick()
	local ok, result = pcall(fn)
	local elapsed = tick() - start
	table.insert(Diagnostics.Metrics.startup, { name = name, ok = ok, elapsed = elapsed, at = os.date("%H:%M:%S") })
	if not ok then
		warn("[Diagnostics] " .. name .. " failed in " .. string.format("%.2f", elapsed * 1000) .. "ms: " .. tostring(result))
	end
	return ok, result
end

function Diagnostics.error(scope, message, details)
	table.insert(Diagnostics.Metrics.errors, { scope = tostring(scope), message = tostring(message), details = tostring(details or ""), at = os.date("%H:%M:%S") })
end

function Diagnostics.report()
	local m = Diagnostics.Metrics
	local lines = {}
	table.insert(lines, "=== Startup Report ===")
	table.insert(lines, "Modules loaded: " .. tostring(#m.startup))
	local failures = 0
	for _, entry in ipairs(m.startup) do
		if not entry.ok then failures = failures + 1 end
	end
	table.insert(lines, "Failures: " .. tostring(failures))
	table.insert(lines, "Errors logged: " .. tostring(#m.errors))
	if #m.startup > 0 then
		local total = 0
		for _, entry in ipairs(m.startup) do
			total = total + entry.elapsed
		end
		table.insert(lines, "Total startup: " .. string.format("%.2f", total * 1000) .. "ms")
	end
	if #m.errors > 0 then
		table.insert(lines, "")
		table.insert(lines, "=== Error Log ===")
		for _, err in ipairs(m.errors) do
			table.insert(lines, "[" .. err.at .. "] " .. err.scope .. ": " .. err.message)
			if err.details ~= "" then table.insert(lines, "  -> " .. err.details) end
		end
	end
	return table.concat(lines, "\n")
end

if getgenv then getgenv().Alleral_Diagnostics = Diagnostics end
return Diagnostics
