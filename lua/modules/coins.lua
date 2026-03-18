coins = {}

local loc = require("localize")

local STORE_ITEM_HEIGHT = 125
local STORE_ITEM_WIDTH = 125

local storeItemCellQuadDataTop = nil
local storeItemCellQuadDataBottom = nil

-- Creates modal content to present user coins.
-- (should be used to create or pushed within modal)
coins.createModalContent = function(_, config)
	local refresh = nil
	local requests = {}
	local function cancelRequests()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
	end

	local theme = require("uitheme").current
	local modal = require("modal")
	local bundle = require("bundle")
	local api = require("api")
	local sfx = require("sfx")

	-- default config
	local _config = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	if config then
		for k, v in pairs(_config) do
			if type(config[k]) == type(v) then
				_config[k] = config[k]
			end
		end
	end

	local ui = _config.uikit

	local content = modal:createContent()
	content.closeButton = true
	content.title = loc("Bank Account")
	content.icon = Data:FromBundle("images/icon-blux.png")

	local node = ui:createFrame()
	content.node = node

	local balanceFrame = ui:frameTextBackground()
	balanceFrame:setParent(node)
	local balanceText = ui:createText(loc("Balance"), { color = Color.White, size = "small" })
	balanceText:setParent(balanceFrame)

	local coinShape = ui:frame()
	coinShape:setParent(balanceFrame)

	Object:Load(Data:FromBundle("shapes/blux.glb"), function(o)
		o.IsUnlit = true
		local s = ui:createShape(o, { spherized = false })
		local coinSize = 60
		s.Width = coinSize
		s.Height = coinSize
		s:setParent(balanceFrame)
		o.Tick = function(o, dt)
			o.LocalRotation.Y += dt * 2
		end
		s.pos = coinShape.pos
		coinShape:remove()
		coinShape = s
	end)

	local amountText = ui:createText("-", { 
		color = Color(253, 222, 44), 
		size = "big", 
		outline = 0.4,
		outlineColor = Color.Black,
		bold = true,
		-- font = Font.Pixel 
	})
	amountText:setParent(balanceFrame)

	local grantedText = ui:createText(string.format(loc("grants: -")), { color = Color(252, 167, 27), size = "small" })
	grantedText.object.Scale = 0.7
	grantedText:setParent(balanceFrame)

	local purchasedText = ui:createText(string.format(loc("purchased: -")), { color = Color(252, 167, 27), size = "small" })
	purchasedText.object.Scale = 0.7
	purchasedText:setParent(balanceFrame)

	local earnedText = ui:createText(string.format(loc("earned: -")), { color = Color(252, 167, 27), size = "small" })
	earnedText.object.Scale = 0.7
	earnedText:setParent(balanceFrame)

	local historyFrame = ui:frameTextBackground()
	historyFrame:setParent(node)
	local historyText = ui:createText(loc("History"), { color = Color.White, size = "small" })
	historyText:setParent(historyFrame)

	local loadedTransactions = {}
	local nbLoadedTransactions = 0

	local recycledCells = {}

	local function transactionCellParentDidResize(self)
		self.Width = self.parent.Width
		self.icon.Height = self.op.Height * 1.2
		self.icon.Width = self.icon.Height
		
		self.description.object.MaxWidth = self.parent.Width - self.op.Width - self.icon.Width - theme.padding - theme.paddingBig * 3

		self.icon.pos = {
			theme.paddingBig,
			self.Height * 0.5 - self.icon.Height * 0.5,
		}

		self.op.pos = {
			self.icon.pos.X + self.icon.Width + theme.padding,
			self.Height * 0.5 - self.op.Height * 0.5,
		}

		self.description.pos = {
			self.Width - self.description.Width - theme.paddingBig,
			self.Height * 0.5 - self.description.Height * 0.5,
		}
	end

	local function getTransactionCell(transaction)
		local c = table.remove(recycledCells)
		if c == nil then
			c = ui:frameScrollCell()
			c.icon = ui:frame({
				image = {
					data = Data:FromBundle("images/icon-blux.png"),
					alpha = true,
				},
			})
			c.icon:setParent(c)
			c.op = ui:createText("", { color = Color.White, size = "small" })
			c.op:setParent(c)
			c.description = ui:createText("", { color = Color(150, 150, 150), size = "small" })
			c.description:setParent(c)
			c.parentDidResize = transactionCellParentDidResize
		end
		if transaction.amount > 0 then
			c.op.Color = theme.colorPositive
			c.op.Text = string.format("⬅️ %d", transaction.amount)
		else
			c.op.Color = theme.colorNegative
			c.op.Text = string.format("➡️ %d", -transaction.amount)
		end
		c.description.Text = transaction.info.description or transaction.info.reason or ""
		c.Height = 45
		return c
	end

	local function recycleTransactionCell(cell)
		cell:setParent(nil)
		table.insert(recycledCells, cell)
	end

	local scroll = ui:scroll({
		padding = {
			top = 0,
			bottom = theme.padding,
			left = 0,
			right = 0,
		},
		cellPadding = theme.padding,
		loadCell = function(index)
			if index <= nbLoadedTransactions then
				local c = getTransactionCell(loadedTransactions[index])
				return c
			end
		end,
		unloadCell = function(_, cell)
			recycleTransactionCell(cell)
		end,
	})
	scroll:setParent(historyFrame)

	local packs = {
		{
			price = "-",
			coins = 160,
			icon = "images/coins-pack-1.png",
            productID = "blip.coins.1",
		},
		{
			price = "-",
			coins = 800,
			icon = "images/coins-pack-2.png",
			productID = "blip.coins.2",
		},
		{
			price = "-",
			coins = 1600,
			icon = "images/coins-pack-3.png",
			productID = "blip.coins.3",
		},
		-- {
		-- 	subscription = true,	
		-- 	price = 9.99,
		-- 	coins = 2000,
		-- 	icon = "images/coins-pack-premium.png",
		-- },
		{
			price = "-",
			coins = 3200,
			icon = "images/coins-pack-4.png",
			productID = "blip.coins.4",
		},
		{
			price = "-",
			coins = 8000,
			icon = "images/coins-pack-5.png",
			productID = "blip.coins.5",
		},
		{
			price = "-",
			coins = 16000,
			icon = "images/coins-pack-6.png",
			productID = "blip.coins.6",	
		},
		{
			price = "-",
			coins = 32000,
			icon = "images/coins-pack-7.png",
			productID = "blip.coins.7",
		}
	}
	local packCells = {}

	local packsScroll = nil

	if System.IAPIsAvailable then

		-- retrieve prices from App Store and update cells
		System:IAPProducts(function(products)
			for i, p in ipairs(packs) do
				local product = products[p.productID]
				if product then
					p.price = product.displayPrice
					local cell = packCells[i]
					if cell then
						local txt
						if p.subscription then
							txt = string.format("%s/mo", p.price)
						else
							txt = string.format("%s", p.price)
						end
						cell.price.Text = txt
						cell.price.pos.X = STORE_ITEM_WIDTH * 0.5 - cell.price.Width * 0.5
					end
				end
			end
		end)

		packsScroll = ui:scroll({
			padding = {
				top = 0,
				bottom = 0,
				left = 0,
				right = 0,
			},
			direction = "right",
			-- backgroundColor = Color(200, 200, 200),
			cellPadding = theme.padding,
			loadCell = function(index)
				if index <= #packs then
					local c = packCells[index]
					if c == nil then
						-- c = ui:frameScrollCell()

						c = ui:frame()

						if storeItemCellQuadDataTop == nil then
							storeItemCellQuadDataTop = Data:FromBundle("images/store-item-top.png")
						end
						if storeItemCellQuadDataBottom == nil then
							storeItemCellQuadDataBottom = Data:FromBundle("images/store-item-bottom.png")
						end
						local topBackground = ui:frame({
							image = {
								data = storeItemCellQuadDataTop,
								slice9 = { 0.5, 0.5 },
								slice9Scale = 1.0,
								slice9Width = 20,
								alpha = true,
								-- cutout = true,
							},
							-- mask = true,
						})
						topBackground:setParent(c)

						local bottomBackground = ui:frame({
							image = {
								data = storeItemCellQuadDataBottom,
								slice9 = { 0.5, 0.5 },
								slice9Scale = 1.0,
								slice9Width = 20,
								alpha = true,
								-- cutout = true,
							},
							-- mask = true,
						})
						bottomBackground:setParent(c)

						c.Width = STORE_ITEM_WIDTH
						c.Height = STORE_ITEM_HEIGHT

						topBackground.Width = STORE_ITEM_WIDTH
						topBackground.Height = STORE_ITEM_HEIGHT - 40
						topBackground.pos = { 0, c.Height - topBackground.Height }

						bottomBackground.Width = STORE_ITEM_WIDTH
						bottomBackground.Height = 40
						bottomBackground.pos = { 0, 0 }

						local icon = ui:frame({
							image = {
								data = Data:FromBundle(packs[index].icon),
								alpha = true,
							},
						})
						icon.Width = topBackground.Height
						icon.Height = topBackground.Height
						icon.pos = { topBackground.Width * 0.5 - icon.Width * 0.5, topBackground.Height * 0.5 - icon.Height * 0.5 }
						icon:setParent(topBackground)

						local txt = string.format("%s", packs[index].price)
						if packs[index].subscription then
							txt = string.format("%s/mo", packs[index].price)
						end
						local price = ui:createText(txt, { color = Color.White, size = "small" })
						price:setParent(bottomBackground)
						price.pos = { bottomBackground.Width * 0.5 - price.Width * 0.5, bottomBackground.Height * 0.5 - price.Height * 0.5 }
						c.price = price

						local txt = string.format("%d", packs[index].coins)
						if packs[index].subscription then
							txt = string.format("%d/mo", packs[index].coins)
						end
						local coins = ui:createText(txt, { 
							color = Color(253, 222, 44), 
							size = "default",
							outline = 0.4,
							outlineColor = Color.Black,
							bold = true,
						})
						coins:setParent(topBackground)
						coins.pos = { topBackground.Width * 0.5 - coins.Width * 0.5, theme.padding }

						c.onPress = function()
							topBackground.Color = Color(100, 100, 100)
							bottomBackground.Color = Color(100, 100, 100)
							icon.Color = Color(100, 100, 100)
						end
						
						c.onRelease = function()	
							if c.loadingAnimation == nil then
								c.loadingAnimation = require("ui_loading_animation"):create({ ui = ui })
								c.loadingAnimation:setParent(topBackground)
								c.loadingAnimation.pos = { 
									topBackground.Width * 0.5 - c.loadingAnimation.Width * 0.5, 
									coins.pos.Y + coins.Height + (topBackground.Height - coins.pos.Y - coins.Height) * 0.5 - c.loadingAnimation.Height * 0.5 
								}
							end
							c.loadingAnimation:show()

							sfx("buttonpositive_3", { Volume = 0.5, Pitch = 1.0, Spatialized = false })

							topBackground.Color = Color(255, 255, 255)
							bottomBackground.Color = Color(255, 255, 255)
							icon.Color = Color(255, 255, 255)
							System:IAPPurchase(packs[index].productID, function(state, sandbox)
								if c.loadingAnimation then
									c.loadingAnimation:hide()
								end
								if state == "success" then
									sfx("coin_1", { Volume = 0.5, Pitch = 1.0, Spatialized = false })
									if refresh ~= nil then refresh() end
								elseif sandbox == true then
									Menu:ShowAlert({ message = "Blux can't be credited with a test version of the app. This transaction hasn't been charged." }, System)
								end
							end)
						end

						c.onCancel = function()
							topBackground.Color = Color(255, 255, 255)
							bottomBackground.Color = Color(255, 255, 255)
							icon.Color = Color(255, 255, 255)
						end

						packCells[index] = c
					end
					c:show()
					return c
				end
			end,
			unloadCell = function(_, cell)
				cell:hide()
			end,
		})
		packsScroll:setParent(node)
	end -- if iap is available

	local function layoutBalanceFrameContent()
		local height = balanceFrame.Height
		balanceText.pos = { theme.padding, height - theme.padding - balanceText.Height }

		earnedText.pos = {
			theme.padding,
			theme.padding,
		}

		grantedText.pos = {
			theme.padding,
			earnedText.pos.Y + earnedText.Height,
		}

		purchasedText.pos = {
			theme.padding,
			grantedText.pos.Y + grantedText.Height,
		}

		local w = balanceFrame.Width - theme.padding - math.max(
			balanceText.Width, 
			purchasedText.Width,
			grantedText.Width, 
			earnedText.Width
		)

		local cw = amountText.Width + coinShape.Width + theme.paddingBig

		coinShape.pos = {
			balanceFrame.Width - w * 0.5 - cw * 0.5,
			height * 0.5 - coinShape.Height * 0.5,
		}

		amountText.pos = {
			coinShape.pos.X + coinShape.Width + theme.paddingBig,
			height * 0.5 - amountText.Height * 0.5,
		}
		
	end

	content.idealReducedContentSize = function(_, width, height)
		width = math.min(width, 500)
		height = math.min(height, 800)

		local coinSize = 60
		coinShape.Width = coinSize
		coinShape.Height = coinSize

		local h = math.max(grantedText.Height + purchasedText.Height + earnedText.Height, coinSize)

		local balanceFrameHeight = balanceText.Height
			+ h
			+ theme.padding * 3

		balanceFrame.Width = width
		balanceFrame.Height = balanceFrameHeight

		layoutBalanceFrameContent()

		if packsScroll then
			packsScroll.Width = width
			packsScroll.Height = STORE_ITEM_HEIGHT
		end

		historyFrame.Width = width
		if packsScroll then
			historyFrame.Height = height - balanceFrame.Height - packsScroll.Height - theme.padding * 2
		else
			historyFrame.Height = height - balanceFrame.Height - theme.padding
		end

		-- detailText.pos = { theme.padding, theme.padding }

		historyText.pos = { theme.padding, historyFrame.Height - theme.padding - historyText.Height }

		balanceFrame.pos = { 0, height - balanceFrame.Height }

		if packsScroll then
			packsScroll.pos = { 0, balanceFrame.pos.Y - packsScroll.Height - theme.padding }
		end
		
		historyFrame.pos = { 0, 0 }

		scroll.Height = historyFrame.Height - historyText.Height - theme.padding * 2
		scroll.Width = historyFrame.Width - theme.padding * 2
		scroll.pos = { theme.padding, 0 }

		return Number2(width, height)
	end

	content.willResignActive = function()
		cancelRequests()
	end

	content.didBecomeActive = function()
		if refresh ~= nil then refresh() end
		System:DebugEvent("User shows bank account", {
			totalCoins = balance.totalCoins,
			grantedCoins = balance.grantedCoins,
			purchasedCoins = balance.purchasedCoins,
			earnedCoins = balance.earnedCoins,
		})
	end

	refresh = function()
		cancelRequests()
		local req = api:getBalance(function(err, balance)
			if err then
				amountText.Text = "-"
				grantedText.Text = loc("grants: -")
				purchasedText.Text = loc("purchased: -")
				earnedText.Text = loc("earned: -")
				layoutBalanceFrameContent()
				return
			end
			amountText.Text = string.format("%d", balance.totalCoins)
			grantedText.Text = string.format(loc("grants: %d"), balance.grantedCoins)
			purchasedText.Text = string.format(loc("purchased: %d"), balance.purchasedCoins)
			earnedText.Text = string.format(loc("earned: %d"), balance.earnedCoins)
			layoutBalanceFrameContent()
		end)
		table.insert(requests, req)

		req = api:getTransactions({
			callback = function(transactions, err)
				if err then
					print("ERROR:", err)
					return
				end
				loadedTransactions = transactions
				nbLoadedTransactions = #loadedTransactions
				scroll:flush()
				scroll:refresh()
			end,
		})
		table.insert(requests, req)
	end

	return content
end

return coins
