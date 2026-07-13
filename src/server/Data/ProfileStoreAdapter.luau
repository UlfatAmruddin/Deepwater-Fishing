--!strict
-- Real persistence adapter.
--
-- Wraps the vendored ProfileStore (the only code, besides ProfileStore itself,
-- permitted to touch DataStoreService) behind the minimal SessionCore.Adapter
-- interface, so SessionCore stays pure/testable. In Studio (no published
-- DataStore API) it uses ProfileStore's mock store so playtests work offline.

local RunService = game:GetService("RunService")

local SessionCore = require(script.Parent.SessionCore)

-- ProfileStore's own exported types are broad; view it through a minimal local
-- interface so our strict code never couples to its internals.
type ProfileLike = {
	Data: { [string]: any },
	IsActive: (ProfileLike) -> boolean,
	EndSession: (ProfileLike) -> (),
	OnSessionEnd: { Connect: (any, () -> ()) -> any },
}
type ProfileStoreLike = {
	Mock: ProfileStoreLike,
	StartSessionAsync: (ProfileStoreLike, key: string) -> ProfileLike?,
}
type ProfileStoreModule = {
	New: (storeName: string, template: { [string]: any }?) -> ProfileStoreLike,
}

local ProfileStore = (require(script.Parent.ProfileStore) :: any) :: ProfileStoreModule

local ProfileStoreAdapter = {}
ProfileStoreAdapter.__index = ProfileStoreAdapter

export type ProfileStoreAdapter = typeof(setmetatable(
	{} :: { _store: ProfileStoreLike },
	ProfileStoreAdapter
))

-- `useMock` defaults to true in Studio and false on a live server.
function ProfileStoreAdapter.new(
	storeName: string,
	template: { [string]: any },
	useMock: boolean?
): ProfileStoreAdapter
	local store = ProfileStore.New(storeName, template)
	local mock = if useMock ~= nil then useMock else RunService:IsStudio()
	return setmetatable({ _store = if mock then store.Mock else store }, ProfileStoreAdapter)
end

function ProfileStoreAdapter.startSession(
	self: ProfileStoreAdapter,
	key: string
): SessionCore.Session?
	local profile = self._store:StartSessionAsync(key)
	if not profile then
		return nil
	end
	local session: SessionCore.Session = {
		data = profile.Data,
		isActive = function()
			return profile:IsActive()
		end,
		endSession = function()
			profile:EndSession()
		end,
		onSessionEnd = function(_, callback)
			profile.OnSessionEnd:Connect(callback)
		end,
	}
	return session
end

return ProfileStoreAdapter
