# color-ascii

`ascii` renders macOS-readable images as colored Unicode full-block characters in the terminal.

It is a native Objective-C command-line tool built with `clang`. It uses AppKit/CoreGraphics, which means it can read common image formats supported by macOS, including PNG, JPEG, HEIC, TIFF, GIF, and BMP.

## Install

```zsh
curl -L https://github.com/Bluerayfoo/color-ascii/archive/refs/heads/main.tar.gz \
  | tar -xz -C /tmp \
  && /tmp/color-ascii-main/install.sh
```

This installs:

```txt
~/cmds/ascii
```

Requirements: macOS and `clang`, which is included with Xcode Command Line Tools:

```zsh
xcode-select --install
```

To choose another install folder:

```zsh
ASCII_INSTALL_DIR=/usr/local/bin /tmp/color-ascii-main/install.sh
```

## Use

```zsh
ascii ~/Desktop/tai-hat.png
ascii ~/Desktop/photo.heic
ascii ~/Desktop/image.jpeg
```

Force a specific output size:

```zsh
ascii ~/Desktop/tai-hat.png --cols 300 --rows 120
```

Use 24-bit truecolor instead of nearest ANSI-256 color:

```zsh
ascii ~/Desktop/tai-hat.png --truecolor
```

## Notes

By default, `ascii` uses nearest ANSI-256 foreground colors and prints one `█` per sampled pixel. This keeps the output smaller and smoother than truecolor while still preserving color.
