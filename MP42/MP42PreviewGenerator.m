//
//  MP42PreviewGenerator.m
//  MP42Foundation
//
//  Created by Damiano Galassi on 08/01/14.
//  Copyright (c) 2022 Damiano Galassi. All rights reserved.
//

#import "MP42PreviewGenerator.h"
#import "MP42TextSample.h"
#import <AVFoundation/AVFoundation.h>

#define MINIMUM_OFFSET  1800

@implementation MP42PreviewGenerator

+ (NSArray<NSImage *> *)generatePreviewImagesFromChapters:(NSArray<MP42TextSample *> *)chapters fileURL:(NSURL *)url atPosition:(CGFloat)position {
    NSArray<NSImage *> *images = nil;

    images = [MP42PreviewGenerator generatePreviewImagesAVFoundationFromChapters:chapters andFile:url atPosition:position];

    return images;
}

+ (NSArray *)generatePreviewImagesAVFoundationFromChapters:(NSArray<MP42TextSample *> *)chapters andFile:(NSURL *)file atPosition:(CGFloat)position {
    NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:[chapters count]];
    
    AVAsset *asset = [AVAsset assetWithURL:file];
    NSArray<AVAssetTrack *> *visualTracks = [asset tracksWithMediaCharacteristic:AVMediaCharacteristicVisual];
    NSLog(@"[ChapterPreview] source=%@ chapters=%lu position=%.3f visualTracks=%lu duration=%.3f playable=%d readable=%d",
          file.path, (unsigned long)chapters.count, (double)position,
          (unsigned long)visualTracks.count, CMTimeGetSeconds(asset.duration),
          asset.playable, asset.readable);
    for (AVAssetTrack *track in visualTracks) {
        NSLog(@"[ChapterPreview] video track=%d mediaType=%@ nominalFrameRate=%.3f playable=%d formats=%@",
              track.trackID, track.mediaType, track.nominalFrameRate, track.playable, track.formatDescriptions);
    }

    if (visualTracks.count > 0) {
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter  = kCMTimeZero;

        CGFloat offset;
        MP42Duration assetDuration = CMTimeGetSeconds(asset.duration) * 1000;

        NSUInteger failures = 0;
        for (NSUInteger idx = 0; idx < chapters.count; idx++)
        {
            MP42TextSample *chapter = chapters[idx];

            if (chapter.timestamp > assetDuration) {
                NSLog(@"[ChapterPreview] chapter=%lu starts after duration: chapterMs=%lld durationMs=%lld",
                      (unsigned long)idx, (long long)chapter.timestamp, (long long)assetDuration);
                break;
            }

            MP42Duration nextChapterTimestamp = (idx < chapters.count - 1) ? chapters[idx+1].timestamp : assetDuration;

            if (position <= 0.0) {
                offset = MINIMUM_OFFSET;
            }
            else if (position >= 1.0) {
                offset = ((nextChapterTimestamp - chapter.timestamp) * position) - MINIMUM_OFFSET;
            }
            else {
                offset = (nextChapterTimestamp - chapter.timestamp) * position;
            }

            CMTime time = CMTimeMake(chapter.timestamp + MAX(MINIMUM_OFFSET, offset), 1000);

            NSError *frameError = nil;
            CMTime actualTime = kCMTimeInvalid;
            CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:&actualTime error:&frameError];
            if (!imgRef) {
                failures++;
                NSLog(@"[ChapterPreview] FAILED chapter=%lu startMs=%lld nextMs=%lld requested=%.3f duration=%.3f errorDomain=%@ code=%ld description=%@ userInfo=%@",
                      (unsigned long)idx, (long long)chapter.timestamp, (long long)nextChapterTimestamp,
                      CMTimeGetSeconds(time), CMTimeGetSeconds(asset.duration),
                      frameError.domain, (long)frameError.code, frameError.localizedDescription, frameError.userInfo);
            } else {
                NSLog(@"[ChapterPreview] OK chapter=%lu requested=%.3f actual=%.3f dimensions=%zux%zu",
                      (unsigned long)idx, CMTimeGetSeconds(time), CMTimeGetSeconds(actualTime),
                      CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
            }
            if (imgRef) {
                NSSize size = NSMakeSize(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
                NSImage *frame = [[NSImage alloc] initWithCGImage:imgRef size:size];
                
                [images addObject:frame];
            }
            
            if (imgRef) CGImageRelease(imgRef);
        }
        NSLog(@"[ChapterPreview] completed generated=%lu failed=%lu requestedChapters=%lu",
              (unsigned long)images.count, (unsigned long)failures, (unsigned long)chapters.count);
    } else {
        NSLog(@"[ChapterPreview] no visual tracks found; no previews generated");
    }

    return images;
}

@end
