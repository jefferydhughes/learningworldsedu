mod = {}

mod.createModalContent = function(_, config)
	local requests = {}
	local getHistoryReq

	local function cancelRequests()
		for _, r in ipairs(requests) do
			r:Cancel()
		end
		requests = {}
		getHistoryReq = nil
	end

	local theme = require("uitheme").current
	local modal = require("modal")
	local conf = require("config")
	local time = require("time")
	local systemApi = require("system_api", System)

	-- default config
	local defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	config = conf:merge(defaultConfig, config)

	local ui = config.uikit

	local content = modal:createContent()
	content.closeButton = true
	content.title = "History"
	content.icon = Data:FromBundle("images/icon-history.png")

	local node = ui:createFrame()
	content.node = node

	local frame = ui:frameTextBackground()
	frame:setParent(node)

	local loadedNotifications = {}
	local nbLoadedNotifications = 0
	local recycledCells = {}

	local padding = theme.padding

	local function historyCellParentDidResize(self)
		self.Width = self.parent.Width

		local infoWidth = self.hash.Width + self.when.Width

		self.hash.pos = {
			padding,
			self.Height - self.hash.Height - padding,
		}

		self.when.pos = {
			self.Width - self.when.Width - padding,
			self.hash.pos.Y
		}

		self.rollbackBtn.pos = {
			self.Width - self.rollbackBtn.Width - padding,
			padding,
		}

		self.description.pos = {
			padding,
			padding,
		}
	end

	local function rollback(self)
		System:Rollback(self.hash)
	end

	local function getHistoryCell(notification, containerWidth)
		local c = table.remove(recycledCells)
		if c == nil then
			c = ui:frameScrollCell()
			c.when = ui:createText("", { color = Color(240, 240, 240), size = "small" })
			c.when.object.Scale = 0.8
			c.when:setParent(c)
			c.hash = ui:createText("a43b62aa", { color = Color(120, 120, 120), size = "small" })
			c.hash.object.Scale = 0.8
			c.hash:setParent(c)
			c.description = ui:createText("", { color = Color(240, 240, 240), size = "small" })
			c.description.object.Scale = 0.9
			c.description:setParent(c)

			if iconRestoreData == nil then
				iconRestoreData = Data:FromBundle("images/icon-restore.png")
			end
			local rollbackIcon = ui:frame({
				image = {
					data = iconRestoreData,
					alpha = true,
				},
			})
			rollbackIcon.Width = 30 rollbackIcon.Height = 30

			c.rollbackBtn = ui:buttonSecondary({ content = rollbackIcon })
			c.rollbackBtn.onRelease = rollback
			rollbackIcon:setParent(c.rollbackBtn)
			c.rollbackBtn:setParent(c)

			c.parentDidResize = historyCellParentDidResize
		end

		local t, units = time.ago(notification.created, {
			years = false,
			months = false,
			seconds_label = "s",
			minutes_label = "m",
			hours_label = "h",
			days_label = "d",
		})
		c.when.Text = "" .. t .. units .. " ago"
		c.hash.Text = string.sub(notification.hash, 1, 10)
		c.rollbackBtn.hash = notification.hash

		c.description.object.MaxWidth = containerWidth - c.rollbackBtn.Width - padding * 3
		c.description.Text = notification.message or ""

		c.Height = c.hash.Height + padding * 3 + math.max(c.description.Height, c.rollbackBtn.Height)

		return c
	end

	local function recycleNotificationCell(cell)
		cell:setParent(nil)
		table.insert(recycledCells, cell)
	end

	local scroll = ui:scroll({
		padding = {
			top = theme.padding,
			bottom = theme.padding,
			left = 0,
			right = 0,
		},
		cellPadding = theme.padding,
		loadCell = function(index, _, container) -- TODO: use container to create cell with right constraints
			if index <= nbLoadedNotifications then
				local c = getHistoryCell(loadedNotifications[index], container.Width)
				if index == 1 then 
					c.rollbackBtn:hide()
				else
					c.rollbackBtn:show()
				end
				return c
			end
		end,
		unloadCell = function(_, cell)
			recycleNotificationCell(cell)
		end,
	})
	scroll:setParent(frame)

	local functions = {}

	functions.layout = function(width, height)
		width = width or frame.parent.Width
		height = height or frame.parent.Height

		frame.Width = width
		local frameHeight = height

		frame.Height = frameHeight

		frame.pos = { 0, height - frameHeight, 0 }

		scroll.Height = frame.Height
		scroll.Width = frame.Width - theme.padding * 2
		scroll.pos = { theme.padding, 0 }
	end

	content.idealReducedContentSize = function(_, width, height)
		width = math.min(width, 500)
		functions.layout(width, height)
		return Number2(width, height)
	end

	content.didBecomeActive = function()
		if getHistoryReq == nil then
			-- NOTE: didBecomeActive is called twice
			-- sending request within this block to avoid doing it twice.
			-- TODO: fix this `didBecomeActive` issue, could be an important optimization in other modals
			getHistoryReq = systemApi:getWorldHistory({ worldID = Environment["worldId"] }, function(commits, err)
				if err then
					return
				end
				loadedNotifications = commits
				nbLoadedNotifications = #commits
				if type(scroll.flush) ~= "function" then
					return
				end
				scroll:flush()
				scroll:refresh()
			end)

			table.insert(requests, getHistoryReq)
		end
	end

	content.willResignActive = function()
		cancelRequests()
	end

	return content
end

return mod
