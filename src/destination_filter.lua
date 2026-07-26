-- Builds searchable destination rows from the native Fairy Ring templates,
-- then hides and compacts non-matching rows without losing their native
-- positions or visibility. Native scripts can rebuild and reuse these
-- components, so every pass refreshes the saved baseline before applying the
-- plugin's filtered state.
local CODE_SEARCH_ALIASES = require("aliases")
local Components = require("src/components")
local Constants = require("src/constants")

local DestinationFilter = {}
DestinationFilter.__index = DestinationFilter

local ROW_CLICK_EVENT_ID = Constants.EVENT_ID .. "_row_click"

-- A destination is rendered across separate dynamic-component collections:
-- labels provide the searchable row anchors, while backgrounds, click targets,
-- and favourite controls must follow the matching anchor when rows are moved.
local ROW_PARENT_NAMES = {
    "FAIRYRINGS__LOG_CONTENT",
    "FAIRYRINGS__FAVOURITE_BUILD",
    "FAIRYRINGS__FAVOURITE_CLICK",
    "FAIRYRINGS__BG_BUILD",
    "FAIRYRINGS__CODE_TEXT_BUILD",
    "FAIRYRINGS__LOCATION_TEXT_BUILD",
    "FAIRYRINGS__TEXT_CLICK",
}

-- These native click targets can rebuild the destination templates. Watching
-- both destination selection and favourite toggles lets the active filter be
-- enforced throughout the native row-click animation.
local REBUILDING_CLICK_PARENTS = {
    FAIRYRINGS__FAVOURITE_CLICK = true,
    FAIRYRINGS__TEXT_CLICK = true,
}

local function isTextParent(componentName)
    return componentName == "FAIRYRINGS__CODE_TEXT_BUILD"
        or componentName == "FAIRYRINGS__LOCATION_TEXT_BUILD"
end

local function normalise(value)
    local text = tostring(value or "")
    text = text:gsub("<[^>]+>", "")
    return text:lower()
end

local function compactFairyRingCode(value)
    local compact = normalise(value):gsub("[^a-z]", "")
    if #compact == 3 then
        return compact
    end
    return nil
end

local function componentKey(componentName, component)
    -- Lua proxies may be recreated between iterations; native IDs provide the
    -- stable identity needed to retain an unfiltered baseline.
    return componentName
        .. ":"
        .. tostring(component.categoryID)
        .. ":"
        .. tostring(component.dynamicID)
end

local function readContent(component)
    local ok, value = pcall(function()
        return component.content
    end)
    if not ok or value == nil then
        return ""
    end
    return tostring(value)
end

function DestinationFilter.new()
    return setmetatable({
        query = "",
        original = {},
        clickComponents = {},
        contentScroll = nil,
        scrollResetPending = false,
        dirty = false,
        reapplyTicksRemaining = 0,
    }, DestinationFilter)
end

function DestinationFilter:_WatchRebuildingClick(
    componentName,
    key,
    component
)
    if not REBUILDING_CLICK_PARENTS[componentName] then
        return
    end

    -- During the enforcement window, retain the newest proxy without replacing
    -- the same listener on every tick. The final pass below rebinds the current
    -- component after the native animation has finished rebuilding it.
    if self.reapplyTicksRemaining > 0
        and self.clickComponents[key] ~= nil
    then
        self.clickComponents[key] = component
        return
    end

    -- Dynamic components may be recreated with the same IDs. Re-subscribing
    -- with the same plugin listener ID replaces the old callback and ensures
    -- the current native component is watched.
    local subscribed = pcall(function()
        component:Subscribe(
            ui.Hook.ONCLICK,
            ROW_CLICK_EVENT_ID,
            function()
                if self.query ~= "" then
                    self.reapplyTicksRemaining =
                        Constants.CLICK_REAPPLY_TICKS
                end
                -- Continue to the native listener which performs the rebuild.
                return true
            end
        )
    end)
    if subscribed then
        self.clickComponents[key] = component
    end
end

function DestinationFilter:_RememberComponent(componentName, component)
    local key = componentKey(componentName, component)
    local remembered = self.original[key]
    local content = readContent(component)

    if remembered == nil then
        remembered = {
            component = component,
            x = component.x,
            y = component.y,
            hidden = component.hidden == true,
            content = content,
            appliedY = nil,
            appliedHidden = nil,
        }
        self.original[key] = remembered
        return remembered
    end

    -- Iteration may return a fresh proxy for the same native component.
    remembered.component = component

    -- Native sorting and favourite changes may reuse a component. Preserve our
    -- baseline only while the native values equal the values we last applied.
    if remembered.appliedY == nil or component.y ~= remembered.appliedY then
        remembered.x = component.x
        remembered.y = component.y
    end
    if remembered.appliedHidden == nil
        or component.hidden ~= remembered.appliedHidden
    then
        remembered.hidden = component.hidden == true
    end
    if content ~= remembered.content then
        remembered.content = content
        remembered.x = component.x
        remembered.y = component.y
    end

    return remembered
end

function DestinationFilter:_SetFilteredState(
    component,
    remembered,
    hidden,
    y
)
    -- Never expose something the native interface had already hidden.
    local targetHidden = remembered.hidden or hidden
    local targetY = y or remembered.y

    pcall(function()
        if component.hidden ~= targetHidden then
            component.hidden = targetHidden
        end
        if component.x ~= remembered.x or component.y ~= targetY then
            component:SetPos(remembered.x, targetY)
        end
    end)

    remembered.appliedHidden = targetHidden
    remembered.appliedY = targetY
end

function DestinationFilter:_CollectRows()
    local components = {}
    local seen = {}

    for _, componentName in ipairs(ROW_PARENT_NAMES) do
        local parent = Components.Get(componentName)
        if parent ~= nil then
            pcall(function()
                parent:IterateDynamicComponents(function(component)
                    local key = componentKey(componentName, component)
                    if not seen[key] then
                        seen[key] = true
                        self:_WatchRebuildingClick(
                            componentName,
                            key,
                            component
                        )
                        local content = readContent(component)
                        components[#components + 1] = {
                            componentName = componentName,
                            component = component,
                            remembered =
                                self:_RememberComponent(
                                    componentName,
                                    component
                                ),
                            content = content,
                            isSearchText = content ~= ""
                                and (
                                    isTextParent(componentName)
                                    or component.type
                                        == ui.ComponentType.LABEL
                                ),
                        }
                    end
                    return false
                end)
            end)
        end
    end

    -- Code/location labels are the canonical row anchors. The other templates
    -- (background, click target and favourite visuals) are attached later.
    local textEntries = {}
    -- Separate template types native Y coordinates describe their row positions.
    for _, entry in ipairs(components) do
        if entry.isSearchText then
            textEntries[#textEntries + 1] = entry
        end
    end
    table.sort(textEntries, function(left, right)
        return left.remembered.y < right.remembered.y
    end)

    -- Some native builds share an ID across each row while others allocate an
    -- ID per visual. Group labels by position, then attach the nearest visuals.
    local rows = {}
    local labelTolerance = 6
    for _, entry in ipairs(textEntries) do
        local row = rows[#rows]
        if row == nil
            or math.abs(entry.remembered.y - row.anchorY) > labelTolerance
        then
            row = {
                components = {},
                textParts = {},
                anchorY = entry.remembered.y,
                maxHeight = 0,
            }
            rows[#rows + 1] = row
        end
        row.textParts[#row.textParts + 1] = entry.content
        if entry.componentName == "FAIRYRINGS__CODE_TEXT_BUILD" then
            row.code = compactFairyRingCode(entry.content)
        end
    end

    if #rows == 0 then
        return rows
    end

    for _, entry in ipairs(components) do
        local nearest = rows[1]
        local nearestDistance =
            math.abs(entry.remembered.y - nearest.anchorY)
        for index = 2, #rows do
            local distance =
                math.abs(entry.remembered.y - rows[index].anchorY)
            if distance < nearestDistance then
                nearest = rows[index]
                nearestDistance = distance
            end
        end

        nearest.components[#nearest.components + 1] = entry
        nearest.maxHeight =
            math.max(nearest.maxHeight, entry.component.height or 0)
    end

    for _, row in ipairs(rows) do
        local aliases = row.code and CODE_SEARCH_ALIASES[row.code] or nil
        if aliases ~= nil then
            for _, alias in ipairs(aliases) do
                row.textParts[#row.textParts + 1] = alias
            end
        end
        row.searchText = normalise(table.concat(row.textParts, " "))
    end

    return rows
end

local function rowSpacing(rows)
    local spacing = nil
    for index = 2, #rows do
        local difference = rows[index].anchorY - rows[index - 1].anchorY
        if difference > 0 and (spacing == nil or difference < spacing) then
            spacing = difference
        end
    end
    if spacing ~= nil then
        return spacing
    end
    local height = rows[1] and rows[1].maxHeight or 0
    return math.max(height, 24)
end

function DestinationFilter:_UpdateScrollSize(rows, visibleCount, spacing)
    local content = Components.Get("FAIRYRINGS__LOG_CONTENT")
    if content == nil then
        return
    end

    local ok, currentWidth, currentHeight = pcall(function()
        return content.scrollWidth, content.scrollHeight
    end)
    if not ok then
        return
    end

    -- Track both the native scroll extent and our last applied extent. This
    -- lets sorting/favourite scripts replace the native value without our
    -- filtered value becoming the new restoration baseline.
    if self.contentScroll == nil then
        self.contentScroll = {
            width = currentWidth,
            height = currentHeight,
            appliedWidth = nil,
            appliedHeight = nil,
        }
    else
        if self.contentScroll.appliedWidth == nil
            or currentWidth ~= self.contentScroll.appliedWidth
        then
            self.contentScroll.width = currentWidth
        end
        if self.contentScroll.appliedHeight == nil
            or currentHeight ~= self.contentScroll.appliedHeight
        then
            self.contentScroll.height = currentHeight
        end
    end

    local desiredHeight
    if self.query == "" then
        desiredHeight = self.contentScroll.height
    else
        local filteredBottom =
            rows[1].anchorY + visibleCount * spacing
        desiredHeight = math.max(content.height or 0, filteredBottom)
    end

    pcall(function()
        if currentWidth ~= self.contentScroll.width
            or currentHeight ~= desiredHeight
        then
            content:SetScrollSize(self.contentScroll.width, desiredHeight)
        end
        if self.scrollResetPending then
            content:SetScrollPos(0, 0)
        end
    end)
    self.contentScroll.appliedWidth = self.contentScroll.width
    self.contentScroll.appliedHeight = desiredHeight
    self.scrollResetPending = false
end

function DestinationFilter:Apply()
    if self.reapplyTicksRemaining > 0 then
        self.reapplyTicksRemaining =
            self.reapplyTicksRemaining - 1
    end
    local rows = self:_CollectRows()
    if #rows == 0 then
        self.dirty = true
        return false
    end

    local spacing = rowSpacing(rows)
    local firstY = rows[1].anchorY
    local visibleCount = 0
    local compactQuery = self.query:gsub("%s+", "")

    for _, row in ipairs(rows) do
        local matches = self.query == ""
            or row.searchText:find(self.query, 1, true) ~= nil
            or (
                compactQuery ~= ""
                and row.code ~= nil
                and row.code:find(compactQuery, 1, true) ~= nil
            )
        local targetAnchor = row.anchorY
        if matches then
            targetAnchor = firstY + visibleCount * spacing
            visibleCount = visibleCount + 1
        end

        -- Move every visual by the row-anchor delta, preserving small offsets
        -- between labels, stars, backgrounds and click targets.
        for _, entry in ipairs(row.components) do
            local targetY = entry.remembered.y
                + targetAnchor
                - row.anchorY
            self:_SetFilteredState(
                entry.component,
                entry.remembered,
                not matches,
                targetY
            )
        end
    end

    self:_UpdateScrollSize(rows, visibleCount, spacing)
    self.dirty = false
    return true
end

function DestinationFilter:SetQuery(value)
    local query = normalise(value)
    if query == self.query then
        return false
    end
    self.query = query
    if self.query == "" then
        self.reapplyTicksRemaining = 0
    end
    self.scrollResetPending = true
    self.dirty = true
    self:Apply()
    return true
end

function DestinationFilter:NeedsUpdate()
    return self.dirty or self.query ~= ""
end

function DestinationFilter:NeedsImmediateUpdate()
    return self.reapplyTicksRemaining > 0
end

function DestinationFilter:Restore()
    for _, component in pairs(self.clickComponents) do
        pcall(function()
            component:Unsubscribe(
                ui.Hook.ONCLICK,
                ROW_CLICK_EVENT_ID
            )
        end)
    end
    self.clickComponents = {}
    self.reapplyTicksRemaining = 0

    for _, remembered in pairs(self.original) do
        pcall(function()
            local component = remembered.component
            component.hidden = remembered.hidden
            component:SetPos(remembered.x, remembered.y)
        end)
        remembered.appliedHidden = nil
        remembered.appliedY = nil
    end

    local content = Components.Get("FAIRYRINGS__LOG_CONTENT")
    if content ~= nil and self.contentScroll ~= nil then
        pcall(function()
            content:SetScrollSize(
                self.contentScroll.width,
                self.contentScroll.height
            )
        end)
    end
end

return DestinationFilter
