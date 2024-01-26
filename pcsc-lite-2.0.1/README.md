A failed attempt to modify CCID 2.0.1 for non-root Termux, with Termux-usb.

Run in Termux.

```sh
./configure --exec-prefix=$PREFIX --sbindir=$PREFIX/bin --enable-ipcdir=$PREFIX/var/run --disable-libsystemd --disable-libudev CFLAGS="-Wno-implicit-function-declaration -ggdb -Wextra" --disable-polkit --prefix=$PREFIX -C
make -j8 && make install
termux-usb -r `termux-usb -l | jq -rM .[0]`
termux-usb -e ./run.sh `termux-usb -l | jq -rM .[0]`
```
