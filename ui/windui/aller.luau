--[[
	Legacy entry — Arrrel UI lives in arrrel.luau.
	Kept so older loaders and URLs keep working.
]]

local PATCH_ROOTS = {
	"ui/windui/",
	"vendor/windui/",
	"windui/",
	"kick/ui/windui/",
	"kick/kick/ui/windui/",
}

local function loadArrrelPatch()
	local readFn = readfile or (syn and syn.readfile) or (fluxus and fluxus.readfile)
	local isFileFn = isfile or (syn and syn.isfile)
	if type(readFn) ~= "function" or type(isFileFn) ~= "function" then
		return nil
	end
	for _, root in ipairs(PATCH_ROOTS) do
		local path = root .. "arrrel.luau"
		if isFileFn(path) then
			local ok, body = pcall(readFn, path)
			if ok and type(body) == "string" and body:find("return function", 1, true) then
				local compile = loadstring or load
				if type(compile) == "function" then
					local chunk, err = compile(body, "@" .. path)
					if chunk then
						local okFn, patchFn = pcall(chunk)
						if okFn and type(patchFn) == "function" then
							return patchFn
						end
					else
						warn("[Arrrel] legacy shim compile: " .. tostring(err))
					end
				end
			end
		end
	end
	return nil
end

return loadArrrelPatch() or function(WindUI)
	warn("[Arrrel] arrrel.luau missing — legacy aller.luau shim skipped")
	return WindUI
end
