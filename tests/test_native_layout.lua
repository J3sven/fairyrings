local NativeLayout = {}

local function assertNativeListGeometry(context)
    assert(context.logContent.y == 0)
    assert(context.logContent.height == 300)
    assert(context.scrollbar.y == 0)
    assert(context.scrollbar.height == 300)
end

function NativeLayout.AssertReserved(context)
    assert(context.logContentHolder.y == 94)
    assert(context.logContentHolder.height == 266)
    assert(context.darkLine.y == 92)
    assert(context.lightLine.y == 93)
    assertNativeListGeometry(context)

    assert(not context.firstCode.hidden)
    assert(not context.secondCode.hidden)
    assert(not context.sortDropdownChild.hidden)
    assert(context.sortDropdownChild.y == 5)
    assert(not context.quickTeleportCheckbox.hidden)
    assert(not context.quickTeleportCheckboxClick.hidden)
    assert(context.quickTeleportCheckbox.y == 12)
    assert(context.quickTeleportCheckboxClick.y == 12)
    assert(context.firstCode.y == 0)
    assert(context.firstLocation.y == 0)
    assert(context.firstClick.y == 0)
    assert(context.secondCode.y == 30)
    assert(context.secondLocation.y == 30)
    assert(context.secondClick.y == 30)
end

function NativeLayout.AssertRestored(context)
    assert(context.darkLine.y == 58)
    assert(context.lightLine.y == 59)
    assertNativeListGeometry(context)
end

function NativeLayout.ReopenAndShutdown(context)
    context.logContentHolder:SetSize(180, 300)
    context.logContentHolder.visible = true

    -- Required listener failures must roll back the layout and created field,
    -- leaving the plugin dormant so a later poll can retry cleanly.
    context.setFocusSubscribeFailure(true)
    context.tick(100)
    assert(context.createdSearch.destroyed)
    assert(context.createdSearch.root.subscription == nil)
    assert(context.logContentHolder.y == 60)
    assert(context.logContentHolder.height == 300)

    context.setFocusSubscribeFailure(false)
    context.setKeyboardSubscribeFailure(true)
    context.tick(150)
    assert(context.createdSearch.destroyed)
    assert(context.createdCaret.destroyed)
    assert(context.createdSelection.destroyed)
    assert(context.createdSelectionText.destroyed)
    assert(context.keyboardListener.subscription == nil)
    assert(context.createdSearch.root.subscription == nil)
    assert(context.logContentHolder.y == 60)
    assert(context.logContentHolder.height == 300)

    context.setKeyboardSubscribeFailure(false)
    context.tick(200)
    assert(not context.createdSearch.destroyed)
    assert(context.searchOptions.width == 280)
    assert(context.createdSearch.root.width == 280)
    NativeLayout.AssertReserved(context)

    -- Native scripts can reapply their geometry. The next plugin update must
    -- reserve exactly one strip again without accumulating another offset.
    context.firstCode:SetPos(context.firstCode.x, 0)
    context.firstLocation:SetPos(context.firstLocation.x, 0)
    context.firstClick:SetPos(context.firstClick.x, 0)
    context.secondCode:SetPos(context.secondCode.x, 30)
    context.secondLocation:SetPos(context.secondLocation.x, 30)
    context.secondClick:SetPos(context.secondClick.x, 30)
    context.logContentHolder:SetPos(10, 60)
    context.logContentHolder:SetSize(280, 300)
    context.logContent.scrollHeight = 100
    context.scrollbar:SetPos(280, 0)
    context.scrollbar:SetSize(20, 300)
    context.darkLine:SetPos(0, 58)
    context.lightLine:SetPos(0, 59)
    context.tick(225)

    NativeLayout.AssertReserved(context)
    assert(context.createdSearch.root.width == 280)
    assert(context.logContent.scrollHeight == 100)

    for logicTick = 226, 249 do
        context.tick(logicTick)
        assert(context.firstCode.y == 0)
        assert(context.secondCode.y == 30)
    end

    context.shutdown()
    assert(context.logContentHolder.y == 60)
    assert(context.logContentHolder.height == 300)
    NativeLayout.AssertRestored(context)
    assert(context.logContent.scrollHeight == 100)
end

return NativeLayout
