local SearchUI = {}

function SearchUI.Run(context)
    local search = context.createdSearch
    local caret = context.createdCaret
    local selection = context.createdSelection
    local selectionText = context.createdSelectionText

    assert(search.root.x == 10)
    assert(search.root.y == 51)
    assert(search.root.width == 280)
    assert(search.root.hidden == false)
    assert(search.root.alpha == 1)
    assert(search.root.movedToFront)
    assert(context.searchOptions.maxLength == nil)
    assert(caret ~= nil)
    assert(caret.x == 18)
    assert(caret.y == 56)
    assert(caret.height == 18)
    assert(caret.fill)
    assert(caret.movedToFront)
    assert(selection ~= nil)
    assert(selection.hidden)
    assert(selection.fill)
    assert(selection.rgba == 0x4A4640FF)
    assert(selection.clickthrough)
    assert(selection.movedToFront)
    assert(selectionText ~= nil)
    assert(selectionText.hidden)
    assert(selectionText.clickthrough)
    assert(selectionText.movedToFront)
    assert((context.logContent.scrollPosCalls or 0) == 0)

    search.root.subscription()
    assert(caret.hidden)
    context.searchOptions.onChange(
        nil,
        ui.InputFieldActionResult.SUBMIT_ON_FOCUS_LOSS,
        ""
    )
    assert(not caret.hidden)

    context.logContent.scrollY = 50
    context.tick(55)
    assert(context.logContent.scrollY == 50)
    assert((context.logContent.scrollPosCalls or 0) == 0)

    -- Favourite hotkeys remain native input and never enter the search query.
    for digit = 1, 9 do
        local forwarded = context.keyboardListener.subscription(
            nil,
            0,
            string.byte(tostring(digit))
        )
        assert(forwarded)
    end
    assert(search.text == "")

    -- Ctrl+A uses native selection when the real field is focused.
    search.root.subscription()
    context.setControlDown(true)
    local forwarded = context.keyboardListener.subscription(
        nil,
        GameKey.A,
        1
    )
    context.setControlDown(false)
    assert(forwarded)
    assert(caret.hidden)

    -- Before the field is clicked, the Fairy Ring keyboard listener emulates
    -- select-all so replacement and deletion behave the same way.
    context.searchOptions.onChange(
        nil,
        ui.InputFieldActionResult.SUBMIT_ON_FOCUS_LOSS,
        ""
    )
    context.keyboardListener.subscription(nil, 0, string.byte("a"))
    context.keyboardListener.subscription(nil, 0, string.byte("b"))
    context.setControlDown(true)
    assert(not context.keyboardListener.subscription(
        nil,
        GameKey.A,
        1
    ))
    context.setControlDown(false)
    assert(not selection.hidden)
    assert(selection.x == 18)
    assert(selection.y == 56)
    assert(selection.width == 16)
    assert(selection.height == 18)
    assert(not selectionText.hidden)
    assert(selectionText.content == "ab")
    assert(selectionText.x == 18)
    assert(selectionText.y == 51)
    assert(selectionText.width == 16)
    assert(selectionText.height == 28)
    context.keyboardListener.subscription(nil, 0, string.byte("x"))
    assert(search.text == "x")
    assert(selection.hidden)
    assert(selectionText.hidden)

    context.setControlDown(true)
    context.keyboardListener.subscription(nil, GameKey.A, 1)
    context.setControlDown(false)
    context.keyboardListener.subscription(nil, GameKey.BACKSPACE, 0)
    assert(search.text == "")
    context.logContent.scrollPosCalls = 0
end

return SearchUI
