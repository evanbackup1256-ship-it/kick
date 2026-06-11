local Access = {}
Access.VERSION = "1.0"

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

function Access.getConfig()
	local cfg = ENV.Alleral_OwnerAccess
	if type(cfg) ~= "table" then
		cfg = {}
	end
	cfg.mode = cfg.mode or "public"
	cfg.publicKey = cfg.publicKey or "PUBLIC"
	return cfg
end

function Access.grant()
	local cfg = Access.getConfig()
	local key = tostring(cfg.publicKey or "PUBLIC")
	ENV.SCRIPT_KEY = key
	getgenv().SCRIPT_KEY = key
	getgenv().JD_IS_PREMIUM = true
	getgenv().JD_REASON = "Public access"
	ENV.Alleral_AccessSession = {
		mode = cfg.mode,
		key = key,
		grantedAt = os.time(),
		isPremium = true,
	}
	return true, cfg.mode
end

function Access.ensureAccess(_options)
	return Access.grant()
end

function Access.isPremium()
	return true
end

function Access.mode()
	return Access.getConfig().mode
end

function Access.installBridge()
	ENV.Alleral_Access = Access
	ENV.Alleral_EnsureAccess = function(options)
		return Access.ensureAccess(options)
	end
	pcall(function()
		if shared then
			shared.Alleral_Access = Access
		end
	end)
end

Access.installBridge()
return Access
