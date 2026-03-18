loading = {}

loading.create = function(_, text, config)
	local modal = require("modal")
	local theme = require("uitheme").current
	local uiLoading = require("ui_loading_animation")

	local MIN_WIDTH = 200
	local PADDING = theme.paddingBig

	-- default config
	local defaultConfig = {
		uikit = require("uikit"), -- allows to provide specific instance of uikit
	}

	local ok, err = pcall(function()
		config = require("config"):merge(defaultConfig, config)
	end)
	if not ok then
		error("loading:create(config) - config error: " .. err, 2)
	end

	local ui = config.uikit

	local content = modal:createContent()
	content.closeButton = false

	content.idealReducedContentSize = function(content, _, _)
		content:refresh()
		return Number2(content.Width, content.Height)
	end

	local maxWidth = function()
		return Screen.Width - theme.modalMargin * 2
	end

	local maxHeight = function()
		return Screen.Height - 100
	end

	local position = function(modal)
		modal.pos = { Screen.Width * 0.5 - modal.Width * 0.5, Screen.Height * 0.5 - modal.Height * 0.5 }
	end

	local node = ui:frame()
	content.node = node

	local label = ui:createText("", Color.White)
	label:setParent(node)
	node.label = label

	local animation = uiLoading:create({
		ui = ui,
	})
	animation:setParent(node)

	node._width = function(self)
		return math.max(self.label.Width + PADDING * 2, MIN_WIDTH)
	end

	node._height = function(self)
		return self.label.Height + animation.Height + PADDING * 3
	end

	node.refresh = function(self)
		label.object.MaxWidth = Screen.Width * 0.7
		label.pos = { 
			self.Width * 0.5 - self.label.Width * 0.5,
			self.Height - self.label.Height - PADDING }

		animation.pos = {
			self.Width * 0.5 - animation.Width * 0.5,
			PADDING
		}
	end

	local popup = modal:create(content, maxWidth, maxHeight, position, ui)

	popup.setText = function(self, text)
		label.Text = text
		self:refreshContent()
		node:refresh()
	end

	popup:setText(text)

	return popup
end

return loading
