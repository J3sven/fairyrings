local Lifecycle = {}

function Lifecycle.Open(context)
    assert(context.subscribed ~= nil)

    context.tick(1)
    assert(context.searchOptions == nil)
    assert(context.getInterfaceCalls == 0)
    assert(context.keyboardListener.subscription == nil)
    assert(not context.firstCode.hidden)
    assert(not context.secondCode.hidden)

    context.logContentHolder.visible = true
    context.tick(50)
    assert(context.searchOptions ~= nil)
    assert(context.getInterfaceCalls == 1)
    assert(context.keyboardListener.subscription ~= nil)
end

function Lifecycle.Close(context)
    context.logContentHolder.visible = false
    context.tick(80)
    assert(context.keyboardListener.subscription == nil)
    assert(context.createdSearch.destroyed)
    assert(context.createdCaret.destroyed)
    assert(context.createdSelection.destroyed)
    assert(context.createdSelectionText.destroyed)
    assert(context.firstClick.subscription == nil)
    assert(context.secondClick.subscription == nil)
    assert(context.firstFavouriteClick.subscription == nil)
    assert(context.secondFavouriteClick.subscription == nil)

    local callsAfterClose = context.getInterfaceCalls
    for logicTick = 81, 99 do
        context.tick(logicTick)
    end
    assert(context.getInterfaceCalls == callsAfterClose)
end

return Lifecycle
