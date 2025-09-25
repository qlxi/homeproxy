#!/bin/bash
set -e

echo "=== Building Homeproxy for OpenWrt ==="

# Параметры сборки
TARGET="ipq60xx"
SUBTARGET="generic"
ARCH="aarch64_cortex-a53"
OPENWRT_VERSION="23.05"
IMMORTALWRT_REPO="https://github.com/immortalwrt/immortalwrt"
IMMORTALWRT_BRANCH="openwrt-23.05"

# Установка зависимостей
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential ccache ecj fastjar file g++ gawk \
    gettext git libelf-dev libncurses5-dev libncursesw5-dev \
    libssl-dev python3 python3-distutils python3-setuptools \
    rsync subversion swig time unzip wget xsltproc zlib1g-dev fakeroot

# Клонирование ImmortalWrt
echo "Cloning ImmortalWrt..."
if [ ! -d "immortalwrt" ]; then
    git clone --depth 1 --branch "$IMMORTALWRT_BRANCH" "$IMMORTALWRT_REPO" immortalwrt
else
    echo "ImmortalWrt already exists, updating..."
    cd immortalwrt
    git pull
    cd ..
fi

# Клонирование homeproxy package
echo "Setting up homeproxy package..."
mkdir -p immortalwrt/package/custom
cd immortalwrt/package/custom

if [ ! -d "homeproxy" ]; then
    git clone https://github.com/immortalwrt/homeproxy.git
else
    echo "Homeproxy package exists, updating..."
    cd homeproxy
    git pull
    cd ..
fi

cd ../../..

# Настройка конфигурации
echo "Configuring build..."
cd immortalwrt

# Базовая конфигурация
cat > .config << EOF
CONFIG_TARGET_${TARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}_DEVICE_generic=y
CONFIG_PACKAGE_homeproxy=y
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_sing-box=y
EOF

# Обновление feeds
echo "Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# Сборка пакета
echo "Building homeproxy package..."
make package/homeproxy/compile -j$(ncp u) V=s

# Поиск собранного пакета
IPK_FILE=$(find bin/packages/${ARCH}/base -name "homeproxy*.ipk" | head -1)

if [ -z "$IPK_FILE" ]; then
    echo "Error: IPK file not found!"
    exit 1
fi

# Копирование пакета в корневую директорию
cp "$IPK_FILE" ../../
cd ..

echo "=== Build completed successfully ==="
echo "IPK file: $(basename $IPK_FILE)"
