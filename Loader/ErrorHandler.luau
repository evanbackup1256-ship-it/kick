-- Alleral_ErrorHandler
local ErrorHandler = { VERSION = "1.0.0" }

function ErrorHandler.safeCall(name, fn, ...)
	local args = table.pack(...)
	local ok, result = pcall(function()
		return fn(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[ErrorHandler] " .. tostring(name or "?") .. " failed: " .. tostring(result))
		return nil, result
	end
	return result
end

function ErrorHandler.guard(name, fn)
	return function(...)
		return ErrorHandler.safeCall(name, fn, ...)
	end
end

function ErrorHandler.try(fn, fallback)
	local ok, result = pcall(fn)
	if ok then
		return result
	end
	if fallback ~= nil then
		return fallback
	end
	return nil
end

function ErrorHandler.assertType(value, typeName, name)
	if type(value) ~= typeName then
		warn("[ErrorHandler] Type mismatch: " .. tostring(name or "?") .. " expected " .. typeName .. ", got " .. type(value))
		return false
	end
	return true
end

function ErrorHandler.assertExists(value, name)
	if value == nil then
		warn("[ErrorHandler] Nil value: " .. tostring(name or "?"))
		return false
	end
	return true
end

if getgenv then getgenv().Alleral_ErrorHandler = ErrorHandler end
return ErrorHandler
