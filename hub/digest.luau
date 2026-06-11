-- Executor-safe string digest (no HttpService.Hash — Volt and others lack it).

local Digest = {}

local function trim(value)
	if value == nil then
		return ""
	end
	return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function envTable()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

function Digest.hash(text)
	text = trim(text)
	if text == "" then
		return ""
	end

	local ENV = envTable()
	if type(ENV.syn) == "table" and type(ENV.syn.crypt) == "table" and type(ENV.syn.crypt.hash) == "function" then
		local ok, digest = pcall(function()
			return ENV.syn.crypt.hash(text, "sha512")
		end)
		if ok and type(digest) == "string" and digest ~= "" then
			return digest
		end
	end

	local h1, h2 = 5381, 0
	for i = 1, #text do
		local byte = string.byte(text, i)
		h1 = (h1 * 33 + byte) % 2147483647
		h2 = (h2 * 31 + byte * (i % 7 + 1)) % 2147483647
	end
	return string.format("al_%x_%x_%x", h1, h2, #text)
end

function Digest.guidFallback()
	local HttpService = game:GetService("HttpService")
	local ok, id = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(id) == "string" and id ~= "" then
		return id
	end
	return "al_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
end

return Digest
