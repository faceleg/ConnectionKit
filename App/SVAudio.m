//
//  SVAudio.m
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAudio.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"

/*
 
 
 
 Audio UTIs:
 kUTTypeMP3
 kUTTypeMPEG4Audio
 public.ogg-vorbis
 ... check that it's not kUTTypeAppleProtected​MPEG4Audio
 public.aiff-audio
 com.microsoft.waveform-​audio  (.wav)
 
 */




@implementation SVAudio

+ (SVAudio *)insertNewAudioInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVAudio *result = [NSEntityDescription insertNewObjectForEntityForName:@"Audio"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)writeBody:(SVHTMLContext *)context;
{
    [context writeHTMLString:@"<p>[[MAKE ME WRITE SOME HTML!]]</p>"];
}

@end
