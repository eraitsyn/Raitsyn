--[[
	CurrencyService: the only code that changes a player's cash.

	Cash lives in the saved profile. leaderstats.Cash mirrors it for display and is
	never read back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local DataSchema = require(script.Parent.Parent.DataSchema)

type Account = { data: DataSchema.PlayerData, display: IntValue }

local accounts: { [Player]: Account } = {}

local CurrencyService = {}

local function sync(account: Account)
	account.display.Value = account.data.Cash
end

function CurrencyService.Attach(player: Player, data: DataSchema.PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	leaderstats.Parent = player

	local account = { data = data, display = cash }
	accounts[player] = account
	sync(account)
end

function CurrencyService.Detach(player: Player)
	accounts[player] = nil
end

function CurrencyService.Get(player: Player): number
	local account = accounts[player]
	return if account then account.data.Cash else 0
end

-- Adds a whole, non-negative amount, capped at Economy.MaxCash.
function CurrencyService.Add(player: Player, amount: number)
	assert(amount >= 0 and amount % 1 == 0, "amount must be a whole number >= 0")
	local account = accounts[player]
	if account == nil then
		return
	end
	account.data.Cash = math.min(Economy.MaxCash, account.data.Cash + amount)
	sync(account)
end

-- Subtracts the amount only if the player can afford all of it.
function CurrencyService.TrySpend(player: Player, amount: number): boolean
	assert(amount >= 0 and amount % 1 == 0, "amount must be a whole number >= 0")
	local account = accounts[player]
	if account == nil or account.data.Cash < amount then
		return false
	end
	account.data.Cash -= amount
	sync(account)
	return true
end

-- Sets cash directly. Used only by rebirth.
function CurrencyService.Reset(player: Player)
	local account = accounts[player]
	if account then
		account.data.Cash = 0
		sync(account)
	end
end

return CurrencyService
