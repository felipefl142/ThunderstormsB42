#!/bin/bash
# run_busted.sh
# Test runner for Busted test framework

set -e

# Change to tests directory
cd "$(dirname "$0")"

echo "=========================================="
echo "Better Thunder (B42) - Busted Test Suite"
echo "=========================================="
echo ""

# Find lua5.1 and busted
LUA=""
if command -v lua5.1 &> /dev/null; then
    LUA="lua5.1"
elif command -v lua &> /dev/null; then
    LUA="lua"
else
    echo "ERROR: Lua 5.1 is not installed!"
    exit 1
fi

BUSTED="/usr/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted"
if [ ! -f "$BUSTED" ]; then
    echo "ERROR: Busted is not installed or not found at $BUSTED!"
    echo ""
    echo "Install with: luarocks install busted"
    echo ""
    exit 1
fi

# Run tests with verbose output and colored terminal
echo "Running all tests..."
echo ""

$LUA $BUSTED --verbose --output=utfTerminal spec/

# Capture exit code
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "=========================================="
    echo "✓ All tests passed!"
    echo "=========================================="
else
    echo "=========================================="
    echo "✗ Some tests failed"
    echo "=========================================="
fi

exit $EXIT_CODE
