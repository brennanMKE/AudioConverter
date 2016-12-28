//
//  ExtAudioConverter.h
//  AudioConverter
//
//  Created by Brennan Stehling on 12/27/16.
//  Copyright © 2016 SmallSharpTools LLC. All rights reserved.
//

// GitHub Reference: https://github.com/lixing123/ExtAudioFileConverter
// LAME iOS Build: https://github.com/kewlbear/lame-ios-build

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

enum BitDepth{
    BitDepth_8  = 8,
    BitDepth_16 = 16,
    BitDepth_24 = 24,
    BitDepth_32 = 32
};

@interface ExtAudioConverter : NSObject

// Required
@property (nonatomic,retain) NSString *inputFilePath; // Absolute path
@property (nonatomic,retain) NSString *outputFilePath; // Absolute path

// Optional
@property (nonatomic,assign) int outputSampleRate; // Default 44100.0
@property (nonatomic,assign) int outputNumberChannels; // Default 2
@property (nonatomic,assign) enum BitDepth outputBitDepth; // Default BitDepth_16
@property (nonatomic,assign) AudioFormatID outputFormatID; // Default Linear PCM
@property (nonatomic,assign) AudioFileTypeID outputFileType; // Default kAudioFileCAFType

@property (nonatomic,assign) BOOL debugEnabled;

- (BOOL)convert;

@end

NS_ASSUME_NONNULL_END
