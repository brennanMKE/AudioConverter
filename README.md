# AudioConverter

Integrates with LAME library for MP3 to support converting audio to MP3 format
in addition to the formats supported by iOS.

 * [ExtAudioFileConverter] (Original Source)
 * [LAME iOS Build]

# How to Build

First create the static libary for LAME using [LAME iOS Build]. Get the latest version 
[LAME Download] and place the source in a folder named `lame` under the build folder.
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

# Release Builds

Apps which are submitted to the App Store cannot include FAT binaries which include
architectures used by the iOS Simulator. These are `x86_64` and `i386`. A tool like
CocoaPods includes tools which strip out these architectures using the `lipo` tool.
It is also possible to create `Debug` and `Release` static libaries with the required
architectures based on the current build configuration.

Current `libmp3lame.a` is included directly in the project. It is possible to instead
use a Library Search Path with the variable for the current build configuration to
change Library Search Path for Debug or Release.

# Source Audio

Creating the source audio for testing is easily done using macOS using the following
command.

```sh
say -o source.m4a "Start and Stop"
```

Any text can be converted to speech and stored in the output file.

---

[ExtAudioFileConverter]: https://github.com/lixing123/ExtAudioFileConverter
[LAME iOS Build]: https://github.com/kewlbear/lame-ios-build
[LAME Download]: https://sourceforge.net/projects/lame/files/lame/3.99/