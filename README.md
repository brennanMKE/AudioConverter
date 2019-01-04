# AudioConverter

Integrates with LAME library to support converting audio to MP3 format
in addition to the formats supported by iOS.

 * [ExtAudioFileConverter]
 * [LAME iOS Build]

## How to Build

First create the static libary for LAME using [LAME iOS Build]. Get the latest 
[LAME download] and place the source in a folder named `lame` under the build folder.
Then run `build-lame.sh` which will create various static libraries for each of the
supported architectures as well as FAT binaries which can be used for development.

Then copy the files LAME into this folder with the following paths below the AudioConverter
directory.

* `lame/include/lame/lame.h`
* `lame/lib/libmp3lame.a`

With these files in place it will be possible to compile the project which includes the
class ExtAudioFileConverter which is used to convert audio files. An example is shown
in `ViewController.m` which converts `source.m4a` to `output.mp3` which is placed in the
`Caches` directory. When conversion is completed an `AVPlayerViewController` is displayed
and the new file is played immediately.

## Release Builds

Running the script for [LAME iOS Build] creates a FAT binary which includes architectures
for devices as well as the iOS Simulator. When a release build is submitted to the 
App Store it will be rejected if architectures for the iOS Simulator are included source
they must be excluded. Running the build script can be run again to build with the valid
architures only. First the previous output folders must be deleted.

```sh
rm -rf fat-lame/
rm -rf scratch-lame/
rm -rf thin-lame/
./build-lame.sh arm64 armv7s armv7
```

A tool like CocoaPods includes scripts which strip out these architectures using the 
`lipo` tool. It is also possible to create `Debug` and `Release` static libaries with 
the required architectures based on the current build configuration.

NOTE: It is possible that current versions of Xcode will strip out the invalid architectures
when the archive is created for submitting a build to the App Store, making this work
unnecessary.

## Source Audio

Creating the source audio for testing is easily done using macOS using the following
command.

```sh
say -o source.m4a "Start and Stop"
```

Any text can be converted to speech and stored in the output file.

---

[ExtAudioFileConverter]: https://github.com/lixing123/ExtAudioFileConverter
[LAME iOS Build]: https://github.com/kewlbear/lame-ios-build
[LAME download]: https://sourceforge.net/projects/lame/files/lame/3.99/
