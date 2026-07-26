-- Reserves a strip in the native Fairy Ring modal for the search field. It
-- tracks native geometry changes so repeated game-script layout rebuilds do not
-- accumulate offsets, and retains the latest native baseline for restoration.
local Constants = require("src/constants")
local Components = require("src/components")
local Geometry = require("src/geometry")

local NativeLayout = {}
NativeLayout.__index = NativeLayout

local POSITION_PROPERTIES = Geometry.POSITION_PROPERTIES
local SIZE_PROPERTIES = Geometry.SIZE_PROPERTIES

local function capture()
    local holder = Components.Get("FAIRYRINGS__LOG_CONTENT_HOLDER")
    local darkLine = Components.Get("FAIRYRINGS__LINE_DARK_TOP")
    local lightLine = Components.Get("FAIRYRINGS__LINE_LIGHT_TOP")
    if holder == nil or darkLine == nil or lightLine == nil then
        return nil
    end

    -- Copy Pos/Size objects rather than resolved x/y/width/height. Their anchor
    -- percentages are required for the modal to remain aligned at every size.
    return {
        holder = {
            position = Geometry.CopyPosition(holder.position),
            size = Geometry.CopySize(holder.size),
            appliedPosition = nil,
            appliedSize = nil,
        },
        darkLine = {
            position = Geometry.CopyPosition(darkLine.position),
            appliedPosition = nil,
        },
        lightLine = {
            position = Geometry.CopyPosition(lightLine.position),
            appliedPosition = nil,
        },
    }
end

function NativeLayout.new()
    local snapshot = capture()
    if snapshot == nil then
        return nil
    end
    return setmetatable({
        snapshot = snapshot,
    }, NativeLayout)
end

function NativeLayout:GetSearchPosition()
    return Geometry.OffsetPosition(
        self.snapshot.holder.position,
        Constants.SEARCH_Y_OFFSET
    )
end

function NativeLayout:GetSearchWidth(holder)
    local darkLine = Components.Get("FAIRYRINGS__LINE_DARK_TOP")
    local dividerWidth = darkLine ~= nil and darkLine.width or 0
    return math.max(holder.width, dividerWidth, 220)
end

function NativeLayout:Apply()
    local holder = Components.Get("FAIRYRINGS__LOG_CONTENT_HOLDER")
    local darkLine = Components.Get("FAIRYRINGS__LINE_DARK_TOP")
    local lightLine = Components.Get("FAIRYRINGS__LINE_LIGHT_TOP")
    if holder == nil or darkLine == nil or lightLine == nil then
        return false
    end

    local snapshot = self.snapshot
    local ok = pcall(function()
        Geometry.RefreshBaseline(
            holder.position,
            snapshot.holder.position,
            snapshot.holder.appliedPosition,
            POSITION_PROPERTIES
        )
        Geometry.RefreshBaseline(
            holder.size,
            snapshot.holder.size,
            snapshot.holder.appliedSize,
            SIZE_PROPERTIES
        )
        Geometry.RefreshBaseline(
            darkLine.position,
            snapshot.darkLine.position,
            snapshot.darkLine.appliedPosition,
            POSITION_PROPERTIES
        )
        Geometry.RefreshBaseline(
            lightLine.position,
            snapshot.lightLine.position,
            snapshot.lightLine.appliedPosition,
            POSITION_PROPERTIES
        )

        -- Reserve one strip between the sort controls and divider. Moving and
        -- shrinking the holder by the same amount preserves its lower edge.
        local holderPosition = Geometry.OffsetPosition(
            snapshot.holder.position,
            Constants.SEARCH_GAP
        )
        local holderSize = Geometry.OffsetHeight(
            snapshot.holder.size,
            -Constants.SEARCH_GAP
        )
        local darkLinePosition = Geometry.OffsetPosition(
            snapshot.darkLine.position,
            Constants.SEARCH_GAP
        )
        local lightLinePosition = Geometry.OffsetPosition(
            snapshot.lightLine.position,
            Constants.SEARCH_GAP
        )

        -- Avoid forcing native layout work unless a script actually reset a
        -- value or the parent geometry changed.
        local holderChanged = false
        if not Geometry.SameProperties(
            holder.position,
            holderPosition,
            POSITION_PROPERTIES
        ) then
            holder.position = holderPosition
            snapshot.holder.appliedPosition =
                Geometry.CopyPosition(holderPosition)
            holderChanged = true
        end
        if not Geometry.SameProperties(
            holder.size,
            holderSize,
            SIZE_PROPERTIES
        ) then
            holder.size = holderSize
            snapshot.holder.appliedSize = Geometry.CopySize(holderSize)
            holderChanged = true
        end
        if holderChanged then
            holder:UpdateLayout()
        end

        if not Geometry.SameProperties(
            darkLine.position,
            darkLinePosition,
            POSITION_PROPERTIES
        ) then
            darkLine.position = darkLinePosition
            darkLine:UpdateLayout()
            snapshot.darkLine.appliedPosition =
                Geometry.CopyPosition(darkLinePosition)
        end
        if not Geometry.SameProperties(
            lightLine.position,
            lightLinePosition,
            POSITION_PROPERTIES
        ) then
            lightLine.position = lightLinePosition
            lightLine:UpdateLayout()
            snapshot.lightLine.appliedPosition =
                Geometry.CopyPosition(lightLinePosition)
        end
    end)
    return ok
end

function NativeLayout:Restore()
    local holder = Components.Get("FAIRYRINGS__LOG_CONTENT_HOLDER")
    local darkLine = Components.Get("FAIRYRINGS__LINE_DARK_TOP")
    local lightLine = Components.Get("FAIRYRINGS__LINE_LIGHT_TOP")
    local snapshot = self.snapshot

    pcall(function()
        if holder ~= nil then
            holder.position = Geometry.CopyPosition(snapshot.holder.position)
            holder.size = Geometry.CopySize(snapshot.holder.size)
            holder:UpdateLayout()
        end
        if darkLine ~= nil then
            darkLine.position =
                Geometry.CopyPosition(snapshot.darkLine.position)
            darkLine:UpdateLayout()
        end
        if lightLine ~= nil then
            lightLine.position =
                Geometry.CopyPosition(snapshot.lightLine.position)
            lightLine:UpdateLayout()
        end
    end)
end

return NativeLayout
