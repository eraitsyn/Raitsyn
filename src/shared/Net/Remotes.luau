--!strict
-- Every remote in the game. Requests are RemoteFunctions that return a
-- Response; server-to-client pushes are RemoteEvents. The server creates
-- them all under ReplicatedStorage.Remotes at start, and the client only
-- ever looks them up by these names. Argument checks live on the server
-- (NetService), never here, because the client must not be trusted to run them.

export type Response = {
	ok: boolean,
	err: string?, -- player-facing reason when not ok
	data: any?,
}

return table.freeze({
	folderName = "Remotes",

	requests = table.freeze({
		"GetSnapshot",
		"Roll",
		"Hatch",
		"Place",
		"Remove",
		"RemoveAll",
		"PlaceBest",
		"SetLocked",
		"SetFollowing",
		"Release",
		"ReleaseRarity",
		"BuyTile",
		"Rebirth",
		"ClaimDaily",
		"SetSetting",
		"SetTutorial",
	}),

	events = table.freeze({
		"Patch", -- { { k: key, s: sub-key?, v: value } }: changes to your own profile
		"Hatched", -- { HatchedPet }: eggs that just cracked
		"Rolled", -- { player, rarity }: a rare roll by anyone, for announcements
		"Notice", -- { kind, ... }: crits, welcome back, toasts the server wants shown
	}),
})
