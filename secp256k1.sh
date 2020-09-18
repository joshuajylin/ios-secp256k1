#!/bin/bash

# Bundle config
: ${BUNDLE:=}
: ${DOWNLOAD_URL:=}
: ${GIT_URL:="git://github.com/bitcoin-core/secp256k1.git"}
: ${LIBRARY:=libsecp256k1.a}

# framework config
: ${FRAMEWORK_NAME:=secp256k1}
: ${FRAMEWORK_VERSION:=A}
: ${FRAMEWORK_CURRENT_VERSION:=1.0.0}
: ${FRAMEWORK_IDENTIFIER:=org.secp256k1lib}

# iphone SDK version
# : ${IPHONE_SDKVERSION:=11.1}
: ${IPHONE_SDKVERSION:=$(echo $(xcodebuild -showsdks) | grep -o  'iphonesimulator[0-9]\+.[0-9]\+' | grep -o  '[0-9]\+.[0-9]\+')}

# macos SDK version
: ${MAC_SDKVERSION:=$(echo $(xcodebuild -showsdks) | grep -o  'macos[0-9]\+.[0-9]\+' | grep -o  '[0-9]\+.[0-9]\+')}

if [ "$1" != "ios" ] && [ "$1" != "mac" ]; then
    echo "Usage: $0 <ios | mac>"
    exit 1
fi

OS_PLATFORM=$1
source shared.sh $OS_PLATFORM

untarLzippedBundle() {
  echo "Untar bundle to $SRC_DIR..."
  tar -zxvf secp256k1-1.0.0.tar.gz -C $SRC_DIR
  doneSection
}
exportConfig() {
  echo "Export configuration..."
  OS_ARCH=$1
  if [ "$OS_ARCH" == "i386" ] || [ "$OS_ARCH" == "x86_64" ]; then
    if [ "$OS_PLATFORM" == "ios" ]; then
        OS_SYSROOT=$XCODE_SIMULATOR_SDK
    else
        if [ "$OS_PLATFORM" == "mac" ] ; then
            OS_SYSROOT=$XCODE_MAC_SDK
        fi
    fi
  else
    OS_SYSROOT=$XCODE_DEVICE_SDK
  fi
  CFLAGS="-arch $OS_ARCH -fPIC -g -Os -pipe --sysroot=$OS_SYSROOT"
  if [ "$OS_PLATFORM" == "ios" ]; then
    if [ "$OS_ARCH" == "armv7s" ] || [ "$OS_ARCH" == "armv7" ]; then
        CFLAGS="$CFLAGS -mios-version-min=6.0"
    else
        CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=7.0"
    fi
  fi
  CXXFLAGS=$CFLAGS
  CPPFLAGS=$CFLAGS
  CC_FOR_BUILD=/usr/bin/clang
  export CC=clang
  export CXX=clang++
  export CFLAGS
  export CXXFLAGS
  export OS_SYSROOT
  export CC_FOR_BUILD
  export PATH="$XCODE_TOOLCHAIN_USR_BIN":"$XCODE_USR_BIN":"$ORIGINAL_PATH"
  echo "OS_ARC: $OS_ARCH"
  echo "CC: $CC"
  echo "CXX: $CXX"
  echo "LDFLAGS: $LDFLAGS"
  echo "CC_FOR_BUILD: $CC_FOR_BUILD"
  echo "CFLAGS: $CFLAGS"
  echo "CXXFLAGS: $CXXFLAGS"
  echo "OS_SYSROOT: $OS_SYSROOT"
  echo "PATH: $PATH"
  doneSection
}

moveHeadersToFramework() {
  echo "Copying includes to $FRAMEWORK_BUNDLE/Headers/..."
  cp -r $BUILD_DIR/armv7/include/*.h  $FRAMEWORK_BUNDLE/Headers/
  doneSection
}

compileSrcForArch() {
  local buildArch=$1
  configureForArch $buildArch
  echo "Building source for architecture $buildArch..."
  ( cd $SRC_DIR/$FRAMEWORK_NAME-$FRAMEWORK_CURRENT_VERSION; \
    echo "Calling make clean..."
    make clean; \
    echo "Calling make check..."
    make check; \
    echo "Calling make..."
    make;
    echo "Calling make install..."
    make install; \
    echo "Place libgmp.a for lipoing..." )
  mv $BUILD_DIR/$buildArch/lib/$LIBRARY $BUILD_DIR/$buildArch
  doneSection
}

configureForArch() {
  local buildArch=$1
  cleanUpSrc
  createDirs
  # untarLzippedBundle
  gitCloneSrc
  echo "Configure for architecture $buildArch..."
  ( cd $SRC_DIR/$FRAMEWORK_NAME-$FRAMEWORK_CURRENT_VERSION; \
    ./autogen.sh && ./configure --prefix $BUILD_DIR/$buildArch --disable-shared --host="none-apple-darwin" --enable-static --disable-assembly --enable-module-recovery)
  doneSection
}

echo "================================================================="
echo "Start"
echo "================================================================="
showConfig
developerToolsPresent
if [ "$ENV_ERROR" == "0" ]; then
  cleanUp
  createDirs
  # downloadSrc
 # untarLzippedBundle
 # gitCloneSrc
  compileSrcForAllArchs
  buildUniversalLib
  moveHeadersToFramework
  buildFrameworkPlist
  echo "Completed successfully.."
else
  echo "Build failed..."
fi
