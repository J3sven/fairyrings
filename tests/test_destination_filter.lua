local DestinationFilter = {}

local function press(context, character)
    context.keyboardListener.subscription(
        nil,
        0,
        string.byte(character)
    )
end

local function backspace(context)
    context.keyboardListener.subscription(nil, 8, 0)
end

local function rebuildNativeRows(context)
    context.firstCode.hidden = false
    context.firstLocation.hidden = false
    context.firstClick.hidden = false
    context.firstFavourite.hidden = false
    context.firstFavouriteClick.hidden = false
    context.secondCode.hidden = false
    context.secondLocation.hidden = false
    context.secondClick.hidden = false
    context.secondFavourite.hidden = false
    context.secondFavouriteClick.hidden = false

    context.firstCode:SetPos(context.firstCode.x, 0)
    context.firstLocation:SetPos(context.firstLocation.x, 0)
    context.firstClick:SetPos(context.firstClick.x, 0)
    context.firstFavourite:SetPos(context.firstFavourite.x, 0)
    context.firstFavouriteClick:SetPos(
        context.firstFavouriteClick.x,
        0
    )
    context.secondCode:SetPos(context.secondCode.x, 30)
    context.secondLocation:SetPos(context.secondLocation.x, 30)
    context.secondClick:SetPos(context.secondClick.x, 30)
    context.secondFavourite:SetPos(context.secondFavourite.x, 30)
    context.secondFavouriteClick:SetPos(
        context.secondFavouriteClick.x,
        30
    )
end

function DestinationFilter.Run(context)
    press(context, "z")
    assert(context.firstCode.hidden)
    assert(context.firstLocation.hidden)
    assert(context.firstClick.hidden)
    assert(context.firstFavourite.hidden)
    assert(context.firstFavouriteClick.hidden)
    assert(not context.sortDropdownChild.hidden)
    assert(context.sortDropdownChild.y == 5)
    assert(not context.quickTeleportCheckbox.hidden)
    assert(not context.quickTeleportCheckboxClick.hidden)
    assert(context.quickTeleportCheckbox.y == 12)
    assert(context.quickTeleportCheckboxClick.y == 12)
    assert(not context.secondCode.hidden)
    assert(not context.secondLocation.hidden)
    assert(not context.secondClick.hidden)
    assert(not context.secondFavourite.hidden)
    assert(not context.secondFavouriteClick.hidden)
    assert(context.secondCode.y == 0)
    assert(context.secondLocation.y == 0)
    assert(context.secondClick.y == 0)
    assert(context.createdCaret.x == 26)
    assert(context.logContent.scrollY == 0)
    assert(context.logContent.scrollPosCalls == 1)

    -- Periodic filtering must not continually force the scroll position.
    context.logContent.scrollY = 40
    context.tick(75)
    assert(context.logContent.scrollY == 40)
    assert(context.logContent.scrollPosCalls == 1)

    -- The click animation may rebuild every row for multiple frames. The query
    -- must be enforced on every intervening logic tick, not just once.
    assert(context.secondClick.subscription())
    for logicTick = 76, 78 do
        rebuildNativeRows(context)
        context.tick(logicTick)
        assert(context.firstCode.hidden)
        assert(context.firstLocation.hidden)
        assert(context.firstClick.hidden)
        assert(context.firstFavourite.hidden)
        assert(context.firstFavouriteClick.hidden)
        assert(not context.secondCode.hidden)
        assert(not context.secondLocation.hidden)
        assert(not context.secondClick.hidden)
        assert(context.secondCode.y == 0)
        assert(context.secondLocation.y == 0)
        assert(context.secondClick.y == 0)
    end

    backspace(context)
    assert(not context.firstCode.hidden)
    assert(not context.firstLocation.hidden)
    assert(not context.firstClick.hidden)
    assert(not context.firstFavourite.hidden)
    assert(not context.firstFavouriteClick.hidden)
    assert(not context.secondCode.hidden)
    assert(not context.secondLocation.hidden)
    assert(not context.secondClick.hidden)
    assert(not context.secondFavourite.hidden)
    assert(not context.secondFavouriteClick.hidden)
    assert(context.firstCode.y == 0)
    assert(context.firstLocation.y == 0)
    assert(context.firstClick.y == 0)
    assert(context.secondCode.y == 30)
    assert(context.secondLocation.y == 30)
    assert(context.secondClick.y == 30)
    assert(context.createdCaret.x == 18)
    assert(context.logContent.scrollY == 0)
    assert(context.logContent.scrollPosCalls == 2)

    for character in ("dkr"):gmatch(".") do
        press(context, character)
    end
    assert(not context.firstCode.hidden)
    assert(not context.firstLocation.hidden)
    assert(not context.firstClick.hidden)
    assert(context.secondCode.hidden)
    assert(context.secondLocation.hidden)
    assert(context.secondClick.hidden)

    for _ = 1, 3 do
        backspace(context)
    end
    for character in ("grand exchange"):gmatch(".") do
        press(context, character)
    end
    assert(not context.firstCode.hidden)
    assert(not context.firstLocation.hidden)
    assert(not context.firstClick.hidden)
    assert(context.secondCode.hidden)
    assert(context.secondLocation.hidden)
    assert(context.secondClick.hidden)
end

return DestinationFilter
