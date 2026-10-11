--!strict
-- Loads and releases player profiles through ProfileStore, which handles
-- session locking (no two servers own a profile at once), autosave, retries
-- and saving everything on shutdown. A player is never allowed to play on
-- data that did not load: blank data would overwrite their real save.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Server = script.Parent.Parent
local ProfileStore = require(Server:WaitForChild("Vendor"):WaitForChild("ProfileStore")) :: any
local Schema = require(Server:WaitForChild("Data"):WaitForChild("Schema"))

local STORE_NAME = "RollRNG_Profiles_v1"
local EARLY_SAVE_GAP = 30 -- seconds between requested early saves per player

export type Profile = {
	Data: Schema.Profile,
	OnSave: any,
	OnSessionEnd: any,
	IsActive: (self: Profile) -> boolean,
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	Save: (self: Profile) -> (),
}

export type LoadError = "left" | "failed" | "future"

local DataService = {}

local store: any
local lastEarlySave: { [Player]: number } = {}

function DataService.start()
	store = ProfileStore.New(STORE_NAME, Schema.template())
	Players.PlayerRemoving:Connect(function(player)
		lastEarlySave[player] = nil
	end)
end

-- Yields until the profile is loaded, or the player leaves, or loading fails.
function DataService.load(player: Player): (Profile?, LoadError?)
	local profile: Profile? = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		return nil, if player.Parent ~= Players then "left" else "failed"
	end
	profile:AddUserId(player.UserId) -- GDPR: lets Roblox erasure requests find this key
	if Schema.migrate(profile.Data :: any) == "future" then
		-- Written by a newer server version; ending the session without
		-- touching it keeps it intact for that version.
		profile:EndSession()
		return nil, "future"
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return nil, "left"
	end
	return profile, nil
end

-- Asks for a save soon after a valuable moment (a Mythic hatch, a rebirth),
-- at most once every EARLY_SAVE_GAP seconds per player.
function DataService.saveSoon(player: Player, profile: Profile)
	local now = os.clock()
	if now - (lastEarlySave[player] or -math.huge) < EARLY_SAVE_GAP then
		return
	end
	lastEarlySave[player] = now
	if profile:IsActive() then
		profile:Save()
	end
end

-- True when changes really reach the DataStore. In Studio without API
-- access ProfileStore keeps data in memory only, and players are told.
function DataService.isSaving(): boolean
	return ProfileStore.DataStoreState == "Access"
end

function DataService.isStudio(): boolean
	return RunService:IsStudio()
end

return DataService
