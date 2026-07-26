-- Owns the PrettyUI search field and bridges the Fairy Ring interface's native
-- keyboard listener into it. A lightweight caret and selection overlay preserve
-- normal text-field feedback before the real PrettyUI input receives focus.
local PrettyUI = assert(
    prettyui,
    "fairyrings requires the prettyui dependency"
)
local Constants = require("src/constants")
local Components = require("src/components")
local Geometry = require("src/geometry")

local SearchUI = {}
SearchUI.__index = SearchUI

local function textWidth(value)
    local ok, width = pcall(function()
        return config.Font.MUSEO_SANS_15PT_REGULAR:GetStringWidth(
            value,
            false
        )
    end)
    return ok and width or (#value * 8)
end

function SearchUI:_UpdateSelection()
    if self.selection == nil then
        return
    end

    local visible = self.allSelected
        and not self.realInputFocused
        and self.inputText ~= ""
    if not visible then
        self.selection.hidden = true
        if self.selectionText ~= nil then
            self.selectionText.hidden = true
        end
        return
    end

    local root = self.field and self.field.root or nil
    local width = root and root.width or 220
    local rootX = root and root.x or 0
    local rootY = root and root.y or 0
    local selectionWidth = math.min(
        textWidth(self.inputText),
        width - Constants.SEARCH_PADDING * 2
    )
    local x = rootX + Constants.SEARCH_PADDING
    local y = rootY
        + (Constants.SEARCH_HEIGHT - Constants.CARET_HEIGHT) // 2

    pcall(function()
        if self.selection.x ~= x or self.selection.y ~= y then
            self.selection:SetPos(x, y)
        end
        if self.selection.width ~= selectionWidth
            or self.selection.height ~= Constants.CARET_HEIGHT
        then
            self.selection:SetSize(
                selectionWidth,
                Constants.CARET_HEIGHT
            )
        end
        self.selection.hidden = false
        self.selection:MoveToFront()
        if self.selectionText ~= nil then
            if self.selectionText.x ~= x
                or self.selectionText.y ~= rootY
            then
                self.selectionText:SetPos(x, rootY)
            end
            if self.selectionText.width ~= selectionWidth
                or self.selectionText.height
                    ~= Constants.SEARCH_HEIGHT
            then
                self.selectionText:SetSize(
                    selectionWidth,
                    Constants.SEARCH_HEIGHT
                )
            end
            self.selectionText.content = self.inputText
            self.selectionText.hidden = false
            self.selectionText:MoveToFront()
        end
    end)
end

function SearchUI:_UpdateCaret(logicTick)
    self:_UpdateSelection()
    if self.caret == nil then
        return
    end

    -- Before a click, native Fairy Ring ONKEY events let users type without
    -- focusing the PrettyUI field, so a plugin caret communicates that state.
    -- Once the real InputField is focused its native caret takes over.
    if self.realInputFocused or self.allSelected then
        self.caret.hidden = true
        return
    end

    local root = self.field and self.field.root or nil
    local width = root and root.width or 220
    local rootX = root and root.x or 0
    local rootY = root and root.y or 0
    local x = rootX
        + math.min(
            Constants.SEARCH_PADDING + textWidth(self.inputText),
            width - Constants.SEARCH_PADDING
        )
    local y = rootY
        + (Constants.SEARCH_HEIGHT - Constants.CARET_HEIGHT) // 2
    local hidden = logicTick
            % (Constants.CARET_BLINK_TICKS * 2)
        >= Constants.CARET_BLINK_TICKS

    pcall(function()
        if self.caret.x ~= x or self.caret.y ~= y then
            self.caret:SetPos(x, y)
        end
        if self.caret.hidden ~= hidden then
            self.caret.hidden = hidden
        end
    end)
end

function SearchUI:_SyncLayout(holder)
    if self.field == nil or self.field.root == nil then
        return
    end

    pcall(function()
        local root = self.field.root
        local desiredPosition = self.layout:GetSearchPosition()
        local desiredWidth = self.layout:GetSearchWidth(holder)
        local changed = false

        if not Geometry.SameProperties(
            root.position,
            desiredPosition,
            Geometry.POSITION_PROPERTIES
        ) then
            root.position = desiredPosition
            changed = true
        end
        if root.width ~= desiredWidth
            or root.height ~= Constants.SEARCH_HEIGHT
        then
            root:SetSize(desiredWidth, Constants.SEARCH_HEIGHT)
            changed = true
        end
        if changed then
            root:UpdateLayout()
        end
        if root.hidden then
            root.hidden = false
        end
        if root.alpha ~= 1 then
            root.alpha = 1
        end
    end)
end

function SearchUI:_SetText(value, mirrorToField)
    local nextText = tostring(value or "")
    local changed = nextText ~= self.inputText
    self.inputText = nextText
    self.allSelected = false

    -- Native ONKEY input bypasses PrettyUI and must be mirrored into the field.
    -- PrettyUI's own onChange callback already changed the field, so mirroring
    -- in that path would generate redundant content updates.
    if mirrorToField and self.field ~= nil then
        self.field:SetText(self.inputText, false)
    end
    if changed then
        self.filter:SetQuery(self.inputText)
    end
    self:_UpdateCaret(0)
end

function SearchUI:_OnKeyboardKey(_, keyCode, keyChar)
    local controlDown = false
    pcall(function()
        controlDown = Keyboard.IsControlDown()
    end)
    local selectAll = (
        keyCode == GameKey.A
        and controlDown
    ) or keyChar == 1

    if selectAll then
        if self.realInputFocused then
            -- Let the focused native InputField perform and draw its own
            -- selection.
            return true
        end
        self.allSelected = self.inputText ~= ""
        self:_UpdateCaret(0)
        return false
    end

    self.realInputFocused = false

    -- The native interface reserves 1-9 for favourite destinations. Returning
    -- true leaves those keys unconsumed so the Fairy Ring handler receives
    -- them, while deliberately keeping them out of the search query.
    if keyChar ~= nil
        and keyChar >= string.byte("1")
        and keyChar <= string.byte("9")
    then
        return true
    end

    if keyCode == GameKey.BACKSPACE
        or keyCode == 8
        or keyChar == 8
        or keyChar == 127
    then
        local value = self.allSelected
            and ""
            or self.inputText:sub(1, -2)
        self:_SetText(value, true)
        return false
    end
    if (keyCode == GameKey.ESCAPE or keyCode == 27)
        and self.inputText ~= ""
    then
        self:_SetText("", true)
        return false
    end
    if keyChar ~= nil and keyChar >= 32 and keyChar <= 255 then
        local prefix = self.allSelected and "" or self.inputText
        self:_SetText(
            prefix .. string.char(keyChar),
            true
        )
        return false
    end
    return true
end

function SearchUI.new(holder, layout, filter)
    local keyboardListener =
        Components.Get("FAIRYRINGS__KEYBOARD_LISTENER")
    local logPanel = Components.Get("FAIRYRINGS__LOG")
    if holder == nil or keyboardListener == nil or logPanel == nil then
        return nil, "required Fairy Ring search components are unavailable"
    end

    local self = setmetatable({
        layout = layout,
        filter = filter,
        field = nil,
        caret = nil,
        selection = nil,
        selectionText = nil,
        keyboardListener = keyboardListener,
        inputText = "",
        realInputFocused = false,
        allSelected = false,
    }, SearchUI)

    local created, fieldOrError = pcall(function()
        return PrettyUI.TextField.new(logPanel, {
            x = holder.x,
            y = holder.y
                - Constants.SEARCH_GAP
                + Constants.SEARCH_Y_OFFSET,
            width = layout:GetSearchWidth(holder),
            height = Constants.SEARCH_HEIGHT,
            placeholder = "Search by code or destination",
            inputMode = ui.InputFieldKeyHandlingMode.DEFAULT,
            onChange = function(_, reason, value)
                if reason
                    == ui.InputFieldActionResult.SUBMIT_ON_FOCUS_LOSS
                then
                    self.realInputFocused = false
                end
                self:_SetText(value, false)
            end,
        })
    end)
    if not created then
        return nil, "unable to create search field: "
            .. tostring(fieldOrError)
    end

    self.field = fieldOrError
    self:_SyncLayout(holder)
    local focusSubscribed, focusError = pcall(function()
        self.field.root:MoveToFront()
        self.field.root:Subscribe(
            ui.Hook.ONCLICK,
            Constants.EVENT_ID .. "_real_focus",
            function()
                -- InputField focus is not exposed as a readable property; its
                -- click and focus-loss action are the available lifecycle
                -- signals used to switch between fake and native carets.
                self.realInputFocused = true
                self.allSelected = false
                self:_UpdateCaret(0)
                return false
            end
        )
    end)
    if not focusSubscribed then
        self:Destroy()
        return nil, "unable to subscribe to search-field focus: "
            .. tostring(focusError)
    end
    local caretCreated, caretOrError = pcall(function()
        local caret = ui.Rectangle.new(logPanel)
        caret:SetSize(1, Constants.CARET_HEIGHT)
        caret.fill = true
        caret.rgba = 0xFFFFFFFF
        caret.clickthrough = true
        caret:MoveToFront()
        return caret
    end)
    if caretCreated then
        self.caret = caretOrError
        self:_UpdateCaret(0)
    else
        log(
            "fairyrings: unable to create the focus caret: "
                .. tostring(caretOrError)
        )
    end

    local selectionCreated, selectionOrError = pcall(function()
        local selection = ui.Rectangle.new(logPanel)
        selection.fill = true
        selection.rgba = 0x4A4640FF
        selection.clickthrough = true
        selection.hidden = true
        selection:MoveToFront()
        return selection
    end)
    if selectionCreated then
        self.selection = selectionOrError
    else
        log(
            "fairyrings: unable to create the selection highlight: "
            .. tostring(selectionOrError)
        )
    end

    local selectionTextCreated, selectionTextOrError = pcall(function()
        local text = ui.Text.new(logPanel)
        text.font = self.field.root.text.font
        text.rgba = self.field.root.text.rgba
        text.isShadowed = self.field.root.text.isShadowed
        text.alignHorizontal = ui.AlignMode.TOPLEFT
        text.alignVertical = ui.AlignMode.CENTRE
        text.maxLines = 1
        text.clickthrough = true
        text.hidden = true
        text:MoveToFront()
        return text
    end)
    if selectionTextCreated then
        self.selectionText = selectionTextOrError
    else
        log(
            "fairyrings: unable to create the selected text: "
            .. tostring(selectionTextOrError)
        )
    end
    self:_UpdateSelection()

    local subscribed, subscribeError = pcall(function()
        keyboardListener:Subscribe(
            ui.Hook.ONKEY,
            Constants.EVENT_ID,
            function(...)
                return self:_OnKeyboardKey(...)
            end
        )
    end)
    if not subscribed then
        self:Destroy()
        return nil, "unable to subscribe to the Fairy Ring keyboard listener: "
            .. tostring(subscribeError)
    end
    return self
end

function SearchUI:Update(holder, logicTick)
    self:_SyncLayout(holder)
    self:_UpdateCaret(logicTick)
end

function SearchUI:Destroy()
    -- Unsubscribe by this plugin's listener IDs so a partially completed API operation cannot leak a callback.
    if self.keyboardListener ~= nil then
        pcall(function()
            self.keyboardListener:Unsubscribe(
                ui.Hook.ONKEY,
                Constants.EVENT_ID
            )
        end)
    end
    if self.field ~= nil and self.field.root ~= nil then
        pcall(function()
            self.field.root:Unsubscribe(
                ui.Hook.ONCLICK,
                Constants.EVENT_ID .. "_real_focus"
            )
        end)
    end
    self.keyboardListener = nil
    if self.caret ~= nil then
        pcall(function()
            self.caret:Destroy()
        end)
        self.caret = nil
    end
    if self.selection ~= nil then
        pcall(function()
            self.selection:Destroy()
        end)
        self.selection = nil
    end
    if self.selectionText ~= nil then
        pcall(function()
            self.selectionText:Destroy()
        end)
        self.selectionText = nil
    end
    if self.field ~= nil then
        pcall(function()
            self.field:Destroy()
        end)
        self.field = nil
    end
end

return SearchUI
