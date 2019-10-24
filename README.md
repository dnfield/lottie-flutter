# LottieFlutter

[![Build Status](https://travis-ci.org/dnfield/lottie-flutter.svg?branch=master)](https://travis-ci.org/fabiomsr/lottie-flutter)
[![Coverage Status](https://coveralls.io/repos/github/dnfield/lottie-flutter/badge.svg)](https://coveralls.io/github/fabiomsr/lottie-flutter)

Lottie-Flutter is based on [Lottie-Android](https://github.com/airbnb/lottie-android).

Original effort by [Fabiomsr](https://github.com/fabiomsr).

Lottie is a mobile library that parses [Adobe After Effects](http://www.adobe.com/products/aftereffects.html) animations exported as json with [Bodymovin](https://github.com/bodymovin/bodymovin) and renders them natively on mobile!

## Current status

Achived rendering parity with lottie-android except for dash paths.

All samples included render.  Motorcycle has some issues still, but also has issues on lottie-android (due to using effects that aren't supported).

## TODO

- [x] DashPathEffect ★ [#9641](https://github.com/flutter/flutter/issues/9641)
- [ ] Add support for effects
- [ ] Improve support for path operation/combinations
- [ ] Support changing colors/timings the way lottie-android does
- [ ] Support scaling larger or smaller than the containing widget?
- [ ] Make more Dart/Flutter like.  In particular, I'd like to split parsing up.

## Lottie Files attribution

The files in this project are from LottieFiles.com

- [assets/checked_done_.json by daPulse](https://www.lottiefiles.com/433-checked-done)
- [assets/emoji_shock.json by Pixel Buddha](https://www.lottiefiles.com/44-emoji-shock)
- [assets/empty_box.json by Hoài Lê](https://www.lottiefiles.com/629-empty-box)
- [assets/favourite_app_icon.json by Michael Harvey](https://www.lottiefiles.com/72-favourite-app-icon)
- [assets/hamburger_arrow.json by ???](https://www.lottiefiles.com/63-hamburger-arrow-transition)
- [assets/happy_gift.json by Jojo Lafrite](https://www.lottiefiles.com/1368-happy-gift)
- [assets/Indicators2.json by by Eddy Gann](https://www.lottiefiles.com/539-page-indicators-square)
- [assets/motorcycle.json by Mohammed Zourob](https://www.lottiefiles.com/29-motorcycle)
- [assets/mulzi.json by ???](https://www.lottiefiles.com/113-muzli-beacon)
- [assets/preloader.json by ???](https://www.lottiefiles.com/51-preloader)
- [assets/walkthrough.json taken from Lottie Preview for Android](https://github.com/airbnb/lottie-android)
