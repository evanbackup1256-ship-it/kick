-- Alleral_Validation
local Validation = { VERSION = "1.0.0" }

function Validation.isType(value, typeName, name)
	if type(value) ~= typeName then
		warn("[Validation] " .. tostring(name or "?") .. " expected " .. typeName .. ", got " .. type(value))
		return false
	end
	return true
end

function Validation.exists(value, name)
	if value == nil then
		warn("[Validation] " .. tostring(name or "?") .. " is nil")
		return false
	end
	return true
end

function Validation.isFunction(value, name)
	if type(value) ~= "function" then
		warn("[Validation] " .. tostring(name or "?") .. " is not a function (got " .. type(value) .. ")")
		return false
	end
	return true
end

function Validation.isTable(value, name)
	if type(value) ~= "table" then
		warn("[Validation] " .. tostring(name or "?") .. " is not a table (got " .. type(value) .. ")")
		return false
	end
	return true
end

function Validation.isString(value, name)
	if type(value) ~= "string" then
		warn("[Validation] " .. tostring(name or "?") .. " is not a string (got " .. type(value) .. ")")
		return false
	end
	return true
end

function Validation.isInstance(value, name)
	if typeof(value) ~= "Instance" then
		warn("[Validation] " .. tostring(name or "?") .. " is not an Instance (got " .. typeof(value) .. ")")
		return false
	end
	return true
end

if getgenv then getgenv().Alleral_Validation = Validation end
return Validation
