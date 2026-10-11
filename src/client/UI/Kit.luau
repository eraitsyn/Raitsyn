--!strict
-- Small UI building blocks: create(), chunky buttons, panels, progress bars
-- and 3D previews. Every screen is built from these so the game looks like
-- one product.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))

local Kit = {}

-- Creates an instance, sets properties and parents children.
function Kit.new(className: string, props: { [string]: any }?, children: { any }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.corner(radius: UDim?): Instance
	return Kit.new("UICorner", { CornerRadius = radius or Theme.radius })
end

function Kit.stroke(colour: Color3?, thickness: number?, transparency: number?): Instance
	return Kit.new("UIStroke", {
		Color = colour or Theme.color.stroke,
		Thickness = thickness or Theme.strokeWidth,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(px: number, vertical: number?): Instance
	local v = vertical or px
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, v),
		PaddingBottom = UDim.new(0, v),
	})
end

function Kit.list(direction: Enum.FillDirection, gap: number, align: Enum.HorizontalAlignment?): Instance
	return Kit.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
end

function Kit.grid(cell: UDim2, gap: number): Instance
	return Kit.new("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- A text label with the game's defaults. `stroke` adds a dark outline,
-- for text drawn over the 3D world.
function Kit.label(props: { [string]: any }, stroke: boolean?): TextLabel
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.font.body,
		TextColor3 = Theme.color.text,
		TextSize = 18,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	})
	for key, value in props do
		if key == "Parent" then
			continue
		end
		(label :: any)[key] = value
	end
	if stroke then
		Kit.new("UIStroke", { Color = Theme.color.stroke, Thickness = 2, Parent = label })
	end
	label.Parent = props.Parent
	return label
end

function Kit.tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

export type Button = {
	root: Frame,
	face: TextButton,
	label: TextLabel,
	setText: (text: string) -> (),
	setColour: (colour: Color3) -> (),
	setEnabled: (enabled: boolean) -> (),
	enabled: () -> boolean,
}

export type ButtonOptions = {
	text: string,
	colour: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	textColour: Color3?,
	font: Font?,
	layoutOrder: number?,
	name: string?,
	parent: Instance?,
	onClick: (() -> ())?,
}

-- A chunky button with a darker "shadow" under it that presses down.
function Kit.button(options: ButtonOptions): Button
	local colour = options.colour or Theme.color.green
	local isEnabled = true
	local root = Kit.new("Frame", {
		Name = options.name or "Button",
		BackgroundTransparency = 1,
		Size = options.size or UDim2.fromOffset(160, 52),
		Position = options.position or UDim2.new(),
		AnchorPoint = options.anchor or Vector2.zero,
		LayoutOrder = options.layoutOrder or 0,
	})
	local shadow = Kit.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.shade(colour, 0.3),
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.fromOffset(0, 4),
		Parent = root,
	}, { Kit.corner() })
	local face = Kit.new("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = colour,
		Size = UDim2.new(1, 0, 1, -4),
		Parent = root,
	}, { Kit.corner(), Kit.stroke(Theme.shade(colour, 0.45), 2) })
	local label = Kit.label({
		Text = options.text,
		FontFace = options.font or Theme.font.heading,
		TextSize = options.textSize or 22,
		TextColor3 = options.textColour or Theme.color.white,
		TextWrapped = false,
		TextScaled = false,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Parent = face,
	}, true)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 1.5
		stroke.Color = Theme.shade(colour, 0.5)
	end

	local base = colour
	local function paint(hover: boolean)
		local c = if isEnabled then base else Theme.color.grey
		face.BackgroundColor3 = if hover and isEnabled then c:Lerp(Color3.new(1, 1, 1), 0.12) else c
		shadow.BackgroundColor3 = Theme.shade(c, 0.3)
	end
	face.MouseEnter:Connect(function()
		paint(true)
	end)
	face.MouseLeave:Connect(function()
		paint(false)
		face.Position = UDim2.new()
	end)
	face.MouseButton1Down:Connect(function()
		if isEnabled then
			face.Position = UDim2.fromOffset(0, 3)
		end
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.Activated:Connect(function()
		face.Position = UDim2.new()
		if isEnabled and options.onClick then
			Sfx.play("click")
			options.onClick()
		end
	end)
	if options.parent then
		root.Parent = options.parent
	end

	return {
		root = root,
		face = face,
		label = label,
		setText = function(text: string)
			label.Text = text
		end,
		setColour = function(c: Color3)
			base = c
			paint(false)
		end,
		setEnabled = function(enabled: boolean)
			isEnabled = enabled
			paint(false)
		end,
		enabled = function()
			return isEnabled
		end,
	}
end

export type Panel = {
	root: Frame,
	body: Frame,
	title: TextLabel,
	header: Frame,
	onClose: (() -> ())?,
}

-- A centred white panel with a coloured header and a close button.
function Kit.panel(titleText: string, size: Vector2, accent: Color3?): Panel
	local colour = accent or Theme.color.blue
	local root = Kit.new("Frame", {
		Name = titleText,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
	}, { Kit.corner(UDim.new(0, 18)), Kit.stroke() })
	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = colour,
		Size = UDim2.new(1, 0, 0, 56),
		Parent = root,
	}, { Kit.corner(UDim.new(0, 18)) })
	-- square off the header's bottom corners
	Kit.new("Frame", {
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		Parent = header,
	})
	local title = Kit.label({
		Text = titleText,
		FontFace = Theme.font.heading,
		TextSize = 30,
		TextColor3 = Theme.color.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		ZIndex = 2,
		Parent = header,
	}, true)
	local body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -32, 1, -76),
		Position = UDim2.fromOffset(16, 66),
		Parent = root,
	})
	local panel: Panel = { root = root, body = body, title = title, header = header }
	Kit.button({
		text = Theme.icon.close,
		colour = Theme.color.red,
		size = UDim2.fromOffset(44, 46),
		position = UDim2.new(1, -8, 0, 5),
		anchor = Vector2.new(1, 0),
		textSize = 24,
		name = "Close",
		parent = header,
		onClick = function()
			if panel.onClose then
				panel.onClose()
			end
		end,
	})
	return panel
end

function Kit.scroll(props: { [string]: any }): ScrollingFrame
	local frame = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.color.greyDark,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	})
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	frame.Parent = props.Parent
	return frame
end

export type Progress = { root: Frame, fill: Frame, set: (fraction: number) -> () }

function Kit.progress(colour: Color3, size: UDim2, parent: Instance?): Progress
	local root = Kit.new("Frame", {
		Name = "Progress",
		BackgroundColor3 = Theme.color.panelDeep,
		Size = size,
		Parent = parent,
	}, { Kit.corner(UDim.new(1, 0)) })
	local fill = Kit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = colour,
		Size = UDim2.fromScale(0, 1),
		Parent = root,
	}, { Kit.corner(UDim.new(1, 0)) })
	return {
		root = root,
		fill = fill,
		set = function(fraction: number)
			fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		end,
	}
end

-- A 3D preview of a model (a pet or an egg). The model is moved into the
-- viewport; the camera frames it from the front, slightly above.
function Kit.viewport(model: Model, height: number, props: { [string]: any }?): ViewportFrame
	local frame = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local focus = Vector3.new(0, height * 0.5, 0)
	local distance = math.max(height, 2) * 2.6 + 3
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.35, distance * 0.3, -distance), focus)
	camera.Parent = frame
	frame.CurrentCamera = camera
	model:PivotTo(CFrame.new())
	model.Parent = frame
	return frame
end

return Kit
