# config
ARCH=x86_64
ANDROID_PLATFORM=android-24
MAKEJ=$(nproc)

# install dependencies
sudo apt -y install google-android-ndk-installer python-is-python3 \
  flex pkg-config build-essential gcc-multilib \
  wget git

# set up environment
LOCAL_ARCH=$(uname -m)
LOCAL_HOST=$LOCAL_ARCH-linux
TARGET_HOST=$ARCH-linux-android
BASEDIR=`echo ~/android`
mkdir -p $BASEDIR
cd $BASEDIR
NDK=`echo /usr/lib/android-ndk/android-ndk-*`
TOOLCHAIN_DIR=`echo ~/android-toolchain`
export PREFIX=$BASEDIR/build/android-$ARCH
mkdir -p $PREFIX $PREFIX/{include,lib}
ANDROID_PREFIX=$NDK/platforms/$ANDROID_PLATFORM/arch-$ARCH

"$NDK/build/tools/make-standalone-toolchain.sh" --arch=$ARCH --platform=$ANDROID_PLATFORM "--install-dir=$TOOLCHAIN_DIR" --verbose
export CROSS_PREFIX=$ARCH-linux-android-
export PATH=$TOOLCHAIN_DIR/bin:$PATH
export CC=$ARCH-linux-android-clang
export CXX=$ARCH-linux-android-clang++
export CFLAGS=-I$ANDROID_PREFIX/usr/include

wget https://www.zlib.net/zlib-1.3.1.tar.gz https://pcsclite.apdu.fr/files/pcsc-lite-2.0.1.tar.bz2 https://ccid.apdu.fr/files/ccid-1.5.5.tar.bz2
tar -xvf zlib-*.tar.gz
tar -xvf pcsc-lite-*.tar.bz2
tar -xvf ccid-*.tar.bz2
rm *.tar.*
git clone https://github.com/libusb/libusb.git -b v1.0.26 --depth 1 libusb

pushd zlib-*
./configure
make -j$MAKEJ
make install
export ZLIB_CFLAGS="-I$PREFIX/include"
export ZLIB_LIBS="-lz -L$PREFIX/lib"
popd

pushd libusb
cd android/jni
$NDK/ndk-build
cp -r libs/$ARCH/* $PREFIX/lib
cp ../../libusb/libusb.h $PREFIX/include
export LIBUSB_CFLAGS="-I$PREFIX/include"
export LIBUSB_LIBS="-lusb1.0 -L$PREFIX/lib"
popd

pushd pcsc-lite-*
# magic!!!
./configure --build=$LOCAL_HOST --host=$TARGET_HOST \
  --enable-shared --disable-libsystemd --disable-libudev --disable-polkit
make -j$MAKEJ
make install -k
export PCSC_CFLAGS="-I$PREFIX/include/PCSC"
export PCSC_LIBS="-lpcsclite -L$PREFIX/lib"
popd

pushd ccid-*
./configure --build=$LOCAL_HOST --host=$TARGET_HOST \
  --enable-shared --enable-embedded
popd

