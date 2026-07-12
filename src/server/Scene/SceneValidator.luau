--!strict
-- Boot-time diagnostics for the authored 2.5D scene.
--
-- The playable scene (boat, seat, camera anchor, hook origin, depth layers) is
-- authored data in the place file, built by scene/BuildScene.luau — it is NOT
-- synced by Rojo. This validator asks shared/SceneContract to audit the
-- asset-replacement contract and logs each issue. It never errors: a developer
-- editing or replacing scene models should get actionable guidance, not a crash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SceneConfig = require(Shared.Config.SceneConfig)
local SceneContract = require(Shared.SceneContract)
local Log = require(Shared.Util.Log)

local SceneValidator = {}

function SceneValidator.validate()
	local issues = SceneContract.audit()
	for _, message in issues do
		Log.warn(message)
	end
	if #issues == 0 then
		Log.info("Scene contract validated:", SceneConfig.sceneName)
	else
		Log.warn(
			("Scene contract: %d issue(s) above — see docs/ASSET_REPLACEMENT.md."):format(#issues)
		)
	end
end

return SceneValidator
