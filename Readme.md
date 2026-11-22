# Claudelib

A Windows 11 style UI library for Roblox (Luau) with the Claude color theme and a translucent window.

## Load

```lua
local Claudelib = loadstring(game:HttpGet("YOUR_RAW_URL"))()
```

## Create a window

```lua
local Window = Claudelib:CreateWindow({
    Title = "My Project",
    Subtitle = "v1.0",                    -- optional
    Theme = "Claude",                     -- "Claude" (dark), "ClaudeLight", or your own table
    ToggleKey = Enum.KeyCode.RightShift,  -- show/hide key
    Logo = nil,                           -- optional "rbxassetid://123"
    Blur = false,                         -- true blurs the game behind the window
})
```

Other options: `Size` (UDim2), `NavWidth` (number), `Parent` (Instance).

## Create tabs

Each tab appears in the left navigation pane. The first tab is selected automatically.

```lua
local General = Window:AddTab("General")
local Visuals = Window:AddTab("Visuals")
local Settings = Window:AddTab("Settings")

General:Select() -- switch to a tab from code
```

## Create sections

Sections are optional group headers inside a tab. You can add elements to a tab or to a section.

```lua
local Player = General:AddSection("Player")
local Camera = General:AddSection("Camera")
```

## Add elements

Every element (except Label) accepts `Name` and an optional `Description`.

```lua
-- Button
Player:AddButton({
    Name = "Reset",
    Description = "Resets your character",
    ButtonText = "Run",
    Callback = function() print("clicked") end,
})

-- Toggle
local toggle = Player:AddToggle({
    Name = "Enabled",
    Default = false,
    Flag = "Enabled",
    Callback = function(state) print(state) end,
})

-- Slider
Player:AddSlider({
    Name = "Speed",
    Min = 0, Max = 100, Default = 16,
    Increment = 1,
    Suffix = "",
    Flag = "Speed",
    Callback = function(value) print(value) end,
})

-- Dropdown
local mode = Player:AddDropdown({
    Name = "Mode",
    Options = { "Legit", "Balanced", "Rage" },
    Default = "Balanced",
    Flag = "Mode",
    Callback = function(value) print(value) end,
})

-- Textbox
Player:AddTextbox({
    Name = "Name",
    Placeholder = "Type here",
    Default = "",
    ClearOnFocus = false,
    Callback = function(text, enterPressed) print(text) end,
})

-- Keybind
Player:AddKeybind({
    Name = "Action",
    Default = Enum.KeyCode.E,
    Callback = function() print("key pressed") end,
    OnChanged = function(newKey) print(newKey.Name) end,
})

-- Label
local label = Player:AddLabel("Some info text")
```

## Changing elements from code

```lua
toggle:Set(true)               -- updates and fires the callback
toggle:Set(true, true)         -- updates silently (no callback)
print(toggle:Get())

mode:Refresh({ "A", "B", "C" }) -- replace dropdown options
label:Set("New text")
```

Toggle, Slider, Dropdown, Textbox and Keybind all have `:Set()` and `:Get()`. Buttons have `:SetText()`.

## Flags

Elements with a `Flag` save their value here automatically:

```lua
print(Claudelib.Flags.Enabled)
print(Claudelib.Flags.Speed)
```

## Notifications

```lua
Window:Notify({
    Title = "Loaded",
    Content = "Claudelib is ready",
    Duration = 4,
})
```

Toasts appear bottom-right. Tap one to dismiss it early.

## Window controls

```lua
Window:SetVisible(false) -- hide (the taskbar icon appears at the bottom center)
Window:Toggle()
Window:Destroy()
Claudelib:Unload()       -- removes every window
```

The title bar has minimize, maximize and close buttons. Minimize hides the window and shows the tray icon. Click the icon, or press the toggle key, to bring it back.