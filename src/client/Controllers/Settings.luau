--!strict
-- Player settings, saved on the server with the rest of the profile:
-- skipping reveals for common pets, Auto Hatch (once unlocked) and sound
-- volume. Also says plainly whether progress is being saved.

local Client = script.Parent.Parent
local App = require(Client:WaitForChild("App"))
local Net = require(Client:WaitForChild("Net"))
local State = require(Client:WaitForChild("State"))
local Sfx = require(Client:WaitForChild("Sfx"))
local UI = Client:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Root = require(UI:WaitForChild("Root"))
local Theme = require(UI:WaitForChild("Theme"))

local Settings = {}

local VOLUMES = { 0, 0.25, 0.5, 0.75, 1 }

local function setSetting(key: string, value: any)
	task.spawn(function()
		local response = Net.request("SetSetting", key, value)
		if not response.ok then
			Root.toastError(response.err)
		end
	end)
end

local function row(parent: Instance, order: number, title: string, detail: string): (Frame, TextLabel)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.color.panelAlt,
		Size = UDim2.new(1, 0, 0, 72),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(UDim.new(0, 12)) })
	Kit.label({
		Text = title,
		FontFace = Theme.font.heading,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -260, 0, 26),
		Position = UDim2.fromOffset(16, 10),
		Parent = frame,
	})
	local detailLabel = Kit.label({
		Text = detail,
		FontFace = Theme.font.body,
		TextSize = 15,
		TextColor3 = Theme.color.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, -260, 0, 30),
		Position = UDim2.fromOffset(16, 36),
		Parent = frame,
	})
	return frame, detailLabel
end

local function toggle(parent: Instance, onClick: () -> ()): Kit.Button
	return Kit.button({
		text = "",
		size = UDim2.fromOffset(110, 48),
		position = UDim2.new(1, -14, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		textSize = 20,
		parent = parent,
		onClick = onClick,
	})
end

local function paintToggle(button: Kit.Button, on: boolean)
	button.setText(if on then "On" else "Off")
	button.setColour(if on then Theme.color.green else Theme.color.grey)
end

function Settings.start()
	local panel = Kit.panel("Settings", Vector2.new(640, 400), Theme.color.greyDark)
	local handle: Root.PanelHandle = { root = panel.root }
	panel.onClose = Root.closePanel
	App.registerPanel("Settings", handle)

	local list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = panel.body,
	}, { Kit.list(Enum.FillDirection.Vertical, 10) })

	local skipRow = row(
		list,
		1,
		"Quick common hatches",
		"Common and Uncommon pets you already have show a short message instead of the full reveal."
	)
	local skipButton = toggle(skipRow, function()
		setSetting("skipCommonReveals", not State.data.settings.skipCommonReveals)
	end)

	local autoRow = row(list, 2, "Auto Hatch", "Eggs start hatching on their own whenever an incubator is free.")
	local autoButton = toggle(autoRow, function()
		setSetting("autoHatch", not State.data.settings.autoHatch)
	end)

	local soundRow = row(list, 3, "Sound effects", "Volume for clicks, rolls and reveals.")
	local volumeButtons: { Kit.Button } = {}
	local volumeHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(236, 44),
		Parent = soundRow,
	}, { Kit.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right) })
	for i, volume in VOLUMES do
		volumeButtons[i] = Kit.button({
			text = if volume == 0 then "🔇" else `{math.floor(volume * 100)}`,
			size = UDim2.fromOffset(44, 44),
			textSize = 15,
			layoutOrder = i,
			parent = volumeHolder,
			onClick = function()
				Sfx.setVolume(volume) -- immediate feedback; the server saves it
				setSetting("sfxVolume", volume)
			end,
		})
	end

	local _, savingDetail = row(list, 4, "Saving", "")

	local function refresh()
		local settings = State.data.settings
		paintToggle(skipButton, settings.skipCommonReveals)
		local unlocked = State.stats.autoHatch > 0
		autoButton.setEnabled(unlocked)
		if unlocked then
			paintToggle(autoButton, settings.autoHatch)
		else
			autoButton.setText(`{Theme.icon.lock} Locked`)
		end
		for i, button in volumeButtons do
			local selected = math.abs(VOLUMES[i] - settings.sfxVolume) < 0.01
			button.setColour(if selected then Theme.color.blue else Theme.color.grey)
		end
		savingDetail.Text = if State.saving
			then "Your progress saves automatically."
			elseif State.studio then "Saving is off in this Studio session (API access is disabled)."
			else "Saving is unavailable right now. Progress from this visit may not be kept."
	end

	handle.onOpen = refresh
	State.watch({ "settings", "@stats" }, function()
		if panel.root.Visible then
			refresh()
		end
	end)
end

return Settings
