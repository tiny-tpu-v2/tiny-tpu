#!/bin/bash

# debug and fix gtkwave app bundle

APP_DIR="$HOME/Applications/GTKWave.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
WRAPPER_SCRIPT="$MACOS_DIR/gtkwave"

echo "debugging gtkwave app bundle..."

# check if app bundle exists
if [ ! -d "$APP_DIR" ]; then
    echo "error: GTKWave.app not found at $APP_DIR"
    exit 1
fi

echo "app bundle found at: $APP_DIR"

# check current wrapper script
echo ""
echo "current wrapper script content:"
echo "================================"
cat "$WRAPPER_SCRIPT"
echo "================================"

# find the actual gtkwave binary
echo ""
echo "searching for actual gtkwave binary..."
ACTUAL_GTKWAVE=""

# check common locations
for path in "/opt/local/bin/gtkwave" "/opt/homebrew/bin/gtkwave" "/usr/local/bin/gtkwave"; do
    if [ -x "$path" ]; then
        echo "found gtkwave binary at: $path"
        ACTUAL_GTKWAVE="$path"
        break
    fi
done

if [ -z "$ACTUAL_GTKWAVE" ]; then
    echo "error: no gtkwave binary found in common locations"
    echo "please install gtkwave using:"
    echo "  sudo port install gtkwave"
    echo "  or"
    echo "  brew install gtkwave"
    exit 1
fi

# test the actual binary
echo ""
echo "testing actual gtkwave binary..."
echo "$ $ACTUAL_GTKWAVE --version"
"$ACTUAL_GTKWAVE" --version 2>&1 | head -3

# create fixed wrapper script
echo ""
echo "creating fixed wrapper script..."
cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash

# gtkwave app bundle wrapper
# calls the actual gtkwave binary with all arguments

GTKWAVE_BIN="$ACTUAL_GTKWAVE"

# check if binary exists
if [ ! -x "\$GTKWAVE_BIN" ]; then
    echo "error: gtkwave binary not found at \$GTKWAVE_BIN"
    exit 1
fi

# execute with all arguments
exec "\$GTKWAVE_BIN" "\$@"
EOF

chmod +x "$WRAPPER_SCRIPT"

echo "fixed wrapper script created"
echo ""
echo "new wrapper content:"
echo "===================="
cat "$WRAPPER_SCRIPT"
echo "===================="

echo ""
echo "testing the app bundle..."
echo "trying to open a test file (if it exists)..."

# test with a vcd file if available
if [ -f "waveforms/unified_buffer.vcd" ]; then
    echo "testing with unified_buffer.vcd..."
    open -a GTKWave "waveforms/unified_buffer.vcd"
else
    echo "no test files found - try running:"
    echo "  make show_unified_buffer"
fi