local subscribed = nil
local searchOptions = nil
local createdSearch = nil
local createdCaret = nil
local createdSelection = nil
local createdSelectionText = nil
local loadedInterface = nil
local proxyFor = nil
local getInterfaceCalls = 0
local controlDown = false
local failFocusSubscribe = false

local function position(value)
    value = value or {}
    return {
        x = value.x or 0,
        y = value.y or 0,
        xParentPc = value.xParentPc or 0,
        yParentPc = value.yParentPc or 0,
        xSelfPc = value.xSelfPc or 0,
        ySelfPc = value.ySelfPc or 0,
    }
end

local function size(value)
    value = value or {}
    return {
        width = value.width or 0,
        height = value.height or 0,
        widthParentPc = value.widthParentPc or 0,
        heightParentPc = value.heightParentPc or 0,
    }
end

local function component(options)
    local value = options or {}
    value.x = value.x or 0
    value.y = value.y or 0
    value.width = value.width or 100
    value.height = value.height or 20
    value.hidden = value.hidden == true
    value.categoryID = value.categoryID or 0
    value.dynamicID = value.dynamicID or 0
    value.children = value.children or {}
    value.position = position({
        x = value.x,
        y = value.y,
        xParentPc = value.xParentPc,
        yParentPc = value.yParentPc,
        xSelfPc = value.xSelfPc,
        ySelfPc = value.ySelfPc,
    })
    value.size = size({
        width = value.width,
        height = value.height,
        widthParentPc = value.widthParentPc,
        heightParentPc = value.heightParentPc,
    })

    function value:SetPos(x, y)
        self.x = x
        self.y = y
        self.position.x = x
        self.position.y = y
    end

    function value:SetSize(width, height)
        self.width = width
        self.height = height
        self.size.width = width
        self.size.height = height
    end

    function value:UpdateLayout()
        self.x = self.position.x
        self.y = self.position.y
        self.width = self.size.width
        self.height = self.size.height
    end

    function value:SetScrollPos(x, y)
        self.scrollX = x
        self.scrollY = y
        self.scrollPosCalls = (self.scrollPosCalls or 0) + 1
    end

    function value:SetScrollSize(width, height)
        self.scrollWidth = width
        self.scrollHeight = height
    end

    function value:IterateDynamicComponents(callback)
        for _, child in ipairs(self.children) do
            callback(proxyFor(child), not child.hidden)
        end
    end

    function value:MoveToFront()
        self.movedToFront = true
    end

    function value:Subscribe(_, _, callback)
        if self.failSubscribe then
            error("forced subscription failure")
        end
        self.subscription = callback
    end

    function value:Unsubscribe()
        self.subscription = nil
    end

    function value:Destroy()
        self.destroyed = true
    end

    return value
end

proxyFor = function(target)
    return setmetatable({}, {
        __index = function(_, key)
            local value = target[key]
            if type(value) == "function" then
                return function(_, ...)
                    return value(target, ...)
                end
            end
            return value
        end,
        __newindex = function(_, key, value)
            target[key] = value
        end,
    })
end

local firstCode = component({
    y = 0,
    dynamicID = 1,
    type = 1,
    content = "D K R",
})
local firstLocation = component({
    y = 0,
    dynamicID = 2,
    type = 1,
    content = "Misthalin: Edgeville",
})
local firstClick = component({ y = 0, dynamicID = 3 })
local secondCode = component({
    y = 30,
    dynamicID = 4,
    type = 1,
    content = "B K S",
})
local secondLocation = component({
    y = 30,
    dynamicID = 5,
    type = 1,
    content = "Zanaris",
})
local secondClick = component({ y = 30, dynamicID = 6 })
local firstFavourite = component({ y = 0, dynamicID = 7 })
local secondFavourite = component({ y = 30, dynamicID = 8 })
local firstFavouriteClick = component({ y = 0, dynamicID = 9 })
local secondFavouriteClick = component({ y = 30, dynamicID = 10 })
local quickTeleportCheckbox = component({ y = 12, dynamicID = 1 })
local quickTeleportCheckboxClick =
    component({ y = 12, dynamicID = 1 })
local sortDropdownChild = component({
    y = 5,
    dynamicID = 1,
    type = 1,
    content = "Destination",
})

local logPanel = component({ width = 320, height = 400 })
local darkLine =
    component({ x = 0, y = 58, width = 280, height = 1 })
local lightLine =
    component({ x = 0, y = 59, width = 280, height = 1 })
local logContentHolder = component({
    x = 10,
    y = 60,
    width = 280,
    height = 300,
    visible = false,
})
local logContent = component({
    width = 280,
    height = 300,
    scrollWidth = 280,
    scrollHeight = 60,
    children = {},
})
local keyboardListener = component()
local favouriteBuild = component({
    children = { firstFavourite, secondFavourite },
})
local favouriteClick = component({
    children = { firstFavouriteClick, secondFavouriteClick },
})
local backgroundBuild = component()
local codeTextBuild =
    component({ children = { firstCode, secondCode } })
local locationTextBuild =
    component({ children = { firstLocation, secondLocation } })
local textClick =
    component({ children = { firstClick, secondClick } })
local scrollbar =
    component({ x = 280, y = 0, width = 20, height = 300 })

-- These controls deliberately remain outside the named destination parents.
-- Their assertions verify that filtering does not capture unrelated children.
local checkboxBuild =
    component({ children = { quickTeleportCheckbox } })
local checkboxClick =
    component({ children = { quickTeleportCheckboxClick } })
local sortDropdown =
    component({ children = { sortDropdownChild } })

local componentsByName = {
    FAIRYRINGS__LOG = logPanel,
    FAIRYRINGS__LINE_DARK_TOP = darkLine,
    FAIRYRINGS__LINE_LIGHT_TOP = lightLine,
    FAIRYRINGS__LOG_CONTENT_HOLDER = logContentHolder,
    FAIRYRINGS__LOG_CONTENT = logContent,
    FAIRYRINGS__KEYBOARD_LISTENER = keyboardListener,
    FAIRYRINGS__FAVOURITE_BUILD = favouriteBuild,
    FAIRYRINGS__FAVOURITE_CLICK = favouriteClick,
    FAIRYRINGS__BG_BUILD = backgroundBuild,
    FAIRYRINGS__CODE_TEXT_BUILD = codeTextBuild,
    FAIRYRINGS__LOCATION_TEXT_BUILD = locationTextBuild,
    FAIRYRINGS__TEXT_CLICK = textClick,
}

-- API IDs are opaque to plugin code. Unique table tokens make the test fail if
-- a component is requested under the wrong generated name.
local componentIDs = {}
local componentsByID = {}
for componentName, value in pairs(componentsByName) do
    local opaqueID = {}
    componentIDs[componentName] = opaqueID
    componentsByID[opaqueID] = value
end

loadedInterface = {}

ui = {
    ComponentType = { LABEL = 1 },
    InputFieldKeyHandlingMode = { DEFAULT = 1 },
    InputFieldActionResult = { SUBMIT_ON_FOCUS_LOSS = 5 },
    Hook = { ONKEY = 1, ONCLICK = 2 },
    Pos = {
        new = function(value)
            return position(value)
        end,
    },
    Size = {
        new = function(value)
            return size(value)
        end,
    },
    Rectangle = {
        new = function()
            local rectangle = component()
            if createdCaret == nil then
                createdCaret = rectangle
            else
                createdSelection = rectangle
            end
            return rectangle
        end,
    },
    AlignMode = {
        TOPLEFT = 1,
        CENTRE = 2,
    },
    Text = {
        new = function()
            createdSelectionText = component()
            return createdSelectionText
        end,
    },
    Interfaces = {
        GetInterface = function(_, interfaceID)
            assert(interfaceID == id.Interface.FAIRYRINGS)
            getInterfaceCalls = getInterfaceCalls + 1
            return loadedInterface
        end,
        GetComponent = function(_, combinedID)
            return componentsByID[combinedID]
        end,
    },
}

local fairyRingInterfaceID = {}
id = {
    Interface = {
        FAIRYRINGS = fairyRingInterfaceID,
    },
    Component = componentIDs,
}

config = {
    Font = {
        MUSEO_SANS_15PT_REGULAR = {
            GetStringWidth = function(_, text)
                return #text * 8
            end,
        },
    },
}

GameKey = {
    A = 48,
    ESCAPE = 13,
    BACKSPACE = 85,
}

Keyboard = {
    IsControlDown = function()
        return controlDown
    end,
}

prettyui = {
    TextField = {
        new = function(_, options)
            -- Each constructor attempt owns a fresh set of captured UI objects.
            createdCaret = nil
            createdSelection = nil
            createdSelectionText = nil
            searchOptions = options
            local result = {
                root = component({
                    x = options.x,
                    y = options.y,
                    width = options.width,
                    height = options.height,
                    failSubscribe = failFocusSubscribe,
                }),
                text = "",
            }
            result.root.text = {
                font = 1,
                rgba = 0xFFFFFFFF,
                isShadowed = true,
            }
            function result:SetText(value)
                self.text = value
            end
            function result:Destroy()
                self.destroyed = true
            end
            createdSearch = result
            return result
        end,
    },
}

Event = {
    Logic = {
        Subscribe = function(_, callback)
            subscribed = callback
        end,
        Unsubscribe = function() end,
    },
}

function log() end

package.path = "fairyrings/?.lua;" .. package.path
dofile("fairyrings/main.lua")

local fixed = {
    tick = function(logicTick)
        return subscribed({ logicTick = logicTick })
    end,
    setControlDown = function(value)
        controlDown = value
    end,
    setFocusSubscribeFailure = function(value)
        failFocusSubscribe = value
    end,
    setKeyboardSubscribeFailure = function(value)
        keyboardListener.failSubscribe = value
    end,
    shutdown = function()
        return PluginShutdown()
    end,
    firstCode = firstCode,
    firstLocation = firstLocation,
    firstClick = firstClick,
    secondCode = secondCode,
    secondLocation = secondLocation,
    secondClick = secondClick,
    firstFavourite = firstFavourite,
    secondFavourite = secondFavourite,
    firstFavouriteClick = firstFavouriteClick,
    secondFavouriteClick = secondFavouriteClick,
    quickTeleportCheckbox = quickTeleportCheckbox,
    quickTeleportCheckboxClick = quickTeleportCheckboxClick,
    sortDropdownChild = sortDropdownChild,
    logContentHolder = logContentHolder,
    logContent = logContent,
    keyboardListener = keyboardListener,
    darkLine = darkLine,
    lightLine = lightLine,
    scrollbar = scrollbar,
}

-- UI objects are created after the interface opens, so expose those captured
-- values through the context dynamically rather than returning stale nils.
return setmetatable(fixed, {
    __index = function(_, key)
        if key == "subscribed" then
            return subscribed
        elseif key == "searchOptions" then
            return searchOptions
        elseif key == "createdSearch" then
            return createdSearch
        elseif key == "createdCaret" then
            return createdCaret
        elseif key == "createdSelection" then
            return createdSelection
        elseif key == "createdSelectionText" then
            return createdSelectionText
        elseif key == "getInterfaceCalls" then
            return getInterfaceCalls
        end
        return nil
    end,
})
