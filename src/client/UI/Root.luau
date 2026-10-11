--!strict
-- The single ScreenGui every screen lives in, scaled to the device, plus the
-- panel manager (one panel open at a time; Escape, the X or tapping outside
-- closes it) and toasts.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent:WaitForChild("Kit"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Sfx = require(script.Parent.Parent:WaitForChild("Sfx"))

local Root = {}

local player = Players.LocalPlayer
local gui: ScreenGui = Kit.new("ScreenGui", {
	Name = "RollRNG",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local scale: UIScale = Kit.new("UIScale", { Parent = gui })

local function layer(name: string, z: number): Frame
	return Kit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = gui,
	})
end

Root.gui = gui
Root.hud = layer("Hud", 1)
Root.context = layer("Context", 2)
Root.panels = layer("Panels", 3)
Root.reveal = layer("Reveal", 4)
Root.toasts = layer("Toasts", 5)

-- Everything is designed at 1280 x 720 and scaled by the shortest side.
local function rescale()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local viewport = camera.ViewportSize
	local shortest = math.min(viewport.X, viewport.Y)
	scale.Scale = math.clamp(shortest / 720, 0.6, 1.25)
	-- UIScale also scales the layers, so they are shrunk back to fill the screen.
	for _, child in { Root.hud, Root.context, Root.panels, Root.reveal, Root.toasts } do
		child.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
	end
end
rescale()
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	rescale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function Root.isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

--------------------------------------------------------------------------------
-- Panels

export type PanelHandle = {
	root: GuiObject,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
	fullscreen: boolean?,
}

local dim: TextButton = Kit.new("TextButton", {
	Name = "Dim",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Theme.color.overlay,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = Root.panels,
})

local current: PanelHandle? = nil
Root.panelChanged = Instance.new("BindableEvent")

function Root.closePanel()
	local panel = current
	if panel == nil then
		return
	end
	current = nil
	panel.root.Visible = false
	dim.Visible = false
	dim.BackgroundTransparency = 1
	if panel.onClose then
		panel.onClose()
	end
	Root.panelChanged:Fire(nil)
end

function Root.openPanel(panel: PanelHandle)
	if current == panel then
		return
	end
	Root.closePanel()
	current = panel
	panel.root.Parent = Root.panels
	panel.root.ZIndex = 2
	dim.Visible = not panel.fullscreen
	Kit.tween(dim, 0.15, { BackgroundTransparency = 0.45 })
	panel.root.Visible = true
	if panel.onOpen then
		panel.onOpen()
	end
	-- a small pop-in
	local uiScale = panel.root:FindFirstChild("PopScale") :: UIScale?
	if uiScale == nil then
		uiScale = Kit.new("UIScale", { Name = "PopScale", Parent = panel.root })
	end
	if uiScale then
		uiScale.Scale = 0.92
		Kit.tween(uiScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	Root.panelChanged:Fire(panel)
end

function Root.togglePanel(panel: PanelHandle)
	if current == panel then
		Root.closePanel()
	else
		Root.openPanel(panel)
	end
end

function Root.isOpen(panel: PanelHandle): boolean
	return current == panel
end

function Root.anyPanelOpen(): boolean
	return current ~= nil
end

dim.Activated:Connect(Root.closePanel)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if current and not processed then
			Root.closePanel()
		end
	end
end)
GuiService.MenuOpened:Connect(Root.closePanel)

--------------------------------------------------------------------------------
-- Toasts (top right, at most three)

local toastList: Frame = Kit.new("Frame", {
	Name = "ToastList",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 70),
	Size = UDim2.fromOffset(340, 400),
	Parent = Root.toasts,
}, { Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })

local toastOrder = 0
export type ToastKind = "error" | "info" | "good"

function Root.toast(text: string, kind: ToastKind?)
	toastOrder += 1
	local colour = if kind == "error"
		then Theme.color.red
		elseif kind == "good" then Theme.color.green
		else Theme.color.blue
	local children = toastList:GetChildren()
	local frames = {}
	for _, child in children do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames >= 3 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	local toast = Kit.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = Theme.color.panel,
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = toastOrder,
		Parent = toastList,
	}, {
		Kit.corner(UDim.new(0, 12)),
		Kit.stroke(colour, 3),
		Kit.padding(14, 10),
	})
	Kit.label({
		Text = text,
		FontFace = Theme.font.bold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toast,
	})
	task.delay(3.2, function()
		if toast.Parent then
			Kit.tween(toast, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.25)
			toast:Destroy()
		end
	end)
end

-- Shows a server refusal (or anything else) as an error toast.
function Root.toastError(err: string?)
	Sfx.play("error")
	Root.toast(err or "Something went wrong", "error")
end

return Root
