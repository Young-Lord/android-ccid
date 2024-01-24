# config
ANDROID_PLATFORM=24
MAKEJ=$(nproc)
# set default ARCH if undefined
: ${ARCH=x86_64}
ARCH_SUFFIX=android
# set android arch name aarch64 arm mips64el mipsel x86_64 x86
case $ARCH in
  arm64|aarch64|arm64-v8a) ARCH=arm64; ANDROID_BIN_PREFIX=aarch64; ANDROID_ARCH_NAME=arm64-v8a;;
  arm|armv7a|armeabi-v7a) ARCH=arm; ANDROID_BIN_PREFIX=armv7a; ARCH_SUFFIX=androideabi; ANDROID_ARCH_NAME=armeabi-v7a;;
  mips64|mips64el) ARCH=mips64; ANDROID_BIN_PREFIX=mips64el; ANDROID_ARCH_NAME=mips64el;;
  mips|mipsel) ARCH=mips; ANDROID_BIN_PREFIX=mipsel; ANDROID_ARCH_NAME=mipsel;;
  x86_64|x64|amd64) ARCH=x86_64; ANDROID_BIN_PREFIX=x86_64; ANDROID_ARCH_NAME=x86_64;;
  x86|i686) ARCH=x86; ANDROID_BIN_PREFIX=i686; ANDROID_ARCH_NAME=x86;;
  *) echo "Unknown ARCH: $ARCH"; exit 1;;
esac

# install dependencies
sudo apt -y install google-android-ndk-installer python-is-python3 \
  flex pkg-config build-essential gcc-multilib \
  wget git > /dev/null

# set up environment
LOCAL_ARCH=$(uname -m)
LOCAL_HOST=$LOCAL_ARCH-linux
TARGET_HOST=$ARCH-linux-android
BASEDIR=`echo ~/android`
mkdir -p $BASEDIR
cd $BASEDIR
NDK=`echo /usr/lib/android-ndk`
export ANDROID_NDK_ROOT=$NDK
export PREFIX=$BASEDIR/build/android-$ARCH
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig"
mkdir -p $PREFIX $PREFIX/{include,lib}
ANDROID_SYSROOT=$NDK/platforms/android-$ANDROID_PLATFORM/arch-$ARCH
TOOLCHAIN_DIR=$NDK/toolchains/llvm/prebuilt/linux-$LOCAL_ARCH
export CROSS_PREFIX=$ANDROID_BIN_PREFIX-linux-$ARCH_SUFFIX$ANDROID_PLATFORM-
export PATH=$TOOLCHAIN_DIR/bin:$PATH
ls -al $TOOLCHAIN_DIR/bin
export CC=${CROSS_PREFIX}clang
export CXX=${CROSS_PREFIX}clang++
export CFLAGS=-I$ANDROID_SYSROOT/usr/include
export LDFLAGS="-llog -lm -lstdc++ -L$ANDROID_SYSROOT/usr/lib"
COMMON_CONFIGURE_FLAGS="--prefix=$PREFIX --build=$LOCAL_HOST --host=$TARGET_HOST --enable-shared"

wget --no-verbose https://www.zlib.net/zlib-1.3.1.tar.gz https://pcsclite.apdu.fr/files/pcsc-lite-2.0.1.tar.bz2 https://ccid.apdu.fr/files/ccid-1.5.5.tar.bz2
tar xf zlib-*.tar.gz
tar xf pcsc-lite-*.tar.bz2
tar xf ccid-*.tar.bz2
rm *.tar.*
git -c advice.detachedHead=false clone https://github.com/libusb/libusb.git -b v1.0.26 --depth 1 libusb > /dev/null

pushd zlib-*
./configure --prefix=$PREFIX || cat *.log
make -j$MAKEJ
make install
export ZLIB_CFLAGS="-I$PREFIX/include"
export ZLIB_LIBS="-lz -L$PREFIX/lib"
popd

pushd libusb
cd android/jni
$NDK/ndk-build USE_PC_NAME=0
cp -r ../libs/$ANDROID_ARCH_NAME/* $PREFIX/lib
cp ../../libusb/libusb.h $PREFIX/include
export LIBUSB_CFLAGS="-I$PREFIX/include"
export LIBUSB_LIBS="-lusb1.0 -L$PREFIX/lib"
popd

pushd pcsc-lite-*
# magic!!!
./configure $COMMON_CONFIGURE_FLAGS \
  LIBUSB_CFLAGS="$LIBUSB_CFLAGS" LIBUSB_LIBS="$LIBUSB_LIBS" \
  --disable-libsystemd --disable-libudev --disable-polkit || cat config.log
make -j$MAKEJ
make install -k
export PCSC_CFLAGS="-I$PREFIX/include/PCSC"
export PCSC_LIBS="-lpcsclite -L$PREFIX/lib"
popd

pushd ccid-*
./configure $COMMON_CONFIGURE_FLAGS \
  ZLIB_CFLAGS="$ZLIB_CFLAGS" ZLIB_LIBS="$ZLIB_LIBS" \
  LIBUSB_CFLAGS="$LIBUSB_CFLAGS" LIBUSB_LIBS="$LIBUSB_LIBS" \
  PCSC_CFLAGS="$PCSC_CFLAGS" PCSC_LIBS="$PCSC_LIBS" \
  --enable-embedded || cat config.log
make -j$MAKEJ
make install -k
CCID_INCLUDE="$PREFIX/include/ccid"
mkdir -p "$CCID_INCLUDE"
(cd `pwd`/src && find . -name '*.h' -print | tar --create --files-from -) | (cd "$CCID_INCLUDE" && tar xfp -)
popd

