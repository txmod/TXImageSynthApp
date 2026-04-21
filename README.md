# TX Image Synth App

![screenshot_ImageEdit](https://github.com/txmod/TXImageSynthApp/blob/main/Screenshots/screenshot_ImageEdit.png)

##INTRO

This is a SuperCollider app for generating sounds based on images used as sonograms.
Images can be created by analysing a sound file, by importing an existing image file,
or by drawing coloured lines or shapes using the image tools provided.
Image files can be saved or imported.
The sonogram image can be synthesised using filtered noise, sine waves, phase modulation synthesis or wavetable synthesis.
EQ, frequency warping, time stretching, delay and reverb can be added.
Recordings can be saved as Sound files.
Project files, containing images and settings, can be saved.

Created by Paul Miller (palemoonrising.co.uk)

## BEFORE STARTING

Download and install SuperCollider (https://supercollider.github.io)
Download and install SC3-plugins (https://supercollider.github.io/SC3-plugins)

## TO START APP

Open the file TXImageSynthApp/blob/main.scd from inside SuperCollider with SC3-plugins installed.
Select the whole document - press Cmd+A (MacOS) / Ctrl+A (Win).
Evaluate the code - press Shift+Return.
Once the app starts, click on the Help button to open the Help Window.

## THANKS

This app was developed from code originally shared by PyoungRyang Ko on SuperCollider Forum thread:
https://scsynth.org/t/a-sketch-to-make-an-image-filter-similar-to-the-image-filter-in-audiosculpt/10317
The Perlin Noise code was adapted from the Simplex Noise sc quark, which was ported
to SuperCollider by Glen Fraser from original code by Stefan Gustavson.
Big thanks to all who share their code.

## LICENSE

GNU GPL 3 license as per SuperCollider

![screenshot_Record](https://github.com/txmod/TXImageSynthApp/blob/main/Screenshots/screenshot_Record.png)
![screenshot_Settings](https://github.com/txmod/TXImageSynthApp/blob/main/Screenshots/screenshot_Settings.png)
![screenshot_Sound](https://github.com/txmod/TXImageSynthApp/blob/main/Screenshots/screenshot_Sound.png)
![screenshot_Warp](https://github.com/txmod/TXImageSynthApp/blob/main/Screenshots/screenshot_Warp.png)
