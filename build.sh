# config
ARCH=x86_64
ANDROID_PLATFORM=24
MAKEJ=$(nproc)

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
ANDROID_PREFIX=$NDK/platforms/$ANDROID_PLATFORM/arch-$ARCH
TOOLCHAIN_DIR=$NDK/toolchains/llvm/prebuilt/linux-$LOCAL_ARCH
export CROSS_PREFIX=$ARCH-linux-android$ANDROID_PLATFORM-
export PATH=$TOOLCHAIN_DIR/bin:$PATH
export CC=${CROSS_PREFIX}clang
export CXX=${CROSS_PREFIX}clang++
export CFLAGS=-I$ANDROID_PREFIX/usr/include
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
cp -r ../libs/$ARCH/* $PREFIX/lib
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
popd

