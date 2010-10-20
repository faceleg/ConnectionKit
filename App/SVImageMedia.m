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

#import "KSURLUtilities.h"


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

- (NSString *)preferredUploadPath;
{
    if ([self type])
    {
        NSString *name = [[[self mediaRecord] preferredUploadPath] stringByDeletingPathExtension];
        
        NSString *result = [name stringByAppendingPathExtension:
                            [NSString filenameExtensionForUTI:[self type]]];
        
        return result;
    }
    
    return [[self mediaRecord] preferredUploadPath];
}

- (NSData *)mediaData;
{
    if (![self isNativeRepresentation])
    {
        if ([[self mediaRecord] mediaData])
        {
            // FIXME: Support scaling from data
        }
        else
        {
            NSURL *URL = [NSURL sandvoxImageURLWithFileURL:[[self mediaRecord] mediaURL]
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
    }
    else
    {
        return [[self mediaRecord] mediaData];
    }
    
    return nil;
}

- (NSURL *)mediaURL; { return nil; }

- (BOOL)isEqual:(id)object;
{
    if ([object conformsToProtocol:@protocol(SVMedia)])
    {
        return [self isEqualToMedia:object];
    }   
    
    return NO;
}

- (BOOL)isEqualToMedia:(id <SVMedia>)otherMedia;
{
    if ([[self mediaURL] ks_isEqualToURL:[otherMedia mediaURL]])
    {
        return YES;
    }
    else if ([otherMedia isKindOfClass:[SVImageMedia class]])
    {
        // Evalutating -mediaData is expensive, so compare "recipes"
        SVImageMedia *otherImage = (SVImageMedia *)otherMedia;
        return ([otherImage.mediaRecord isEqualToMedia:self.mediaRecord] &&
                [otherImage.width isEqualToNumber:self.width] &&
                [otherImage.height isEqualToNumber:self.height] &&
                [otherImage.type isEqualToString:self.type]);
    }
    
    return NO;
}

- (NSUInteger)hash { return [[self mediaRecord] hash]; }

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];   // immutable
}

@end
