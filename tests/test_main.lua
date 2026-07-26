package.path = "fairyrings/?.lua;" .. package.path

local context = require("tests/support/fixture")
local DestinationFilter = require("tests/test_destination_filter")
local Lifecycle = require("tests/test_main_lifecycle")
local NativeLayout = require("tests/test_native_layout")
local SearchUI = require("tests/test_search_ui")

Lifecycle.Open(context)
NativeLayout.AssertReserved(context)
SearchUI.Run(context)
DestinationFilter.Run(context)
Lifecycle.Close(context)
NativeLayout.AssertRestored(context)
NativeLayout.ReopenAndShutdown(context)

print("fairyrings tests passed")
