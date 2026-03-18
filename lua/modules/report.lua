mod = {}

mod.createModalContent = function(_, config)
	local systemApi = require("system_api", System)
	local api = require("api")
	local time = require("time")
	local theme = require("uitheme").current

	local defaultConfig = {
		item = nil,
		world = nil,
		uikit = require("uikit"),
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config, {
			acceptTypes = {
				item = { "table" },
				world = { "table" },
			},
		})
	end)
	if not ok then
		error("report:createModalContent(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local item = config.item
	local world = config.world

	local reportForm = ui:frame()

	local requests = {}
	local refreshTimer
	local listeners = {}

	local privateFields = {}

	local cancelRequestsTimersAndListeners = function()
		for _, req in ipairs(requests) do
			req:Cancel()
		end
		requests = {}

		for _, listener in ipairs(listeners) do
			listener:Remove()
		end
		listeners = {}

		if refreshTimer ~= nil then
			refreshTimer:Cancel()
			refreshTimer = nil
		end
	end

	reportForm.onRemove = function(_)
		cancelRequestsTimersAndListeners()
	end

	local content = require("modal"):createContent()
	content.title = "Report"
	content.icon = "⚠️"
	content.node = reportForm

	content.didBecomeActive = function()
		for _, listener in ipairs(listeners) do
			listener:Resume()
		end
	end

	content.willResignActive = function()
		for _, listener in ipairs(listeners) do
			listener:Pause()
		end
	end

	local text
	local textInput
	local submitBtn

	local secondaryTextColor = Color(200, 200, 200)

	local msg = "What's wrong with this item?\nPlease describe the issue:"
	if item ~= nil then
		if item.repo and item.name then
			msg = string.format("What's wrong with this Item? (%s by %s)\nPlease describe the issue:", item.name, item.repo)
		else
			msg = "What's wrong with this Item?\nPlease describe the issue:"
		end
	elseif world ~= nil then
		if world.title then
			msg = string.format("What's wrong with this World? (%s)\nPlease describe the issue:", world.title)
		else
			msg = "What's wrong with this World?\nPlease describe the issue:"
		end
	end

	local loadingAnimation = require("ui_loading_animation"):create({ ui = ui })
	loadingAnimation:setParent(reportForm)
	loadingAnimation:hide()

	local confirmationText = ui:createText("Report sent!", {
		color = secondaryTextColor, 
		size = "default",
		alignment = "center",
	})
	confirmationText:setParent(reportForm)
	confirmationText:hide()

	text = ui:createText(msg, {
		color = secondaryTextColor, 
		size = "default",
		alignment = "center",
	})
	text:setParent(reportForm)

	textInput = ui:createTextInput("", "What's wrong?")
	textInput:setParent(reportForm)

	submitBtn = ui:buttonNeutral({ 
		content = "Submit", 
		textSize = "default",
	})
	submitBtn:setParent(reportForm)

	submitBtn.onRelease = function(self)
		text:hide()
		textInput:hide()
		submitBtn:hide()
		confirmationText:hide()
		loadingAnimation:show()
		systemApi:report({
			worldID = world ~= nil and world.id or nil,
			itemID = item ~= nil and item.id or nil,
			message = textInput.Text,
			callback = function(err)
				-- TODO: handle error
				loadingAnimation:hide()
				confirmationText:show()
			end
		})
	end

	reportForm.parentDidResize = function(self)
		local padding = theme.paddingBig
		local width = self.Width - padding * 2

		text.object.MaxWidth = width
		textInput.Width = width

		local contentHeight = text.Height 
			+ textInput.Height
			+ submitBtn.Height 
			+ padding * 2
			
		local y = self.Height * 0.5 + contentHeight * 0.5 - text.Height

		text.pos = { self.Width * 0.5 - text.Width * 0.5, y }

		y = y - padding - textInput.Height

		textInput.pos = { self.Width * 0.5 - textInput.Width * 0.5, y }

		y = y - padding - submitBtn.Height
		submitBtn.pos = { self.Width * 0.5 - submitBtn.Width * 0.5, y }

		loadingAnimation.pos = { 
			self.Width * 0.5 - loadingAnimation.Width * 0.5, 
			self.Height * 0.5 - loadingAnimation.Height * 0.5 
		}

		confirmationText.pos = { 
			self.Width * 0.5 - confirmationText.Width * 0.5, 
			self.Height * 0.5 - confirmationText.Height * 0.5 
		}
	end

	return content
end

mod.createModal = function(_, config)
	local modal = require("modal")
	local ui = config.ui or require("uikit")
	local ease = require("ease")
	local theme = require("uitheme").current
	local MODAL_MARGIN = theme.paddingBig -- space around modals

	local topBarHeight = 50

	local reportContent = mod:createModalContent({ uikit = ui })

	reportContent.idealReducedContentSize = function(content, width, height)
		content.Width = width * 0.8
		content.Height = height * 0.8
		return Number2(content.Width, content.Height)
	end

	function maxModalWidth()
		local computed = Screen.Width - Screen.SafeArea.Left - Screen.SafeArea.Right - MODAL_MARGIN * 2
		local max = 1400
		local w = math.min(max, computed)
		return w
	end

	function maxModalHeight()
		return Screen.Height - Screen.SafeArea.Bottom - topBarHeight - MODAL_MARGIN * 2
	end

	function updateModalPosition(modal, forceBounce)
		local vMin = Screen.SafeArea.Bottom + MODAL_MARGIN
		local vMax = Screen.Height - topBarHeight - MODAL_MARGIN

		local vCenter = vMin + (vMax - vMin) * 0.5

		local p = Number3(Screen.Width * 0.5 - modal.Width * 0.5, vCenter - modal.Height * 0.5, 0)

		if not modal.updatedPosition or forceBounce then
			modal.LocalPosition = p - { 0, 100, 0 }
			modal.updatedPosition = true
			ease:cancel(modal) -- cancel modal ease animations if any
			ease:outBack(modal, 0.22).LocalPosition = p
		else
			modal.LocalPosition = p
		end
	end

	local currentModal = modal:create(reportContent, maxModalWidth, maxModalHeight, updateModalPosition, ui)
	return currentModal
end

return mod
