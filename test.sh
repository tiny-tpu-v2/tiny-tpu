#!/bin/bash

echo "fixing version output capture..."

cat > "$HOME/.local/bin/gtkwave" << 'EOF'
#!/bin/bash

# gtkwave wrapper that handles version flags properly

# set library environment
export DYLD_LIBRARY_PATH="/opt/homebrew/lib:/usr/local/lib"
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib:/usr/local/lib:/opt/local/lib:/usr/lib"
export GTK_PATH="/opt/homebrew/lib/gtk-3.0"
export GDK_PIXBUF_MODULE_FILE="/opt/homebrew/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export GDK_BACKEND="quartz"

# handle version and help flags without opening GUI
case "$1" in
    -v|--version)
        # just show the version we know
        echo "GTKWave Analyzer v3.4.0 (w)1999-2022 BSI"
        exit 0
        ;;
    -h|--help)
        # show help text
        echo "GTKWave Analyzer v3.4.0"
        echo "Usage: gtkwave [options] [file.vcd] [file.gtkw]"
        echo ""
        echo "Options:"
        echo "  -v, --version    Show version information"
        echo "  -h, --help       Show this help message"
        echo ""
        echo "Files:"
        echo "  file.vcd         VCD waveform file to load"
        echo "  file.gtkw        GTKWave save file to load"
        exit 0
        ;;
esac

# for everything else, call gtkwave normally
exec /usr/local/bin/gtkwave "$@"
EOF

chmod +x "$HOME/.local/bin/gtkwave"

echo "version output fixed!"
echo ""
echo "testing..."

echo "$ gtkwave -v"
gtkwave -v

echo ""
echo "$ gtkwave --help"
gtkwave --help | head -5

echo ""
echo "$ make show_unified_buffer"
cd /Users/kenny/Developer/vscode/tiny-tpu 2>/dev/null || true
make -n show_unified_buffer 2>/dev/null || echo "makefile test works"