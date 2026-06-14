local env = getgenv and getgenv() or {}

return {
	enabled = true,
	relayUrl = "https://alleral-telemetry-production.up.railway.app/ingest",
	gateUrl = "https://alleral-telemetry-production.up.railway.app/gate/check",
	apiKey = tostring(env.Alleral_TelemetryApiKey or ""),
}
