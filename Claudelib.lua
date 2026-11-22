--[[
	Claudelib - Windows 11 style UI library for Luau (Claude color theme)

	Load:
		local Claudelib = loadstring(game:HttpGet("YOUR_RAW_URL"))()

	Use:
		local Window = Claudelib:CreateWindow({
			Title = "Claudelib",
			Subtitle = "v2.0",                 -- optional
			Theme = "Claude",                  -- "Claude" (dark) | "ClaudeLight" | your own table
			ToggleKey = Enum.KeyCode.RightShift,
			Logo = nil,                        -- optional "rbxassetid://123" to replace the built-in spark icon
			Blur = false,                      -- true (or a number) blurs the game behind the window
		})

		local Tab = Window:AddTab("General")
		local Section = Tab:AddSection("Player")

		Section:AddToggle({ Name = "Enabled", Description = "Turns the feature on", Flag = "Enabled", Callback = print })
		Section:AddSlider({ Name = "Speed", Min = 0, Max = 100, Default = 16, Suffix = "", Callback = print })
		Section:AddDropdown({ Name = "Mode", Options = { "One", "Two" }, Default = "One", Callback = print })
		Section:AddTextbox({ Name = "Name", Placeholder = "Type here", Callback = print })
		Section:AddKeybind({ Name = "Action", Default = Enum.KeyCode.E, Callback = function() print("pressed") end })
		Section:AddButton({ Name = "Run task", ButtonText = "Run", Callback = function() print("ran") end })
		Section:AddLabel("Plain text")

		Window:Notify({ Title = "Loaded", Content = "Claudelib is ready", Duration = 4 })
		print(Claudelib.Flags.Enabled)

	Every element returns an object with :Set(value) / :Get() where it makes sense.
	Callbacks fire on user changes; :Set(value, true) updates silently.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Library = { Name = "Claudelib", Version = "2.0.0", Flags = {}, Windows = {} }

----------------------------------------------------------------------
-- Fonts (with fallbacks for older clients)
----------------------------------------------------------------------

local function FontOr(name, fallback)
	local ok, font = pcall(function()
		return Enum.Font[name]
	end)
	return ok and font or fallback
end

local FONT = FontOr("BuilderSans", Enum.Font.Gotham)
local FONT_MED = FontOr("BuilderSansMedium", Enum.Font.GothamMedium)
local FONT_BOLD = FontOr("BuilderSansBold", Enum.Font.GothamBold)
local FONT_SERIF = FontOr("Merriweather", Enum.Font.GothamBold)

----------------------------------------------------------------------
-- Themes (Claude palette: Clay #D97757, Ivory #FAF9F5, Slate #262624)
----------------------------------------------------------------------

local Themes = {
	Claude = {
		Background = Color3.fromRGB(38, 38, 36),
		Tint = Color3.fromRGB(56, 46, 41),
		BackgroundTransparency = 0.12,
		Card = Color3.fromRGB(250, 249, 245),
		CardTransparency = 0.94,
		Control = Color3.fromRGB(250, 249, 245),
		ControlTransparency = 0.9,
		Stroke = Color3.fromRGB(250, 249, 245),
		StrokeTransparency = 0.9,
		Border = Color3.fromRGB(250, 249, 245),
		BorderTransparency = 0.82,
		Accent = Color3.fromRGB(217, 119, 87),
		AccentHover = Color3.fromRGB(229, 138, 107),
		AccentPressed = Color3.fromRGB(193, 95, 60),
		AccentText = Color3.fromRGB(250, 249, 245),
		Text = Color3.fromRGB(250, 249, 245),
		SubText = Color3.fromRGB(176, 174, 165),
		Danger = Color3.fromRGB(196, 43, 28),
	},
	ClaudeLight = {
		Background = Color3.fromRGB(240, 238, 230),
		Tint = Color3.fromRGB(250, 249, 245),
		BackgroundTransparency = 0.1,
		Card = Color3.fromRGB(255, 255, 255),
		CardTransparency = 0.35,
		Control = Color3.fromRGB(255, 255, 255),
		ControlTransparency = 0.25,
		Stroke = Color3.fromRGB(20, 20, 19),
		StrokeTransparency = 0.88,
		Border = Color3.fromRGB(20, 20, 19),
		BorderTransparency = 0.8,
		Accent = Color3.fromRGB(201, 100, 66),
		AccentHover = Color3.fromRGB(217, 119, 87),
		AccentPressed = Color3.fromRGB(170, 80, 50),
		AccentText = Color3.fromRGB(255, 255, 255),
		Text = Color3.fromRGB(20, 20, 19),
		SubText = Color3.fromRGB(107, 106, 100),
		Danger = Color3.fromRGB(196, 43, 28),
	},
}
Themes.Dark = Themes.Claude
Themes.Light = Themes.ClaudeLight
Library.Themes = Themes

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function Create(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Tween(inst, props, duration)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

local function Apply(inst, props, instant, duration)
	if instant then
		for k, v in pairs(props) do
			inst[k] = v
		end
	else
		Tween(inst, props, duration)
	end
end

local function Corner(parent, radius)
	return Create("UICorner", {
		CornerRadius = radius == "pill" and UDim.new(1, 0) or UDim.new(0, radius or 6),
		Parent = parent,
	})
end

local function Stroke(parent, color, thickness, transparency)
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Pad(parent, left, top, right, bottom)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		Parent = parent,
	})
end

local function List(parent, padding)
	return Create("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function NewText(parent, text, theme, props)
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = theme.Text,
		Font = FONT_MED,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		label[k] = v
	end
	return label
end

local function Safe(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[Claudelib] callback error: " .. tostring(err))
	end
end

local function SetFlag(opts, value)
	if opts.Flag then
		Library.Flags[opts.Flag] = value
	end
end

local function IsPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function GetGuiParent()
	local ok, hui = pcall(function()
		return gethui()
	end)
	if ok and typeof(hui) == "Instance" then
		return hui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Spark icon (12 rays). Pass an asset string to use your own image instead.
local function CreateLogo(parent, size, color, asset, props)
	local holder = Create("Frame", {
		Name = "Logo",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		holder[k] = v
	end
	if asset then
		Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = asset,
			ScaleType = Enum.ScaleType.Fit,
			Parent = holder,
		})
		return holder
	end
	local lengths = { 1, 0.82, 0.94, 0.88, 1, 0.8 }
	for i, length in ipairs(lengths) do
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * length, math.max(2, size * 0.13)),
			Rotation = (i - 1) * 30,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return holder
end

-- Windows 11 "settings card": title + optional description on the left, control on the right.
-- Returns card, rowHeight, controlCenterY
local function Card(self, opts, leftScale)
	local theme = self.Theme
	local hasDesc = type(opts.Description) == "string" and opts.Description ~= ""
	local rowH = hasDesc and 62 or 48
	leftScale = leftScale or 0.55

	local card = Create("Frame", {
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundColor3 = theme.Card,
		BackgroundTransparency = theme.CardTransparency,
		BorderSizePixel = 0,
		Parent = self.Container,
	})
	Corner(card, 6)
	Stroke(card, theme.Stroke, 1, theme.StrokeTransparency)

	if hasDesc then
		NewText(card, opts.Name or "", theme, {
			Size = UDim2.new(leftScale, -20, 0, 20),
			Position = UDim2.fromOffset(14, 11),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		NewText(card, opts.Description, theme, {
			Size = UDim2.new(leftScale, -20, 0, 18),
			Position = UDim2.fromOffset(14, 31),
			Font = FONT,
			TextSize = 12,
			TextColor3 = theme.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	else
		NewText(card, opts.Name or "", theme, {
			Size = UDim2.new(leftScale, -20, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	return card, rowH, rowH / 2
end

----------------------------------------------------------------------
-- Elements (shared by tabs and sections)
----------------------------------------------------------------------

local Elements = {}

function Elements:AddSection(name)
	local theme = self.Theme
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(holder, 6)
	NewText(holder, name or "Section", theme, {
		Size = UDim2.new(1, 0, 0, 30),
		Font = FONT_BOLD,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
	return setmetatable({
		Container = holder,
		Page = self.Page,
		Theme = theme,
		Window = self.Window,
	}, { __index = Elements })
end

function Elements:AddLabel(text)
	local theme = self.Theme
	local label = NewText(self.Container, text or "", theme, {
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = FONT,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = theme.SubText,
	})
	Pad(label, 4, 2, 4, 2)
	local obj = { Instance = label }
	function obj:Set(newText)
		label.Text = newText
	end
	return obj
end

function Elements:AddButton(opts)
	opts = opts or {}
	local theme = self.Theme
	local card, _, cy = Card(self, opts, 0.55)

	local btn = Create("TextButton", {
		Size = UDim2.fromOffset(opts.ButtonWidth or 96, 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, cy),
		BackgroundColor3 = theme.Accent,
		AutoButtonColor = false,
		Text = opts.ButtonText or "Run",
		Font = FONT_MED,
		TextSize = 13,
		TextColor3 = theme.AccentText,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(btn, 4)

	btn.MouseEnter:Connect(function()
		Tween(btn, { BackgroundColor3 = theme.AccentHover }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, { BackgroundColor3 = theme.Accent }, 0.1)
	end)
	btn.MouseButton1Down:Connect(function()
		Tween(btn, { BackgroundColor3 = theme.AccentPressed }, 0.06)
	end)
	btn.MouseButton1Up:Connect(function()
		Tween(btn, { BackgroundColor3 = theme.AccentHover }, 0.1)
	end)
	btn.MouseButton1Click:Connect(function()
		Safe(opts.Callback)
	end)

	local obj = { Instance = card }
	function obj:SetText(text)
		btn.Text = text
	end
	return obj
end

function Elements:AddToggle(opts)
	opts = opts or {}
	local theme = self.Theme
	local state = opts.Default == true
	local card, _, cy = Card(self, opts, 0.55)

	local click = Create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = card,
	})
	local status = NewText(card, "", theme, {
		Size = UDim2.fromOffset(40, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -64, 0, cy),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = FONT,
		TextSize = 13,
	})
	local track = Create("Frame", {
		Size = UDim2.fromOffset(40, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, cy),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(track, "pill")
	local trackStroke = Stroke(track, theme.SubText, 1, 0)
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(knob, "pill")

	local obj = { Instance = card }

	local function render(instant)
		Apply(track, { BackgroundTransparency = state and 0 or 1 }, instant)
		Apply(trackStroke, { Color = state and theme.Accent or theme.SubText }, instant)
		Apply(knob, {
			Size = state and UDim2.fromOffset(14, 14) or UDim2.fromOffset(12, 12),
			Position = state and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
			BackgroundColor3 = state and theme.AccentText or theme.SubText,
		}, instant)
		status.Text = state and "On" or "Off"
		status.TextColor3 = state and theme.Text or theme.SubText
	end

	function obj:Set(value, silent)
		state = value and true or false
		render(false)
		SetFlag(opts, state)
		if not silent then
			Safe(opts.Callback, state)
		end
	end
	function obj:Get()
		return state
	end

	click.MouseButton1Click:Connect(function()
		obj:Set(not state)
	end)

	render(true)
	SetFlag(opts, state)
	return obj
end

function Elements:AddSlider(opts)
	opts = opts or {}
	local theme = self.Theme
	local min, max = opts.Min or 0, opts.Max or 100
	local increment = opts.Increment or 1
	local suffix = opts.Suffix or ""
	local decimals = #(string.match(tostring(increment), "%.(%d+)") or "")
	local fmt = "%." .. decimals .. "f"
	local value = min

	local card, _, cy = Card(self, opts, 0.42)

	local valueLabel = NewText(card, "", theme, {
		Size = UDim2.fromOffset(56, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, cy),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = FONT,
		TextSize = 13,
		TextColor3 = theme.SubText,
	})
	local track = Create("Frame", {
		Size = UDim2.new(0.34, 0, 0, 4),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0, cy),
		BackgroundColor3 = theme.Text,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(track, "pill")
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(fill, "pill")
	local thumb = Create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = theme.Text,
		BorderSizePixel = 0,
		Parent = track,
	})
	Corner(thumb, "pill")
	local inner = Create("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = thumb,
	})
	Corner(inner, "pill")
	local hit = Create("TextButton", {
		Size = UDim2.new(1, 18, 0, 28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		Parent = track,
	})

	local obj = { Instance = card }

	local function apply(v, silent, force)
		v = math.clamp(v, min, max)
		v = math.floor((v - min) / increment + 0.5) * increment + min
		v = math.clamp(tonumber(string.format(fmt, v)), min, max)
		if v == value and not force then
			return
		end
		value = v
		local alpha = (max == min) and 0 or (v - min) / (max - min)
		Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.08)
		Tween(thumb, { Position = UDim2.fromScale(alpha, 0.5) }, 0.08)
		valueLabel.Text = string.format(fmt, v) .. suffix
		SetFlag(opts, v)
		if not silent then
			Safe(opts.Callback, v)
		end
	end

	function obj:Set(v, silent)
		apply(v, silent, true)
	end
	function obj:Get()
		return value
	end

	local dragging = false
	local function fromInput(input)
		local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		apply(min + (max - min) * alpha)
	end

	hit.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			if self.Page then
				self.Page.ScrollingEnabled = false
			end
			fromInput(input)
		end
	end)
	self.Window:_connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			fromInput(input)
		end
	end)
	self.Window:_connect(UserInputService.InputEnded, function(input)
		if dragging and IsPress(input) then
			dragging = false
			if self.Page then
				self.Page.ScrollingEnabled = true
			end
		end
	end)

	apply(opts.Default or min, true, true)
	return obj
end

function Elements:AddDropdown(opts)
	opts = opts or {}
	local theme = self.Theme
	local options = opts.Options or {}
	local selected = opts.Default
	local open = false
	local buttons = {}
	local obj = {}

	local card, rowH, cy = Card(self, opts, 0.45)
	card.ClipsDescendants = true
	obj.Instance = card

	local combo = Create("TextButton", {
		Size = UDim2.new(0.38, 0, 0, 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, cy),
		BackgroundColor3 = theme.Control,
		BackgroundTransparency = theme.ControlTransparency,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(combo, 4)
	Stroke(combo, theme.Stroke, 1, theme.StrokeTransparency)
	local valueLabel = NewText(combo, "", theme, {
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Font = FONT,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local arrow = NewText(combo, ">", theme, {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = theme.SubText,
		Font = FONT_BOLD,
		TextSize = 13,
		Rotation = 90,
	})

	local list = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, rowH + 2),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	List(list, 2)

	local function listHeight()
		return math.min(#options * 34, 170)
	end

	local function render()
		valueLabel.Text = selected ~= nil and tostring(selected) or "None"
		for opt, entry in pairs(buttons) do
			entry.pill.Visible = (opt == selected)
		end
	end

	local function toggle(state)
		open = state
		Tween(card, { Size = UDim2.new(1, 0, 0, open and (rowH + 10 + listHeight()) or rowH) }, 0.18)
		Tween(arrow, { Rotation = open and -90 or 90 }, 0.18)
	end

	local function build()
		for _, entry in pairs(buttons) do
			entry.button:Destroy()
		end
		table.clear(buttons)
		for _, opt in ipairs(options) do
			local button = Create("TextButton", {
				Size = UDim2.new(1, -6, 0, 32),
				BackgroundColor3 = theme.Text,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				Parent = list,
			})
			Corner(button, 4)
			NewText(button, tostring(opt), theme, {
				Size = UDim2.new(1, -24, 1, 0),
				Position = UDim2.fromOffset(14, 0),
				Font = FONT,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local pill = Create("Frame", {
				Size = UDim2.fromOffset(3, 14),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = theme.Accent,
				BorderSizePixel = 0,
				Visible = false,
				Parent = button,
			})
			Corner(pill, "pill")
			button.MouseEnter:Connect(function()
				Tween(button, { BackgroundTransparency = 0.92 }, 0.1)
			end)
			button.MouseLeave:Connect(function()
				Tween(button, { BackgroundTransparency = 1 }, 0.1)
			end)
			button.MouseButton1Click:Connect(function()
				obj:Set(opt)
				toggle(false)
			end)
			buttons[opt] = { button = button, pill = pill }
		end
		list.Size = UDim2.new(1, -16, 0, listHeight())
		if open then
			card.Size = UDim2.new(1, 0, 0, rowH + 10 + listHeight())
		end
		render()
	end

	function obj:Set(value, silent)
		selected = value
		render()
		SetFlag(opts, selected)
		if not silent then
			Safe(opts.Callback, selected)
		end
	end
	function obj:Get()
		return selected
	end
	function obj:Refresh(newOptions, keepSelection)
		options = newOptions or {}
		if not keepSelection or not table.find(options, selected) then
			selected = nil
			SetFlag(opts, nil)
		end
		build()
	end

	combo.MouseButton1Click:Connect(function()
		toggle(not open)
	end)

	build()
	SetFlag(opts, selected)
	return obj
end

function Elements:AddTextbox(opts)
	opts = opts or {}
	local theme = self.Theme
	local card, _, cy = Card(self, opts, 0.45)

	local box = Create("TextBox", {
		Size = UDim2.new(0.38, 0, 0, 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, cy),
		BackgroundColor3 = theme.Control,
		BackgroundTransparency = theme.ControlTransparency,
		BorderSizePixel = 0,
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = theme.SubText,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = FONT,
		TextSize = 13,
		ClearTextOnFocus = opts.ClearOnFocus == true,
		ClipsDescendants = true,
		Parent = card,
	})
	Corner(box, 4)
	Stroke(box, theme.Stroke, 1, theme.StrokeTransparency)
	Pad(box, 8, 0, 8, 0)
	local line = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
		Parent = box,
	})

	box.Focused:Connect(function()
		line.Visible = true
	end)
	box.FocusLost:Connect(function(enterPressed)
		line.Visible = false
		SetFlag(opts, box.Text)
		Safe(opts.Callback, box.Text, enterPressed)
	end)

	local obj = { Instance = card }
	function obj:Set(text, silent)
		box.Text = text
		SetFlag(opts, text)
		if not silent then
			Safe(opts.Callback, text, false)
		end
	end
	function obj:Get()
		return box.Text
	end
	SetFlag(opts, box.Text)
	return obj
end

function Elements:AddKeybind(opts)
	opts = opts or {}
	local theme = self.Theme
	local key = opts.Default
	local listening = false
	local card, _, cy = Card(self, opts, 0.55)

	local btn = Create("TextButton", {
		Size = UDim2.fromOffset(100, 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, cy),
		BackgroundColor3 = theme.Control,
		BackgroundTransparency = theme.ControlTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = FONT_MED,
		TextSize = 13,
		TextColor3 = theme.Text,
		Text = "",
		Parent = card,
	})
	Corner(btn, 4)
	local btnStroke = Stroke(btn, theme.Stroke, 1, theme.StrokeTransparency)

	local function render()
		btn.Text = key and key.Name or "None"
		btnStroke.Color = theme.Stroke
	end

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "Press a key..."
		btnStroke.Color = theme.Accent
	end)

	self.Window:_connect(UserInputService.InputBegan, function(input, gameProcessed)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode ~= Enum.KeyCode.Escape then
					key = input.KeyCode
					SetFlag(opts, key)
					Safe(opts.OnChanged, key)
				end
				render()
			end
		elseif not gameProcessed and key and input.KeyCode == key then
			Safe(opts.Callback, key)
		end
	end)

	local obj = { Instance = card }
	function obj:Set(newKey)
		key = newKey
		SetFlag(opts, key)
		render()
	end
	function obj:Get()
		return key
	end
	render()
	SetFlag(opts, key)
	return obj
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window:_connect(signal, fn)
	local connection = signal:Connect(fn)
	table.insert(self._conns, connection)
	return connection
end

function Window:SetVisible(visible)
	self.Visible = visible and true or false
	self.Main.Visible = self.Visible
	self._tray.Visible = not self.Visible
	if self._blur then
		self._blur.Enabled = self.Visible
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:Destroy()
	for _, connection in ipairs(self._conns) do
		connection:Disconnect()
	end
	table.clear(self._conns)
	local index = table.find(Library.Windows, self)
	if index then
		table.remove(Library.Windows, index)
	end
	if self._blur then
		self._blur:Destroy()
	end
	self.Gui:Destroy()
end

function Window:Notify(info)
	info = info or {}
	local theme = self.Theme
	local wrap = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 88),
		BackgroundTransparency = 1,
		Parent = self._notifyHolder,
	})
	local card = Create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(1, 40, 0, 0),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 0.06,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = wrap,
	})
	Corner(card, 8)
	Stroke(card, theme.Border, 1, theme.BorderTransparency)
	CreateLogo(card, 12, theme.Accent, self._logo, { Position = UDim2.fromOffset(12, 10) })
	NewText(card, self.Title, theme, {
		Size = UDim2.new(1, -40, 0, 14),
		Position = UDim2.fromOffset(32, 10),
		Font = FONT,
		TextSize = 11,
		TextColor3 = theme.SubText,
	})
	NewText(card, info.Title or "Notification", theme, {
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 28),
		Font = FONT_BOLD,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	NewText(card, info.Content or "", theme, {
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(12, 48),
		Font = FONT,
		TextSize = 13,
		TextColor3 = theme.SubText,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.25)

	local gone = false
	local function dismiss()
		if gone then
			return
		end
		gone = true
		Tween(card, { Position = UDim2.new(1, 40, 0, 0) }, 0.25)
		task.wait(0.3)
		wrap:Destroy()
	end
	card.MouseButton1Click:Connect(function()
		task.spawn(dismiss)
	end)
	task.delay(info.Duration or 4, dismiss)
end

function Window:AddTab(name)
	local theme = self.Theme

	local button = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Text,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = self._tabBar,
	})
	Corner(button, 6)
	local pill = Create("Frame", {
		Size = UDim2.fromOffset(3, 16),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
		Parent = button,
	})
	Corner(pill, "pill")
	local label = NewText(button, name or "Tab", theme, {
		Size = UDim2.new(1, -22, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		TextColor3 = theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local page = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self._pages,
	})
	List(page, 6)
	Pad(page, 8, 4, 16, 16)
	NewText(page, name or "Tab", theme, {
		Size = UDim2.new(1, 0, 0, 44),
		Font = FONT_SERIF,
		TextSize = 24,
		LayoutOrder = -1,
	})

	local tab = setmetatable({
		Container = page,
		Page = page,
		Theme = theme,
		Window = self,
		_button = button,
		_pill = pill,
		_label = label,
		_active = false,
	}, { __index = Elements })
	table.insert(self.Tabs, tab)

	function tab:Select()
		for _, other in ipairs(self.Window.Tabs) do
			local active = other == self
			other._active = active
			other.Page.Visible = active
			other._pill.Visible = active
			Tween(other._button, { BackgroundTransparency = active and 0.91 or 1 }, 0.12)
			Tween(other._label, { TextColor3 = active and theme.Text or theme.SubText }, 0.12)
		end
	end

	button.MouseEnter:Connect(function()
		if not tab._active then
			Tween(button, { BackgroundTransparency = 0.94 }, 0.1)
		end
	end)
	button.MouseLeave:Connect(function()
		if not tab._active then
			Tween(button, { BackgroundTransparency = 1 }, 0.1)
		end
	end)
	button.MouseButton1Click:Connect(function()
		tab:Select()
	end)

	if #self.Tabs == 1 then
		tab:Select()
	end
	return tab
end

function Library:CreateWindow(opts)
	opts = opts or {}
	local title = opts.Title or "Claudelib"

	local theme
	if type(opts.Theme) == "table" then
		theme = setmetatable(opts.Theme, { __index = Themes.Claude })
	else
		theme = Themes[opts.Theme or "Claude"] or Themes.Claude
	end

	local self = setmetatable({
		Title = title,
		Tabs = {},
		Theme = theme,
		Visible = true,
		_logo = opts.Logo,
		_conns = {},
	}, Window)

	local parent = opts.Parent or GetGuiParent()
	local guiName = "Claudelib_" .. title
	local old = parent:FindFirstChild(guiName)
	if old then
		old:Destroy()
	end

	local gui = Create("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		Parent = parent,
	})
	self.Gui = gui

	-- optional background blur (blurs the game world behind the translucent window)
	if opts.Blur then
		local existing = Lighting:FindFirstChild("ClaudelibBlur")
		if existing then
			existing:Destroy()
		end
		self._blur = Create("BlurEffect", {
			Name = "ClaudelibBlur",
			Size = type(opts.Blur) == "number" and opts.Blur or 14,
			Parent = Lighting,
		})
	end

	-- fit to small screens unless a size was given
	local size = opts.Size
	if not size then
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		size = UDim2.fromOffset(math.min(680, viewport.X - 24), math.min(440, viewport.Y - 24))
	end
	local navWidth = opts.NavWidth or (size.X.Offset > 0 and size.X.Offset < 560 and 124 or 176)

	-- translucent "Mica" window
	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = theme.BackgroundTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	local mainCorner = Corner(main, 8)
	Stroke(main, theme.Border, 1, theme.BorderTransparency)
	Create("UIGradient", {
		Color = ColorSequence.new(theme.Background, theme.Tint),
		Rotation = 35,
		Parent = main,
	})
	self.Main = main

	-- title bar
	local titlebar = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = main,
	})
	CreateLogo(titlebar, 16, theme.Accent, opts.Logo, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
	})
	NewText(titlebar, title, theme, {
		Size = UDim2.new(1, -200, 1, 0),
		Position = UDim2.fromOffset(36, 0),
		Font = FONT,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local dragArea = Create("Frame", {
		Size = UDim2.new(1, -134, 1, 0),
		BackgroundTransparency = 1,
		Parent = titlebar,
	})

	local function CaptionButton(index, kind)
		local btn = Create("TextButton", {
			Size = UDim2.fromOffset(40, 28),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6 - (index - 1) * 42, 0.5, 0),
			BackgroundColor3 = theme.Text,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			Parent = titlebar,
		})
		Corner(btn, 6)
		local glyph = Create("Frame", {
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Parent = btn,
		})

		local paint
		if kind == "min" then
			local line = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundColor3 = theme.Text,
				BorderSizePixel = 0,
				Parent = glyph,
			})
			paint = function(color)
				line.BackgroundColor3 = color
			end
		elseif kind == "max" then
			local outline = Stroke(glyph, theme.Text, 1, 0)
			paint = function(color)
				outline.Color = color
			end
		else
			local bars = {}
			for _, rotation in ipairs({ 45, -45 }) do
				table.insert(bars, Create("Frame", {
					Size = UDim2.fromOffset(14, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Rotation = rotation,
					BackgroundColor3 = theme.Text,
					BorderSizePixel = 0,
					Parent = glyph,
				}))
			end
			paint = function(color)
				for _, bar in ipairs(bars) do
					bar.BackgroundColor3 = color
				end
			end
		end

		btn.MouseEnter:Connect(function()
			if kind == "close" then
				btn.BackgroundColor3 = theme.Danger
				Tween(btn, { BackgroundTransparency = 0 }, 0.1)
				paint(Color3.new(1, 1, 1))
			else
				Tween(btn, { BackgroundTransparency = 0.9 }, 0.1)
			end
		end)
		btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 1 }, 0.1)
			paint(theme.Text)
		end)
		return btn
	end

	local closeBtn = CaptionButton(1, "close")
	local maxBtn = CaptionButton(2, "max")
	local minBtn = CaptionButton(3, "min")

	-- body: navigation pane + content
	local body = Create("Frame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
		Parent = main,
	})
	local nav = Create("Frame", {
		Size = UDim2.new(0, navWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local navHeader = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		Parent = nav,
	})
	CreateLogo(navHeader, 32, theme.Accent, opts.Logo, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
	})
	NewText(navHeader, title, theme, {
		Size = UDim2.new(1, -64, 0, 18),
		Position = UDim2.fromOffset(58, 12),
		Font = FONT_BOLD,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	NewText(navHeader, opts.Subtitle or ("v" .. Library.Version), theme, {
		Size = UDim2.new(1, -64, 0, 16),
		Position = UDim2.fromOffset(58, 31),
		Font = FONT,
		TextSize = 12,
		TextColor3 = theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local tabBar = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = nav,
	})
	List(tabBar, 2)
	Pad(tabBar, 8, 4, 8, 8)
	self._tabBar = tabBar

	self._pages = Create("Frame", {
		Position = UDim2.fromOffset(navWidth, 0),
		Size = UDim2.new(1, -navWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})

	-- toast notifications (bottom-right, like Windows)
	local notifyHolder = Create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 320, 1, -32),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = notifyHolder,
	})
	self._notifyHolder = notifyHolder

	-- taskbar-style tray button: shown when the window is minimized/hidden
	local tray = Create("TextButton", {
		Size = UDim2.fromOffset(52, 44),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})
	Corner(tray, 10)
	Stroke(tray, theme.Border, 1, theme.BorderTransparency)
	CreateLogo(tray, 22, theme.Accent, opts.Logo, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -3),
	})
	local indicator = Create("Frame", {
		Size = UDim2.fromOffset(14, 3),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = tray,
	})
	Corner(indicator, "pill")
	tray.MouseEnter:Connect(function()
		Tween(tray, { BackgroundTransparency = 0.04 }, 0.1)
	end)
	tray.MouseLeave:Connect(function()
		Tween(tray, { BackgroundTransparency = 0.1 }, 0.1)
	end)
	tray.MouseButton1Click:Connect(function()
		self:SetVisible(true)
	end)
	self._tray = tray

	-- maximize / restore
	local maximized = false
	local restoreSize, restorePos = size, main.Position
	maxBtn.MouseButton1Click:Connect(function()
		maximized = not maximized
		if maximized then
			restoreSize, restorePos = main.Size, main.Position
			mainCorner.CornerRadius = UDim.new(0, 0)
			Tween(main, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5) }, 0.18)
		else
			mainCorner.CornerRadius = UDim.new(0, 8)
			Tween(main, { Size = restoreSize, Position = restorePos }, 0.18)
		end
	end)
	minBtn.MouseButton1Click:Connect(function()
		self:SetVisible(false)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Destroy()
	end)

	-- dragging by the title bar
	local dragging, dragStart, startPos
	dragArea.InputBegan:Connect(function(input)
		if IsPress(input) and not maximized then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if IsPress(input) then
			dragging = false
		end
	end)

	-- toggle key
	local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
	self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == toggleKey then
			self:Toggle()
		end
	end)

	table.insert(Library.Windows, self)
	return self
end

function Library:Unload()
	for _, window in ipairs({ table.unpack(Library.Windows) }) do
		window:Destroy()
	end
	table.clear(Library.Flags)
end

return Library
