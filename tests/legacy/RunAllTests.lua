-- Master Test Runner for Better Thunder Mod
-- Run this file from the Lua console with: require "tests/RunAllTests"
-- This will execute all test suites and provide a summary

print("")
print("========================================")
print("  Better Thunder (B42) - Test Suite")
print("========================================")
print("")

local totalPassed = 0
local totalFailed = 0
local testFiles = {}

-- Helper to run a test file and collect results
local function runTest(testName, testPath)
    print("")
    print("----------------------------------------")
    print("Running: " .. testName)
    print("----------------------------------------")

    local success, result = pcall(require, testPath)

    if success and result then
        totalPassed = totalPassed + (result.passed or 0)
        totalFailed = totalFailed + (result.failed or 0)
        table.insert(testFiles, {
            name = testName,
            passed = result.passed or 0,
            failed = result.failed or 0,
            success = true
        })
    else
        print("[ERROR] Failed to run test: " .. testName)
        if result then
            print("[ERROR] " .. tostring(result))
        end
        table.insert(testFiles, {
            name = testName,
            passed = 0,
            failed = 1,
            success = false
        })
        totalFailed = totalFailed + 1
    end
end

-- Run all test suites
print("Starting test execution...")
print("")

-- Run shared tests (works on both client and server)
runTest("Thunder_Shared", "tests/Thunder_Shared_Test")

-- Run server tests (only on server)
if not isClient() then
    runTest("Thunder_Server", "tests/Thunder_Server_Test")
else
    print("⚠ Skipping Thunder_Server tests (client side)")
end

-- Run client tests (only on client)
if not isServer() then
    runTest("Thunder_Client", "tests/Thunder_Client_Test")
    runTest("Thunder_UI", "tests/Thunder_UI_Test")
else
    print("⚠ Skipping Thunder_Client tests (server side)")
    print("⚠ Skipping Thunder_UI tests (server side)")
end

-- Print final summary
print("")
print("========================================")
print("  Final Test Summary")
print("========================================")
print("")

for _, test in ipairs(testFiles) do
    local status = test.success and "✓" or "✗"
    local color = (test.failed == 0) and "✓" or "⚠"
    print(string.format("%s %s: %d passed, %d failed",
        color, test.name, test.passed, test.failed))
end

print("")
print("----------------------------------------")
print(string.format("TOTAL: %d passed, %d failed", totalPassed, totalFailed))
print("----------------------------------------")
print("")

if totalFailed == 0 then
    print("🎉 ✓ ALL TESTS PASSED! 🎉")
else
    print("⚠ Some tests failed - review output above")
end

print("")
print("========================================")
print("")

return {
    passed = totalPassed,
    failed = totalFailed,
    tests = testFiles
}
