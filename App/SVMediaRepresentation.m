//
//  SVMediaRepresentation.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaRepresentation.h"

#import "KTImageScalingURLProtocol.h"
#import "SVMediaRecord.h"


@implementation SVMediaRepresentation

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord;
{
    [self init];
    
    _mediaRecord = [mediaRecord retain];
    
    return self;
}

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height
                 fileType:(NSString *)type;
{
    self = [self initWithMediaRecord:mediaRecord];
    
    _width = [width copy];
    _height = [height copy];
    _type = [type copy];
    
    return self;
}

- (void)dealloc
{
    [_mediaRecord release];
    [_width release];
    [_height release];
    [_type release];
    
    [super dealloc];
}

@synthesize mediaRecord = _mediaRecord;
@synthesize width = _width;
@synthesize height = _height;
@synthesize fileType = _type;

- (NSData *)data;
{
    if ([self width] || [self height])
    {
        NSURL *URL = [NSURL sandvoxImageURLWithFileURL:[[self mediaRecord] fileURL]
                                                  size:NSMakeSize([[self width] floatValue], [[self height] floatValue])
                                           scalingMode:KSImageScalingModeAspectFit
                                            sharpening:0.0f
                                     compressionFactor:1.0f
                                              fileType:[self fileType]];
        
        NSData *result = [NSURLConnection
                          sendSynchronousRequest:[NSURLRequest requestWithURL:URL]
                          returningResponse:NULL
                          error:NULL];
        return result;
    }
    else
    {
        return [[self mediaRecord] fileContents];
    }
}

@end
