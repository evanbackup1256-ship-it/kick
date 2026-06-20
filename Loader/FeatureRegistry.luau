-- Alleral_FeatureRegistry
local FeatureRegistry = { VERSION = "1.0.0", _features = {}, _loaded = {} }

function FeatureRegistry.register(name, loaderFn)
	if type(name) ~= "string" or type(loaderFn) ~= "function" then
		warn("[FeatureRegistry] Invalid registration: " .. tostring(name))
		return false
	end
	FeatureRegistry._features[name] = loaderFn
	return true
end

function FeatureRegistry.load(name, ...)
	local fn = FeatureRegistry._features[name]
	if type(fn) ~= "function" then
		warn("[FeatureRegistry] Unknown feature: " .. tostring(name))
		return nil
	end
	if FeatureRegistry._loaded[name] then
		return FeatureRegistry._loaded[name]
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn("[FeatureRegistry] Feature '" .. name .. "' failed: " .. tostring(result))
		return nil
	end
	FeatureRegistry._loaded[name] = result
	return result
end

function FeatureRegistry.loadAll(...)
	local results = {}
	for name, fn in pairs(FeatureRegistry._features) do
		local ok, result = pcall(fn, ...)
		results[name] = { ok = ok, result = result }
		if not ok then
			warn("[FeatureRegistry] Feature '" .. name .. "' failed: " .. tostring(result))
		end
	end
	return results
end

function FeatureRegistry.isLoaded(name)
	return FeatureRegistry._loaded[name] ~= nil
end

function FeatureRegistry.list()
	local names = {}
	for name in pairs(FeatureRegistry._features) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function FeatureRegistry.unload(name)
	if FeatureRegistry._loaded[name] ~= nil then
		FeatureRegistry._loaded[name] = nil
		return true
	end
	return false
end

function FeatureRegistry.unloadAll()
	FeatureRegistry._loaded = {}
end

if getgenv then getgenv().Alleral_FeatureRegistry = FeatureRegistry end
return FeatureRegistry
