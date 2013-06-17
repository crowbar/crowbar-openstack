#!/bin/bash
OAT_PKGS=(OAT-Appraiser-Base-OATapp-1.0.0-2.x86_64.deb)

bc_needs_build() {
    for pkg in ${OAT_PKGS[@]}; do
        [[ -f $BC_CACHE/$OS_TOKEN/pkgs/$pkg ]] && continue
        return 0
    done
    return 1
}

bc_build() {
    sudo cp "$BC_DIR/build_in_chroot.sh" "$CHROOT/tmp"
    in_chroot /tmp/build_in_chroot.sh
    local pkg
    for pkg in "${OAT_PKGS[@]}"; do
        [[ -f $BC_CACHE/$OS_TOKEN/pkgs/$pkg ]] || \
            die "OAT build process did not build $pkg!"
        if [[ $CURRENT_CACHE_BRANCH ]]; then
            (cd "$BC_CACHE/$OS_TOKEN/pkgs"; git add "$pkg")
        fi
    done
}
