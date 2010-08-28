//
//  SVImageMedia.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageMedia.h"

#import "SVImageScalingOperation.h"
#import "KTImageScalingURLProtocol.h"

#import "NSString+Karelia.h"


@implementation SVImageMedia

- (id)initWithSourceMedia:(id <SVMedia>)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height
                     type:(NSString *)type;
{
    self = [self init];
    
    _mediaRecord = [mediaRecord retain];
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
@synthesize type = _type;

- (BOOL)isNativeRepresentation;
{
    BOOL result = !([self width] || [self height]);
    return result;
}

- (NSString *)preferredFilename;    // what the media would like to named given the chance
{
    if ([self type])
    {
        NSString *name = [[[self mediaRecord] preferredFilename] stringByDeletingPathExtension];
        
        NSString *result = [name stringByAppendingPathExtension:
                            [NSString filenameExtensionForUTI:[self type]]];
        
        return result;
    }
    
    return [[self mediaRecord] preferredFilename];
}

- (NSData *)data;
{
    if (![self isNativeRepresentation])
    {
        NSURL *URL = [NSURL sandvoxImageURLWithFileURL:[[self mediaRecord] fileURL]
                                                  size:NSMakeSize([[self width] floatValue], [[self height] floatValue])
                                           scalingMode:KSImageScalingModeAspectFit
                                            sharpening:0.0f
                                     compressionFactor:1.0f
                                              fileType:[self type]];
        
        SVImageScalingOperation *op = [[SVImageScalingOperation alloc] initWithURL:URL];
        [op start];
        
        NSData *result = [[[op result] copy] autorelease];
        [op release];
        
        return result;
    }
    else
    {
        return [[self mediaRecord] fileContents];
    }
}

- (BOOL)isEqualToMediaRepresentation:(SVImageMedia *)otherRep;
{
    BOOL result = ([[self mediaRecord] isEqual:[otherRep mediaRecord]] &&
                   KSISEQUAL([self width], [otherRep width]) &&
                   KSISEQUAL([self height], [otherRep height]) &&
                   KSISEQUAL([self type], [otherRep type]));
    return result;
}

- (BOOL)isEqual:(id)object;
{
    return (self == object ||
            ([object isKindOfClass:[SVImageMedia class]] &&
             [self isEqualToMediaRepresentation:object]));
}

- (NSUInteger)hash { return [[self mediaRecord] hash]; }

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];   // immutable
}

@end
