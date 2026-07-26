-- helpers for copying, offsetting, and comparing anchored UI geometry.
-- We copy because Pos and Size values are mutable API objects.
local Geometry = {}

Geometry.POSITION_PROPERTIES = {
    "x", "y", "xParentPc", "yParentPc", "xSelfPc", "ySelfPc",
}

Geometry.SIZE_PROPERTIES = {
    "width", "height", "widthParentPc", "heightParentPc",
}

function Geometry.CopyPosition(position)
    return ui.Pos.new(position)
end

function Geometry.CopySize(size)
    return ui.Size.new(size)
end

function Geometry.OffsetPosition(position, yOffset)
    local result = Geometry.CopyPosition(position)
    result.y = result.y + yOffset
    return result
end

function Geometry.OffsetHeight(size, heightOffset)
    local result = Geometry.CopySize(size)
    result.height = result.height + heightOffset
    return result
end

function Geometry.RefreshBaseline(current, baseline, applied, properties)
    if applied == nil then
        return
    end
    -- Native scripts may rebuild this layout after the plugin has attached.
    -- A value differing from our last write is therefore a new native
    -- baseline, while an equal value must not be captured again (which would
    -- recursively accumulate SEARCH_GAP on every update).
    for _, property in ipairs(properties) do
        if current[property] ~= applied[property] then
            baseline[property] = current[property]
        end
    end
end

function Geometry.SameProperties(left, right, properties)
    if left == nil or right == nil then
        return false
    end
    for _, property in ipairs(properties) do
        if left[property] ~= right[property] then
            return false
        end
    end
    return true
end

return Geometry
