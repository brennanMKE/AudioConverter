//
//  ExtAudioConverter.m
//  AudioConverter
//
//  Created by Brennan Stehling on 12/27/16.
//  Copyright © 2016 SmallSharpTools LLC. All rights reserved.
//

#import "ExtAudioConverter.h"
#import "lame.h"

typedef NS_ENUM(UInt32, ExtAudioConverterStatus) {
    ExtAudioConverterStatusOK = 0,
    ExtAudioConverterStatusFailed
};

typedef struct ExtAudioConverterSettings {
    AudioStreamBasicDescription   inputPCMFormat;
    AudioStreamBasicDescription   outputFormat;

    ExtAudioFileRef               inputFile;
    CFStringRef                   outputFilePath;
    ExtAudioFileRef               outputFile;

    AudioStreamPacketDescription *inputPacketDescriptions;
} ExtAudioConverterSettings;

static ExtAudioConverterStatus CheckStatus(OSStatus status, const char *operation) {
    if (status == noErr) return ExtAudioConverterStatusOK;
    char statusString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(statusString + 1) = CFSwapInt32HostToBig(status);
    if (isprint(statusString[1]) && isprint(statusString[2]) &&
        isprint(statusString[3]) && isprint(statusString[4])) {
        statusString[0] = statusString[5] = '\'';
        statusString[6] = '\0';
    } else {
        // No, format it as an integer
        sprintf(statusString, "%d", (int)status);
    }
    fprintf(stderr, "Error: %s (%s)\n", operation, statusString);

    return ExtAudioConverterStatusFailed;
}

Boolean startConvert(ExtAudioConverterSettings *settings) {
    //Determine the proper buffer size and calculate number of packets per buffer
    //for CBR and VBR format
    ExtAudioConverterStatus status;
    UInt32 sizePerBuffer = 32*1024; //32KB is a good starting point
    UInt32 framesPerBuffer = sizePerBuffer/sizeof(SInt16);

    // allocate destination buffer
    SInt16 *outputBuffer = (SInt16 *)malloc(sizeof(SInt16) * sizePerBuffer);

    while (1) {
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers              = 1;
        outputBufferList.mBuffers[0].mNumberChannels = settings->outputFormat.mChannelsPerFrame;
        outputBufferList.mBuffers[0].mDataByteSize   = sizePerBuffer;
        outputBufferList.mBuffers[0].mData           = outputBuffer;

        UInt32 framesCount = framesPerBuffer;

        status = CheckStatus(ExtAudioFileRead(settings->inputFile,
                                             &framesCount,
                                             &outputBufferList),
                            "ExtAudioFileRead failed");
        if (status != ExtAudioConverterStatusOK) {
            return false;
        }

        if (framesCount==0) {
            return true;
        }

        status = CheckStatus(ExtAudioFileWrite(settings->outputFile,
                                              framesCount,
                                              &outputBufferList),
                            "ExtAudioFileWrite failed");
        if (status != ExtAudioConverterStatusOK) {
            return false;
        }
    }

    return true;
}

Boolean startConvertMP3(ExtAudioConverterSettings *settings) {
    ExtAudioConverterStatus status;
    //Init lame and set parameters
    lame_t lame = lame_init();
    lame_set_in_samplerate(lame, settings->inputPCMFormat.mSampleRate);
    lame_set_num_channels(lame, settings->inputPCMFormat.mChannelsPerFrame);
    lame_set_VBR(lame, vbr_default);
    lame_init_params(lame);

    NSString *outputFilePath = (__bridge NSString*)settings->outputFilePath;
    FILE *outputFile = fopen([outputFilePath cStringUsingEncoding:1], "wb");

    UInt32 sizePerBuffer = 32*1024;
    UInt32 framesPerBuffer = sizePerBuffer/sizeof(SInt16);

    int write;

    // allocate destination buffer
    SInt16 *outputBuffer = (SInt16 *)malloc(sizeof(SInt16) * sizePerBuffer);

    UInt32 framesCount;
    UInt32 channelsCount = settings->outputFormat.mChannelsPerFrame;

    do {
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers              = 1;
        outputBufferList.mBuffers[0].mNumberChannels = settings->outputFormat.mChannelsPerFrame;
        outputBufferList.mBuffers[0].mDataByteSize   = sizePerBuffer;
        outputBufferList.mBuffers[0].mData           = outputBuffer;

        framesCount = framesPerBuffer;

        status = CheckStatus(ExtAudioFileRead(settings->inputFile,
                                             &framesCount,
                                             &outputBufferList),
                            "ExtAudioFileRead failed");
        if (status != ExtAudioConverterStatusOK) {
            return false;
        }

        // Copy bytes from outputBufferList into pcm_buffer
        SInt16 pcm_buffer[framesCount];
        unsigned char mp3_buffer[framesCount];
        memcpy(pcm_buffer,
               outputBufferList.mBuffers[0].mData,
               framesCount);

        if (framesCount == framesPerBuffer / channelsCount) {
            //the 3rd parameter means number of samples per channel, not number of sample in pcm_buffer
            write = lame_encode_buffer_interleaved(lame,
                                                   outputBufferList.mBuffers[0].mData,
                                                   framesCount,
                                                   mp3_buffer,
                                                   framesCount);
        }
        else {
            if (framesCount > 0) {
                write = lame_encode_flush(lame, mp3_buffer, framesCount);
            }
            else {
                write = 0;
            }
        }

        fwrite(mp3_buffer,
               1,
               write,
               outputFile);
    }
    while (framesCount != 0);

    lame_close(lame);
    fclose(outputFile);

    return true;
}

@implementation ExtAudioConverter

- (BOOL)convert {
    ExtAudioConverterStatus status;
    ExtAudioConverterSettings settings = {0};

    //Check if source file or output file is null
    if (self.inputFilePath==NULL) {
        if (self.debugEnabled) {
            NSLog(@"Source file is not set");
        }
        return NO;
    }

    if (self.outputFilePath==NULL) {
        if (self.debugEnabled) {
            NSLog(@"Output file is no set");
        }
        return NO;
    }

    //Create ExtAudioFileRef
    NSURL *sourceURL = [NSURL fileURLWithPath:self.inputFilePath];
    status = CheckStatus(ExtAudioFileOpenURL((__bridge CFURLRef)sourceURL,
                                            &settings.inputFile),
                        "ExtAudioFileOpenURL failed");
    if (status != ExtAudioConverterStatusOK) {
        return NO;
    }

    if (![self validateInput:&settings]) {
        return NO;
    }

    settings.outputFormat.mSampleRate       = self.outputSampleRate;
    settings.outputFormat.mBitsPerChannel   = self.outputBitDepth;
    if (self.outputFormatID==kAudioFormatMPEG4AAC) {
        settings.outputFormat.mBitsPerChannel = 0;
    }
    settings.outputFormat.mChannelsPerFrame = self.outputNumberChannels;
    settings.outputFormat.mFormatID         = self.outputFormatID;

    if (self.outputFormatID==kAudioFormatLinearPCM) {
        settings.outputFormat.mBytesPerFrame   = settings.outputFormat.mChannelsPerFrame * settings.outputFormat.mBitsPerChannel/8;
        settings.outputFormat.mBytesPerPacket  = settings.outputFormat.mBytesPerFrame;
        settings.outputFormat.mFramesPerPacket = 1;
        settings.outputFormat.mFormatFlags     = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        //some file type only support big-endian
        if (self.outputFileType==kAudioFileAIFFType || self.outputFileType==kAudioFileSoundDesigner2Type || self.outputFileType==kAudioFileAIFCType || self.outputFileType==kAudioFileNextType) {
            settings.outputFormat.mFormatFlags |= kAudioFormatFlagIsBigEndian;
        }
    } else {
        UInt32 size = sizeof(settings.outputFormat);
        status = CheckStatus(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                                   0,
                                                   NULL,
                                                   &size,
                                                   &settings.outputFormat),
                            "AudioFormatGetProperty kAudioFormatProperty_FormatInfo failed");
        if (status != ExtAudioConverterStatusOK) {
            return NO;
        }
    }
    if (self.debugEnabled) {
        NSLog(@"output format:%@", [self descriptionForAudioFormat:settings.outputFormat]);
    }

    //Create output file
    //if output file path is invalid, this returns an error with 'wht?'
    NSURL *outputURL = [NSURL fileURLWithPath:self.outputFilePath];

    //create output file
    settings.outputFilePath = (__bridge CFStringRef)(self.outputFilePath);
    if (settings.outputFormat.mFormatID!=kAudioFormatMPEGLayer3) {
        status = CheckStatus(ExtAudioFileCreateWithURL((__bridge CFURLRef)outputURL,
                                                      self.outputFileType,
                                                      &settings.outputFormat,
                                                      NULL,
                                                      kAudioFileFlags_EraseFile,
                                                      &settings.outputFile),
                            "Create output file failed, the output file type and output format pair may not match");
        if (status != ExtAudioConverterStatusOK) {
            return NO;
        }
    }

    //Set input file's client data format
    //Must be PCM, thus as we say, "when you convert data, I want to receive PCM format"
    if (settings.outputFormat.mFormatID==kAudioFormatLinearPCM) {
        settings.inputPCMFormat = settings.outputFormat;
    } else {
        settings.inputPCMFormat.mFormatID = kAudioFormatLinearPCM;
        settings.inputPCMFormat.mSampleRate = settings.outputFormat.mSampleRate;
        //TODO:set format flags for both OS X and iOS, for all versions
        settings.inputPCMFormat.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
        //TODO:check if size of SInt16 is always suitable
        settings.inputPCMFormat.mBitsPerChannel = 8 * sizeof(SInt16);
        settings.inputPCMFormat.mChannelsPerFrame = settings.outputFormat.mChannelsPerFrame;
        //TODO:check if this is suitable for both interleaved/noninterleaved
        settings.inputPCMFormat.mBytesPerPacket = settings.inputPCMFormat.mBytesPerFrame = settings.inputPCMFormat.mChannelsPerFrame*sizeof(SInt16);
        settings.inputPCMFormat.mFramesPerPacket = 1;
    }
    if (self.debugEnabled) {
        NSLog(@"Client data format:%@",[self descriptionForAudioFormat:settings.inputPCMFormat]);
    }

    status = CheckStatus(ExtAudioFileSetProperty(settings.inputFile,
                                                kExtAudioFileProperty_ClientDataFormat,
                                                sizeof(settings.inputPCMFormat),
                                                &settings.inputPCMFormat),
                        "Setting client data format of input file failed");
    if (status != ExtAudioConverterStatusOK) {
        return NO;
    }

    //If the file has a client data format, then the audio data in ioData is translated from the client format to the file data format, via theExtAudioFile's internal AudioConverter.
    if (settings.outputFormat.mFormatID!=kAudioFormatMPEGLayer3) {
        status = CheckStatus(ExtAudioFileSetProperty(settings.outputFile,
                                                    kExtAudioFileProperty_ClientDataFormat,
                                                    sizeof(settings.inputPCMFormat),
                                                    &settings.inputPCMFormat),
                            "Setting client data format of output file failed");
        if (status != ExtAudioConverterStatusOK) {
            return NO;
        }
    }

    BOOL result;
    if (settings.outputFormat.mFormatID==kAudioFormatMPEGLayer3) {
        result = startConvertMP3(&settings);
    } else {
        result = startConvert(&settings);
    }

    ExtAudioFileDispose(settings.inputFile);
    //AudioFileClose/ExtAudioFileDispose function is needed, or else for .wav output file the duration will be 0
    ExtAudioFileDispose(settings.outputFile);
    return result;
}

// Check if the input combination is valid
- (BOOL)validateInput:(ExtAudioConverterSettings*)settings {
    //Set default output format
    if (self.outputSampleRate==0) {
        self.outputSampleRate = 44100;
    }

    if (self.outputNumberChannels==0) {
        self.outputNumberChannels = 2;
    }

    if (self.outputBitDepth==0) {
        self.outputBitDepth = 16;
    }

    if (self.outputFormatID==0) {
        self.outputFormatID = kAudioFormatLinearPCM;
    }

    if (self.outputFileType==0) {
        //caf type is the most powerful file format
        self.outputFileType = kAudioFileCAFType;
    }

    BOOL valid = YES;
    //The file format and data format match documentation is at: https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/CoreAudioOverview/SupportedAudioFormatsMacOSX/SupportedAudioFormatsMacOSX.html
    switch (self.outputFileType) {
        case kAudioFileWAVEType:{//for wave file format
            //WAVE file type only support PCM, alaw and ulaw
            valid = self.outputFormatID==kAudioFormatLinearPCM || self.outputFormatID==kAudioFormatALaw || self.outputFormatID==kAudioFormatULaw;
            break;
        }
        case kAudioFileAIFFType:{
            //AIFF only support PCM format
            valid = self.outputFormatID==kAudioFormatLinearPCM;
            break;
        }
        case kAudioFileAAC_ADTSType:{
            //aac only support aac data format
            valid = self.outputFormatID==kAudioFormatMPEG4AAC;
            break;
        }
        case kAudioFileAC3Type:{
            //convert from PCM to ac3 format is not supported
            valid = NO;
            break;
        }
        case kAudioFileAIFCType:{
            //TODO:kAudioFileAIFCType together with kAudioFormatMACE3/kAudioFormatMACE6/kAudioFormatQDesign2/kAudioFormatQUALCOMM pair failed
            //Since MACE3:1/MACE6:1 is obsolete, they're not supported yet
            valid = self.outputFormatID==kAudioFormatLinearPCM || self.outputFormatID==kAudioFormatULaw || self.outputFormatID==kAudioFormatALaw || self.outputFormatID==kAudioFormatAppleIMA4 || self.outputFormatID==kAudioFormatQDesign2 || self.outputFormatID==kAudioFormatQUALCOMM;
            break;
        }
        case kAudioFileCAFType:{
            //caf file type support almost all data format
            //TODO:not all foramt are supported, check them out
            valid = YES;
            break;
        }
        case kAudioFileMP3Type:{
            //TODO:support mp3 type
            valid = self.outputFormatID==kAudioFormatMPEGLayer3;
            break;
        }
        case kAudioFileMPEG4Type:{
            valid = self.outputFormatID==kAudioFormatMPEG4AAC;
            break;
        }
        case kAudioFileM4AType:{
            valid = self.outputFormatID==kAudioFormatMPEG4AAC || self.outputFormatID==kAudioFormatAppleLossless;
            break;
        }
        case kAudioFileNextType:{
            valid = self.outputFormatID==kAudioFormatLinearPCM || self.outputFormatID==kAudioFormatULaw;
            break;
        }
        case kAudioFileSoundDesigner2Type:{
            valid = self.outputFormatID==kAudioFormatLinearPCM;
            break;
        }
            //TODO:check iLBC format
        default:
            break;
    }

    return valid;
}

- (NSString *)descriptionForAudioFormat:(AudioStreamBasicDescription)audioFormat {
    NSMutableString *description = [NSMutableString new];

    // From https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/ConstructingAudioUnitApps/ConstructingAudioUnitApps.html (Listing 2-8)
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (audioFormat.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';

    [description appendString:@"\n"];
    [description appendFormat:@"Sample Rate:         %10.0f \n",  audioFormat.mSampleRate];
    [description appendFormat:@"Format ID:           %10s \n",    formatIDString];
    [description appendFormat:@"Format Flags:        %10d \n",    (unsigned int)audioFormat.mFormatFlags];
    [description appendFormat:@"Bytes per Packet:    %10d \n",    (unsigned int)audioFormat.mBytesPerPacket];
    [description appendFormat:@"Frames per Packet:   %10d \n",    (unsigned int)audioFormat.mFramesPerPacket];
    [description appendFormat:@"Bytes per Frame:     %10d \n",    (unsigned int)audioFormat.mBytesPerFrame];
    [description appendFormat:@"Channels per Frame:  %10d \n",    (unsigned int)audioFormat.mChannelsPerFrame];
    [description appendFormat:@"Bits per Channel:    %10d \n",    (unsigned int)audioFormat.mBitsPerChannel];

    // Add flags (supposing standard flags).
    [description appendString:[self descriptionForStandardFlags:audioFormat.mFormatFlags]];

    return [NSString stringWithString:description];
}

- (NSString *)descriptionForStandardFlags:(UInt32) mFormatFlags {
    NSMutableString *description = [NSMutableString new];

    if (mFormatFlags & kAudioFormatFlagIsFloat)
    { [description appendString:@"kAudioFormatFlagIsFloat \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsBigEndian)
    { [description appendString:@"kAudioFormatFlagIsBigEndian \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsSignedInteger)
    { [description appendString:@"kAudioFormatFlagIsSignedInteger \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsPacked)
    { [description appendString:@"kAudioFormatFlagIsPacked \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsAlignedHigh)
    { [description appendString:@"kAudioFormatFlagIsAlignedHigh \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsNonInterleaved)
    { [description appendString:@"kAudioFormatFlagIsNonInterleaved \n"]; }
    if (mFormatFlags & kAudioFormatFlagIsNonMixable)
    { [description appendString:@"kAudioFormatFlagIsNonMixable \n"]; }
    if (mFormatFlags & kAudioFormatFlagsAreAllClear)
    { [description appendString:@"kAudioFormatFlagsAreAllClear \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsFloat)
    { [description appendString:@"kLinearPCMFormatFlagIsFloat \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsBigEndian)
    { [description appendString:@"kLinearPCMFormatFlagIsBigEndian \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsSignedInteger)
    { [description appendString:@"kLinearPCMFormatFlagIsSignedInteger \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsPacked)
    { [description appendString:@"kLinearPCMFormatFlagIsPacked \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsAlignedHigh)
    { [description appendString:@"kLinearPCMFormatFlagIsAlignedHigh \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved)
    { [description appendString:@"kLinearPCMFormatFlagIsNonInterleaved \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagIsNonMixable)
    { [description appendString:@"kLinearPCMFormatFlagIsNonMixable \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagsSampleFractionShift)
    { [description appendString:@"kLinearPCMFormatFlagsSampleFractionShift \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagsSampleFractionMask)
    { [description appendString:@"kLinearPCMFormatFlagsSampleFractionMask \n"]; }
    if (mFormatFlags & kLinearPCMFormatFlagsAreAllClear)
    { [description appendString:@"kLinearPCMFormatFlagsAreAllClear \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_16BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_16BitSourceData \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_20BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_20BitSourceData \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_24BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_24BitSourceData \n"]; }
    if (mFormatFlags & kAppleLosslessFormatFlag_32BitSourceData)
    { [description appendString:@"kAppleLosslessFormatFlag_32BitSourceData \n"]; }
    
    return [NSString stringWithString:description];
}

@end
