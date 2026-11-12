--[[
	YourBae UI Library
	UI saja (tanpa fitur search), bisa dipakai lewat loadstring.

	local Library = loadstring(game:HttpGet("URL_RAW_FILE_INI"))()
	local Window  = Library:CreateWindow({ Name = "YourBae", Logo = "YB", ToggleKey = Enum.KeyCode.RightShift })
	local Tab     = Window:AddTab({ Name = "Main", Icon = "🏠" })
	local Section = Tab:AddSection({ Name = "Overview", Side = "Left" })

	Section:AddLabel("STATUS")
	Section:AddInfo({ Name = "Status", Value = "Idle" })
	Section:AddToggle({ Name = "Contoh Toggle", Default = false, Flag = "demo", Callback = function(v) end })
	Section:AddSlider({ Name = "Contoh Slider", Min = 0, Max = 10, Default = 5, Increment = 1, Callback = function(v) end })
	Section:AddDropdown({ Name = "Zone", Options = {"A", "B"}, Default = "A", Callback = function(v) end })
	Section:AddButton({ Name = "Klik", Callback = function() end })
	Section:AddTextbox({ Name = "Input", Default = "", Placeholder = "ketik...", Callback = function(t) end })
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Library = {}

local Theme = {
	Background = Color3.fromRGB(11, 21, 16),
	Sidebar = Color3.fromRGB(8, 16, 12),
	Card = Color3.fromRGB(17, 31, 24),
	CardHeader = Color3.fromRGB(24, 43, 33),
	Stroke = Color3.fromRGB(34, 60, 47),
	Accent = Color3.fromRGB(52, 190, 115),
	Text = Color3.fromRGB(224, 240, 231),
	SubText = Color3.fromRGB(122, 150, 136),
	Field = Color3.fromRGB(9, 18, 14),
	Active = Color3.fromRGB(26, 48, 37),
	Track = Color3.fromRGB(30, 54, 42),
}

---------------------------------------------------------------------
-- Helper
---------------------------------------------------------------------
local function Create(className, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(r)
	return Create("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function Stroke(color, thickness, transparency)
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Padding(t, r, b, l)
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
	})
end

local function Tween(obj, time, props)
	TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function SafeCall(fn, ...)
	if type(fn) == "function" then
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[YourBaeUI] " .. tostring(err))
		end
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

-- Logo gambar: bisa "rbxassetid://ID", angka ID saja, atau link PNG (https://...).
-- Link PNG hanya jalan di executor yang punya writefile + getcustomasset.
local function ResolveImage(src)
	if type(src) ~= "string" or src == "" then
		return nil
	end
	if src:match("^https?://") then
		local getAsset = getcustomasset or getsynasset
		if writefile and isfile and getAsset then
			local ok, asset = pcall(function()
				local sum = 0
				for i = 1, #src do
					sum = (sum * 31 + src:byte(i)) % 1000000007
				end
				local file = "YourBae_logo_" .. tostring(sum) .. ".png"
				if not isfile(file) then
					writefile(file, game:HttpGet(src))
				end
				return getAsset(file)
			end)
			if ok and asset then
				return asset
			end
		end
		return nil
	end
	if src:match("^%d+$") then
		return "rbxassetid://" .. src
	end
	return src
end

local function GetGuiParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then
		return ui
	end
	local writable = pcall(function()
		local f = Instance.new("Folder")
		f.Parent = CoreGui
		f:Destroy()
	end)
	if writable then
		return CoreGui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function MakeDraggable(handle, target, conns)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if IsPress(input) then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and IsMove(input) then
			local d = input.Position - dragStart
			local ps = target.Parent and target.Parent.AbsoluteSize or Vector2.new(1920, 1080)
			target.Position = UDim2.new(
				startPos.X.Scale + d.X / math.max(ps.X, 1), startPos.X.Offset,
				startPos.Y.Scale + d.Y / math.max(ps.Y, 1), startPos.Y.Offset
			)
		end
	end))
end

-- Ikon vektor: garis/bentuk transparan, warna bisa diubah lewat :SetColor()
-- Nama ikon: home, grid, users, user, shop, gear, eye, pin, target, star, list, dots
-- Juga bisa "rbxassetid://ID" (gambar) atau teks/emoji biasa.
local function MakeIcon(parent, icon, color, pos)
	icon = icon or ""
	local obj = {}
	local parts = {}
	local holder = Create("Frame", {
		Position = pos or UDim2.new(0, 0, 0, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	obj.Holder = holder

	local function Box(x, y, w, h, o)
		o = o or {}
		local f = Create("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = o.fill and 0 or 1,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = o.rot or 0,
			Parent = o.parent or holder,
		})
		if o.round then
			Create("UICorner", {
				CornerRadius = (o.round == "full") and UDim.new(0.5, 0) or UDim.new(0, o.round),
				Parent = f,
			})
		end
		if o.fill then
			table.insert(parts, { f, "BackgroundColor3" })
		else
			local s = Stroke(color, 1.6)
			s.Parent = f
			table.insert(parts, { s, "Color" })
		end
		return f
	end
	local function Clip(x, y, w, h)
		return Create("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = holder,
		})
	end

	local builders = {
		home = function()
			Box(0.5, 5, 11, 2, { fill = true, round = 1, rot = -45 })
			Box(8.5, 5, 11, 2, { fill = true, round = 1, rot = 45 })
			Box(4, 10, 12, 7, { round = 2 })
			Box(8.5, 12.5, 3, 4.5, { fill = true, round = 1 })
		end,
		grid = function()
			Box(2, 2, 7, 7, { round = 2 })
			Box(11, 2, 7, 7, { round = 2 })
			Box(2, 11, 7, 7, { round = 2 })
			Box(11, 11, 7, 7, { round = 2 })
		end,
		user = function()
			Box(6, 1.5, 8, 8, { round = "full" })
			local c = Clip(0, 12, 20, 8)
			Box(3, 0, 14, 14, { round = "full", parent = c })
		end,
		users = function()
			Box(3, 2, 7, 7, { round = "full" })
			local c = Clip(0, 11, 13, 9)
			Box(1, 0, 11, 12, { round = "full", parent = c })
			Box(12, 4, 5.5, 5.5, { round = "full" })
			local c2 = Clip(11, 12, 9, 8)
			Box(1, 0, 9, 11, { round = "full", parent = c2 })
		end,
		shop = function()
			Box(2, 3, 16, 5, { fill = true, round = 1 })
			Box(4, 8, 12, 9, { round = 1 })
			Box(8, 12, 4, 5, { fill = true, round = 1 })
		end,
		gear = function()
			for i = 0, 7 do
				local c = Create("Frame", {
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					Rotation = i * 45,
					Parent = holder,
				})
				Box(8.5, 0.5, 3, 4, { fill = true, round = 1, parent = c })
			end
			Box(4, 4, 12, 12, { round = "full" })
			Box(8, 8, 4, 4, { fill = true, round = "full" })
		end,
		eye = function()
			Box(1, 5, 18, 10, { round = "full" })
			Box(7.5, 7.5, 5, 5, { fill = true, round = "full" })
		end,
		pin = function()
			Box(4, 1, 12, 12, { round = "full" })
			Box(8.5, 5.5, 3, 3, { fill = true, round = "full" })
			Box(9, 13, 2, 5, { fill = true, round = 1 })
		end,
		target = function()
			Box(2, 2, 16, 16, { round = "full" })
			Box(6, 6, 8, 8, { round = "full" })
			Box(9, 9, 2, 2, { fill = true, round = "full" })
		end,
		star = function()
			Box(4, 4, 12, 12, { round = 1 })
			Box(4, 4, 12, 12, { round = 1, rot = 45 })
		end,
		list = function()
			for i = 0, 2 do
				Box(2, 4 + i * 5, 2.5, 2.5, { fill = true, round = "full" })
				Box(7, 4.25 + i * 5, 11, 2, { fill = true, round = 1 })
			end
		end,
		dots = function()
			Box(2, 8.5, 3, 3, { fill = true, round = "full" })
			Box(8.5, 8.5, 3, 3, { fill = true, round = "full" })
			Box(15, 8.5, 3, 3, { fill = true, round = "full" })
		end,
	}

	local build = builders[icon]
	if build then
		build()
	elseif icon:find("rbxassetid://") then
		local img = Create("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = icon,
			ImageColor3 = color,
			Parent = holder,
		})
		table.insert(parts, { img, "ImageColor3" })
	else
		local t = Create("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = icon,
			Font = Enum.Font.GothamMedium,
			TextSize = 16,
			TextColor3 = color,
			Parent = holder,
		})
		table.insert(parts, { t, "TextColor3" })
	end

	function obj:SetColor(c)
		for _, p in ipairs(parts) do
			p[1][p[2]] = c
		end
	end
	function obj:Destroy()
		holder:Destroy()
	end
	return obj
end

-- Panah (chevron) vektor. Rotation 0 = bawah, 180 = atas, -90 = kanan
local function Chevron(parent, color, pos)
	local h = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Create("Frame", {
		Position = UDim2.fromOffset(2, 7.5),
		Size = UDim2.fromOffset(7, 2),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = 45,
		Parent = h,
	}, { Corner(1) })
	Create("Frame", {
		Position = UDim2.fromOffset(7, 7.5),
		Size = UDim2.fromOffset(7, 2),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = -45,
		Parent = h,
	}, { Corner(1) })
	return h
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------
function Library:CreateWindow(opts)
	opts = opts or {}
	local name = opts.Name or "YourBae"
	local logoText = opts.Logo or "YB"
	local logoImage = ResolveImage(opts.LogoImage)
	local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift

	local Window = { Tabs = {}, Flags = {}, CurrentTab = nil }
	local conns = {}

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(opts.Scale or 0.8, 0.5, 1.5) -- makin kecil = UI makin kecil
	local width = math.clamp(vp.X / scale - 20, 360, 660)
	local height = math.clamp(vp.Y / scale - 20, 280, 450)
	local sidebarW = width < 520 and 130 or 180

	-- hapus UI lama jika di-execute ulang
	local parent = GetGuiParent()
	local old = parent:FindFirstChild("YourBaeUI")
	if old then
		old:Destroy()
	end

	local Gui = Create("ScreenGui", {
		Name = "YourBaeUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	})
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(Gui)
		end
	end)
	Gui.Parent = parent
	Window.Gui = Gui

	local Main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = Gui,
	}, { Corner(10), Stroke(Theme.Stroke, 1) })
	local UiScale = Create("UIScale", { Scale = scale, Parent = Main })

	-- Sidebar ---------------------------------------------------------
	local Sidebar = Create("Frame", {
		Size = UDim2.new(0, sidebarW, 1, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = Main,
	}, { Corner(10) })
	Create("Frame", { -- meratakan sisi kanan sidebar
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 12, 1, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = Sidebar,
	})
	Create("Frame", { -- garis pemisah
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = Sidebar,
	})

	local LogoArea = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundTransparency = 1,
		Parent = Sidebar,
	})
	local Logo = Create("Frame", {
		Position = UDim2.new(0, 16, 0, 18),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Parent = LogoArea,
	}, { Corner(11), Stroke(Theme.Accent, (opts.LogoBorder == false) and 0 or 3) })
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = logoText,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = Theme.Accent,
		Visible = not logoImage,
		Parent = Logo,
	})
	if logoImage then
		local inset = (opts.LogoBorder == false) and 0 or 4
		Create("ImageLabel", {
			Position = UDim2.new(0, inset, 0, inset),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			BackgroundTransparency = 1,
			Image = logoImage,
			ScaleType = Enum.ScaleType.Crop,
			Parent = Logo,
		}, { Corner(8) })
	end
	Create("TextLabel", {
		Position = UDim2.new(0, 66, 0, 18),
		Size = UDim2.new(1, -72, 0, 40),
		BackgroundTransparency = 1,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = LogoArea,
	})

	local TabList = Create("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 80),
		Size = UDim2.new(1, -20, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = Sidebar,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = TabList,
	})

	-- Konten ----------------------------------------------------------
	local Content = Create("Frame", {
		Position = UDim2.new(0, sidebarW + 1, 0, 0),
		Size = UDim2.new(1, -(sidebarW + 1), 1, 0),
		BackgroundTransparency = 1,
		Parent = Main,
	})

	local Header = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		Parent = Content,
	})
	local HeaderIcon = nil
	local Title = Create("TextLabel", {
		Position = UDim2.new(0, 56, 0, 0),
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 21,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = Header,
	})
	local Collapse = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Text = "—",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		Parent = Header,
	}, { Corner(8) })
	Collapse.MouseEnter:Connect(function()
		Tween(Collapse, 0.15, { TextColor3 = Theme.Accent, BackgroundTransparency = 0, BackgroundColor3 = Theme.Active })
	end)
	Collapse.MouseLeave:Connect(function()
		Tween(Collapse, 0.15, { TextColor3 = Theme.SubText, BackgroundTransparency = 1 })
	end)

	local Pages = Create("Frame", {
		Position = UDim2.new(0, 20, 0, 66),
		Size = UDim2.new(1, -40, 1, -82),
		BackgroundTransparency = 1,
		Parent = Content,
	})

	-- Tombol mengambang saat UI disembunyikan ------------------------
	local Floating = Create("TextButton", {
		Position = UDim2.new(0, 24, 0.5, -23),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Theme.Background,
		Text = logoText,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = Theme.Accent,
		AutoButtonColor = false,
		Visible = false,
		Parent = Gui,
	}, { Corner(12), Stroke(Theme.Accent, 2.5) })
	if logoImage then
		Floating.Text = ""
		Create("ImageLabel", {
			Position = UDim2.new(0, 4, 0, 4),
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundTransparency = 1,
			Image = logoImage,
			ScaleType = Enum.ScaleType.Crop,
			Parent = Floating,
		}, { Corner(9) })
	end

	function Window:Toggle(state)
		if state == nil then
			state = not Main.Visible
		end
		Main.Visible = state
		Floating.Visible = not state
	end

	Collapse.MouseButton1Click:Connect(function()
		Window:Toggle(false)
	end)
	Floating.MouseButton1Click:Connect(function()
		Window:Toggle(true)
	end)

	MakeDraggable(Header, Main, conns)
	MakeDraggable(LogoArea, Main, conns)
	MakeDraggable(Floating, Floating, conns)

	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == toggleKey then
			Window:Toggle()
		end
	end))

	function Window:SetScale(n)
		UiScale.Scale = math.clamp(tonumber(n) or scale, 0.5, 1.5)
	end

	function Window:Destroy()
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		Gui:Destroy()
	end

	-- Tab -------------------------------------------------------------
	function Window:SelectTab(tab)
		for _, t in ipairs(self.Tabs) do
			local on = (t == tab)
			t._page.Visible = on
			Tween(t._btn, 0.15, { BackgroundTransparency = on and 0 or 1 })
			t._name.TextColor3 = on and Theme.Text or Theme.SubText
			t._icon:SetColor(on and Theme.Accent or Theme.SubText)
		end
		Title.Text = tab.Name
		if HeaderIcon then
			HeaderIcon:Destroy()
		end
		HeaderIcon = MakeIcon(Header, tab.Icon, Theme.Accent, UDim2.new(0, 20, 0.5, -10))
		self.CurrentTab = tab
	end

	function Window:AddTab(o)
		o = type(o) == "string" and { Name = o } or o or {}
		local Tab = { Name = o.Name or "Tab", Icon = o.Icon or "•" }

		local Btn = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Theme.Active,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = #self.Tabs + 1,
			Parent = TabList,
		}, { Corner(8) })
		local TabIcon = MakeIcon(Btn, Tab.Icon, Theme.SubText, UDim2.new(0, 12, 0.5, -10))
		local NameLbl = Create("TextLabel", {
			Position = UDim2.new(0, 44, 0, 0),
			Size = UDim2.new(1, -50, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = Tab.Name,
			Parent = Btn,
		})

		local Page = Create("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = Pages,
		})
		local function Column(pos, size)
			local sf = Create("ScrollingFrame", {
				Position = pos,
				Size = size,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Theme.Stroke,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Parent = Page,
			})
			Create("UIListLayout", {
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = sf,
			})
			return sf
		end
		local Left = Column(UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -6, 1, 0))
		local Right = Column(UDim2.new(0.5, 6, 0, 0), UDim2.new(0.5, -6, 1, 0))

		Tab._btn, Tab._name, Tab._page = Btn, NameLbl, Page
		Tab._icon = TabIcon

		table.insert(self.Tabs, Tab)
		Btn.MouseButton1Click:Connect(function()
			Window:SelectTab(Tab)
		end)
		if #self.Tabs == 1 then
			Window:SelectTab(Tab)
		end

		-- Section -----------------------------------------------------
		function Tab:AddSection(so)
			so = type(so) == "string" and { Name = so } or so or {}
			local col = (so.Side == "Right") and Right or Left
			local Section = {}

			local Card = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Card,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = col,
			}, { Corner(8), Stroke(Theme.Stroke, 1) })
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = Card })

			-- Default: header biasa (tanpa minimize). Isi Collapsible = true kalau mau bisa dilipat.
			local headProps = {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = Theme.CardHeader,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Parent = Card,
			}
			if so.Collapsible then
				headProps.AutoButtonColor = false
				headProps.Text = ""
			end
			local Head = Create(so.Collapsible and "TextButton" or "Frame", headProps)
			local titleX = 16
			if so.Icon then
				MakeIcon(Head, so.Icon, Theme.Accent, UDim2.new(0, 14, 0.5, -10))
				titleX = 44
			end
			Create("TextLabel", {
				Position = UDim2.new(0, titleX, 0, 0),
				Size = UDim2.new(1, -titleX - 44, 1, 0),
				BackgroundTransparency = 1,
				Text = so.Name or "Section",
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = Head,
			})
			local Body = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Parent = Card,
			}, { Padding(14, 16, 16, 16) })
			Create("UIListLayout", {
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = Body,
			})

			if so.Collapsible then
				local Arrow = Chevron(Head, Theme.SubText, UDim2.new(1, -24, 0.5, 0))
				Head.MouseButton1Click:Connect(function()
					Body.Visible = not Body.Visible
					Arrow.Rotation = Body.Visible and 0 or -90
				end)
			end

			-- Label kecil (judul grup, mis. "STATUS")
			function Section:AddLabel(text)
				local L = Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					Text = tostring(text),
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextColor3 = Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = Body,
				})
				local obj = {}
				function obj:Set(t)
					L.Text = tostring(t)
				end
				return obj
			end

			-- Baris info: nama di kiri, nilai di kanan
			function Section:AddInfo(io)
				io = io or {}
				local Row = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					Parent = Body,
				})
				Create("TextLabel", {
					Size = UDim2.new(0.4, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = io.Name or "",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = Row,
				})
				local Val = Create("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.new(0.6, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = tostring(io.Value or ""),
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = Row,
				})
				local obj = {}
				function obj:Set(v)
					Val.Text = tostring(v)
				end
				return obj
			end

			-- Toggle
			function Section:AddToggle(to)
				to = to or {}
				local state = to.Default and true or false
				local Row = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					Parent = Body,
				})
				Create("TextLabel", {
					Size = UDim2.new(1, -60, 1, 0),
					BackgroundTransparency = 1,
					Text = to.Name or "Toggle",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = Row,
				})
				local Switch = Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(46, 26),
					BackgroundColor3 = Theme.Track,
					Parent = Row,
				}, { Corner(13) })
				local Knob = Create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 4, 0.5, 0),
					Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = Theme.SubText,
					Parent = Switch,
				}, { Corner(9) })
				local Click = Create("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					Parent = Row,
				})

				local function Render(animate)
					local t = animate and 0.15 or 0
					Tween(Switch, t, { BackgroundColor3 = state and Theme.Accent or Theme.Track })
					Tween(Knob, t, {
						Position = state and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
						BackgroundColor3 = state and Theme.Sidebar or Theme.SubText,
					})
				end
				local obj = {}
				function obj:Set(v, silent)
					state = v and true or false
					Render(true)
					if to.Flag then
						Window.Flags[to.Flag] = state
					end
					if not silent then
						SafeCall(to.Callback, state)
					end
				end
				function obj:Get()
					return state
				end
				Click.MouseButton1Click:Connect(function()
					obj:Set(not state)
				end)
				Render(false)
				if to.Flag then
					Window.Flags[to.Flag] = state
				end
				return obj
			end

			-- Slider (dengan kotak angka)
			function Section:AddSlider(sl)
				sl = sl or {}
				local min, max = sl.Min or 0, sl.Max or 100
				local inc = sl.Increment or 1
				local decimals = 0
				do
					local s = string.format("%.10g", inc)
					local dot = s:find("%.")
					if dot then
						decimals = #s - dot
					end
				end
				local fmt = "%." .. decimals .. "f"
				local value = math.clamp(sl.Default or min, min, max)

				local Row = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 58),
					BackgroundTransparency = 1,
					Parent = Body,
				})
				Create("TextLabel", {
					Size = UDim2.new(1, -70, 0, 32),
					BackgroundTransparency = 1,
					Text = sl.Name or "Slider",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = Row,
				})
				local Box = Create("TextBox", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(56, 32),
					BackgroundColor3 = Theme.Field,
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Accent,
					ClearTextOnFocus = false,
					Text = "",
					Parent = Row,
				}, { Corner(6), Stroke(Theme.Stroke, 1) })
				local Track = Create("Frame", {
					Position = UDim2.new(0, 0, 0, 44),
					Size = UDim2.new(1, 0, 0, 6),
					BackgroundColor3 = Theme.Track,
					Parent = Row,
				}, { Corner(3) })
				local Fill = Create("Frame", {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = Theme.Accent,
					BorderSizePixel = 0,
					Parent = Track,
				}, { Corner(3) })
				local Knob = Create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = Theme.Accent,
					Parent = Track,
				}, { Corner(7) })
				local Hit = Create("TextButton", {
					Position = UDim2.new(0, 0, 0, 34),
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					Text = "",
					Parent = Row,
				})

				local obj = {}
				local function Apply(v, silent)
					v = math.clamp(v, min, max)
					v = math.floor((v - min) / inc + 0.5) * inc + min
					v = tonumber(string.format(fmt, v)) or min
					v = math.clamp(v, min, max)
					local changed = (v ~= value)
					value = v
					local a = (max - min) == 0 and 0 or (v - min) / (max - min)
					Fill.Size = UDim2.new(a, 0, 1, 0)
					Knob.Position = UDim2.new(a, 0, 0.5, 0)
					Box.Text = string.format(fmt, v)
					if sl.Flag then
						Window.Flags[sl.Flag] = v
					end
					if changed and not silent then
						SafeCall(sl.Callback, v)
					end
				end
				function obj:Set(v, silent)
					Apply(tonumber(v) or value, silent)
				end
				function obj:Get()
					return value
				end

				local dragging = false
				local function FromInput(input)
					local a = math.clamp((input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
					Apply(min + (max - min) * a)
				end
				Hit.InputBegan:Connect(function(input)
					if IsPress(input) then
						dragging = true
						FromInput(input)
					end
				end)
				table.insert(conns, UserInputService.InputChanged:Connect(function(input)
					if dragging and IsMove(input) then
						FromInput(input)
					end
				end))
				table.insert(conns, UserInputService.InputEnded:Connect(function(input)
					if IsPress(input) then
						dragging = false
					end
				end))
				Box.FocusLost:Connect(function()
					local n = tonumber(Box.Text)
					if n then
						Apply(n)
					else
						Box.Text = string.format(fmt, value)
					end
				end)

				Apply(value, true)
				return obj
			end

			-- Dropdown
			function Section:AddDropdown(dd)
				dd = dd or {}
				local options = dd.Options or {}
				local selected = dd.Default or options[1]
				local open = false

				local Holder = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Parent = Body,
				})
				Create("UIListLayout", {
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = Holder,
				})
				if dd.Name then
					Create("TextLabel", {
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = dd.Name,
						Font = Enum.Font.GothamMedium,
						TextSize = 13,
						TextColor3 = Theme.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
						Parent = Holder,
					})
				end
				local Field = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundColor3 = Theme.Field,
					AutoButtonColor = false,
					Text = "",
					LayoutOrder = 2,
					Parent = Holder,
				}, { Corner(8), Stroke(Theme.Stroke, 1) })
				local Current = Create("TextLabel", {
					Position = UDim2.new(0, 14, 0, 0),
					Size = UDim2.new(1, -44, 1, 0),
					BackgroundTransparency = 1,
					Text = tostring(selected or ""),
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = Field,
				})
				local Arrow = Chevron(Field, Theme.SubText, UDim2.new(1, -22, 0.5, 0))
				local List = Create("ScrollingFrame", {
					Size = UDim2.new(1, 0, 0, 0),
					BackgroundColor3 = Theme.Field,
					BorderSizePixel = 0,
					ScrollBarThickness = 2,
					ScrollBarImageColor3 = Theme.Stroke,
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					Visible = false,
					LayoutOrder = 3,
					Parent = Holder,
				}, { Corner(8), Stroke(Theme.Stroke, 1) })
				Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = List })

				local obj = {}
				local function Close()
					open = false
					List.Visible = false
					Arrow.Rotation = 0
				end
				local function Build()
					for _, c in ipairs(List:GetChildren()) do
						if c:IsA("TextButton") then
							c:Destroy()
						end
					end
					for i, opt in ipairs(options) do
						local b = Create("TextButton", {
							Size = UDim2.new(1, 0, 0, 32),
							BackgroundTransparency = 1,
							Text = tostring(opt),
							Font = Enum.Font.GothamMedium,
							TextSize = 13,
							TextColor3 = (opt == selected) and Theme.Accent or Theme.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							AutoButtonColor = false,
							LayoutOrder = i,
							Parent = List,
						}, { Padding(0, 10, 0, 14) })
						b.MouseButton1Click:Connect(function()
							obj:Set(opt)
							Close()
						end)
					end
					List.Size = UDim2.new(1, 0, 0, math.min(math.max(#options, 1), 5) * 32)
				end
				function obj:Set(v, silent)
					selected = v
					Current.Text = tostring(v or "")
					if dd.Flag then
						Window.Flags[dd.Flag] = v
					end
					Build()
					if not silent then
						SafeCall(dd.Callback, v)
					end
				end
				function obj:Get()
					return selected
				end
				function obj:Refresh(newOptions, keep)
					options = newOptions or {}
					if not keep or not table.find(options, selected) then
						selected = options[1]
						Current.Text = tostring(selected or "")
					end
					Build()
				end
				Field.MouseButton1Click:Connect(function()
					open = not open
					List.Visible = open
					Arrow.Rotation = open and 180 or 0
				end)

				if dd.Flag then
					Window.Flags[dd.Flag] = selected
				end
				Build()
				return obj
			end

			-- Button
			function Section:AddButton(bo)
				bo = type(bo) == "string" and { Name = bo } or bo or {}
				local B = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundColor3 = Theme.Field,
					AutoButtonColor = false,
					Text = bo.Name or "Button",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Text,
					Parent = Body,
				}, { Corner(8), Stroke(Theme.Stroke, 1) })
				B.MouseEnter:Connect(function()
					Tween(B, 0.15, { BackgroundColor3 = Theme.Active, TextColor3 = Theme.Accent })
				end)
				B.MouseLeave:Connect(function()
					Tween(B, 0.15, { BackgroundColor3 = Theme.Field, TextColor3 = Theme.Text })
				end)
				B.MouseButton1Click:Connect(function()
					SafeCall(bo.Callback)
				end)
				return B
			end

			-- Textbox
			function Section:AddTextbox(tb)
				tb = tb or {}
				local Holder = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Parent = Body,
				})
				Create("UIListLayout", {
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = Holder,
				})
				if tb.Name then
					Create("TextLabel", {
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = tb.Name,
						Font = Enum.Font.GothamMedium,
						TextSize = 13,
						TextColor3 = Theme.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
						Parent = Holder,
					})
				end
				local Input = Create("TextBox", {
					Size = UDim2.new(1, 0, 0, 38),
					BackgroundColor3 = Theme.Field,
					Text = tb.Default or "",
					PlaceholderText = tb.Placeholder or "",
					PlaceholderColor3 = Theme.SubText,
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					LayoutOrder = 2,
					Parent = Holder,
				}, { Corner(8), Stroke(Theme.Stroke, 1), Padding(0, 12, 0, 14) })
				local obj = {}
				function obj:Set(t)
					Input.Text = tostring(t)
				end
				function obj:Get()
					return Input.Text
				end
				Input.FocusLost:Connect(function()
					if tb.Flag then
						Window.Flags[tb.Flag] = Input.Text
					end
					SafeCall(tb.Callback, Input.Text)
				end)
				return obj
			end

			return Section
		end

		return Tab
	end

	return Window
end

return Library
