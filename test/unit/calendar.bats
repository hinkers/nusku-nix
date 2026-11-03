# nusku-calendar-events (Python, evolution-data-server): no calendar service here, so only what
# can be checked without one. The shell's calendar (config/quickshell/nusku/menus/Calendar.qml)
# reads its JSON.

@test "nusku-calendar-events is valid Python" {
    python3 -c 'import sys, ast; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' scripts/nusku-calendar-events
}

@test "nusku-calendar-events has no GUI (no GTK, no layer shell)" {
    ! grep -qE 'Gtk|Gdk|LayerShell|LD_PRELOAD' scripts/nusku-calendar-events || false
}

@test "nusku-calendar-events: the JSON the calendar reads (gnomeCalendar, days -> time, summary, uid)" {
    grep -qF '"gnomeCalendar"' scripts/nusku-calendar-events
    grep -qF '"days"' scripts/nusku-calendar-events
    grep -qF 'r.gnomeCalendar' config/quickshell/nusku/menus/Calendar.qml
    for k in time summary uid; do
        grep -qF "\"$k\"" scripts/nusku-calendar-events
        grep -qF "modelData.$k" config/quickshell/nusku/menus/Calendar.qml
    done
}

@test "the calendar points at this repo's installer for GNOME Calendar" {
    grep -qF './install.sh --apps' config/quickshell/nusku/menus/Calendar.qml
}
