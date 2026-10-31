# nusku-calendar (Python + GTK4): no display here, so only what can be checked without one.
# The Nix package (modules/home/panels.nix) is built for real once; see the task report.

@test "nusku-calendar is valid Python" {
    python3 -c 'import sys, ast; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' scripts/nusku-calendar
}

@test "nusku-calendar preloads the gtk4-layer-shell library the package points it at" {
    grep -qF 'os.environ.get("NUSKU_LAYER_SHELL"' scripts/nusku-calendar
    ! grep -qF '/usr/lib/' scripts/nusku-calendar || false
}

@test "nusku-calendar points at this repo's installer for GNOME Calendar" {
    grep -qF './install.sh --apps' scripts/nusku-calendar
}
