#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 Tianling Shen <cnsztl@immortalwrt.org>
# Modified for aarch64_cortex-a53 build

set -o errexit
set -o pipefail

export PKG_SOURCE_DATE_EPOCH="$(date "+%s")"

BASE_DIR="$(cd "$(dirname $0)"; pwd)"
PKG_DIR="$BASE_DIR/.."

# Параметры для вашей архитектуры
TARGET="ipq60xx"
SUBTARGET="generic"
ARCH="aarch64_cortex-a53"
IMMORTALWRT_BRANCH="openwrt-23.05"

function get_mk_value() {
    awk -F "$1:=" '{print $2}' "$PKG_DIR/Makefile" | xargs
}

PKG_NAME="$(get_mk_value "PKG_NAME")"

# Установка зависимостей для сборки
install_build_deps() {
    echo "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential ccache ecj fastjar file g++ gawk \
        gettext git libelf-dev libncurses5-dev libncursesw5-dev \
        libssl-dev python3 python3-distutils python3-setuptools \
        rsync subversion swig time unzip wget xsltproc zlib1g-dev fakeroot
}

# Подготовка ImmortalWrt build system
setup_build_env() {
    echo "Setting up ImmortalWrt build environment..."
    
    if [ ! -d "immortalwrt" ]; then
        git clone --depth 1 --branch "$IMMORTALWRT_BRANCH" \
            https://github.com/immortalwrt/immortalwrt.git immortalwrt
    fi
    
    cd immortalwrt
    
    # Копируем пакет homeproxy в дерево сборки
    mkdir -p package/custom
    cp -r "$PKG_DIR" package/custom/homeproxy
    
    # Базовая конфигурация
    cat > .config << EOF
CONFIG_TARGET_${TARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}_DEVICE_generic=y
CONFIG_PACKAGE_${PKG_NAME}=y
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_sing-box=y
EOF
}

# Сборка через OpenWrt build system
build_with_openwrt() {
    echo "Building with OpenWrt build system..."
    
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    
    # Конфигурируем сборку
    make defconfig
    
    # Собираем только нужный пакет
    echo "Building package: $PKG_NAME"
    make package/custom/homeproxy/compile -j$(nproc) V=s
    
    # Ищем собранный IPK файл
    IPK_FILE=$(find bin/packages/${ARCH}/base -name "${PKG_NAME}*.ipk" | head -1)
    
    if [ -z "$IPK_FILE" ]; then
        echo "Error: IPK file not found!"
        exit 1
    fi
    
    # Копируем результат
    cp "$IPK_FILE" "$BASE_DIR/"
    echo "BUILT_IPK=$(basename $IPK_FILE)" >> $GITHUB_ENV
    echo "Successfully built: $(basename $IPK_FILE)"
}

# Основная функция
main() {
    install_build_deps
    setup_build_env
    build_with_openwrt
}

main "$@"
