--!strict
-- A small confirm dialog on top of everything, for actions that cannot be
-- undone (releasing pets, rebirth uses its own hold-to-confirm screen).

local Kit = require(script.Parent:WaitForChild("Kit"))
local Root = require(script.Parent:WaitForChild("Root"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local Dialog = {}

local open: GuiObject? = nil

function Dialog.confirm(title: string, body: string, confirmText: string, colour: Color3?, onConfirm: () -> ())
	if open then
		open:Destroy()
	end
	local shade = Kit.new("TextButton", {
		Name = "Dialog",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.color.overlay,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = Root.toasts,
	})
	local box = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.color.panel,
		Active = true, -- clicks on the box must not reach the shade behind it
		ZIndex = 51,
		Parent = shade,
	}, {
		Kit.corner(UDim.new(0, 18)),
		Kit.stroke(),
		Kit.padding(20, 18),
		Kit.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center),
	})
	open = shade
	local function close()
		if open == shade then
			open = nil
		end
		shade:Destroy()
	end
	shade.Activated:Connect(close)
	Kit.label({
		Text = title,
		FontFace = Theme.font.heading,
		TextSize = 28,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 1,
		ZIndex = 52,
		Parent = box,
	})
	Kit.label({
		Text = body,
		FontFace = Theme.font.body,
		TextSize = 20,
		TextColor3 = Theme.color.muted,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		ZIndex = 52,
		Parent = box,
	})
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = 3,
		ZIndex = 52,
		Parent = box,
	}, { Kit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) })
	Kit.button({
		text = "Cancel",
		colour = Theme.color.grey,
		size = UDim2.fromOffset(170, 54),
		layoutOrder = 1,
		parent = row,
		onClick = close,
	})
	Kit.button({
		text = confirmText,
		colour = colour or Theme.color.red,
		size = UDim2.fromOffset(170, 54),
		layoutOrder = 2,
		parent = row,
		onClick = function()
			close()
			onConfirm()
		end,
	})
end

return Dialog
