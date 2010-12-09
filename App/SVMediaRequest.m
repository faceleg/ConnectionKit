//
//  SVMediaRequest.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaRequest.h"
#import "SVMedia.h"

#import "SVImageScalingOperation.h"
#import "KTImageScalingURLProtocol.h"

#import "NSString+Karelia.h"

#import "KSURLUtilities.h"


@implementation SVMediaRequest

- (id)initWithMedia:(SVMedia *)mediaRecord
              width:(NSNumber *)width
             height:(NSNumber *)height
               type:(NSString *)type
preferredUploadPath:(NSString *)path;
{
    if (type)
    {
        // Warn if trying a non-standard format
        if (![type isEqualToUTI:(NSString *)kUTTypeJPEG] &&
            ![type isEqualToUTI:(NSString *)kUTTypePNG] &&
            ![type isEqualToUTI:(NSString *)kUTTypeGIF])
        {
            NSLog(@"Warning: Request for non-standard image format: %@", type);
        }
        
        // Warn if path doesn't match type
        if (path)
        {
            if (![[NSString UTIForFilenameExtension:[path pathExtension]] isEqualToUTI:type])
            {
                NSLog(@"Warning: Request for image whose filename does not match format: %@", type);
            }
        }
    }
    
    self = [self init];
    
    _media = [mediaRecord retain];
    _width = [width copy];
    _height = [height copy];
    _type = [type copy];
    _uploadPath = [path copy];
    
    return self;
}

- (void)dealloc
{
    [_media release];
    [_width release];
    [_height release];
    [_type release];
    [_uploadPath release];
    
    [super dealloc];
}

@synthesize media = _media;
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
    if (!_uploadPath)
    {
        if ([self type])
        {
            NSString *name = [[[self media] preferredUploadPath] stringByDeletingPathExtension];
            
            _uploadPath = [name stringByAppendingPathExtension:
                           [NSString filenameExtensionForUTI:[self type]]];
            [_uploadPath retain];
        }
        else
        {
            _uploadPath = [[[self media] preferredUploadPath] copy];
        }
    }
    
    return _uploadPath;
}

- (NSData *)mediaData;
{
    if (![self isNativeRepresentation])
    {
        if ([NSThread isMainThread])
        {
            NSLog(@"Evaluating scaled image data on main thread which is inadvisable as generally takes a significant amount of time");
        }
        
        NSDictionary *params = [NSURL
                                sandvoxImageParametersWithSize:NSMakeSize([[self width] floatValue], [[self height] floatValue])
                                scalingMode:KSImageScalingModeAspectFit
                                sharpening:0.0f
                                compressionFactor:1.0f
                                fileType:[self type]];
        
        SVImageScalingOperation *op = [[SVImageScalingOperation alloc] initWithMedia:[self media] parameters:params];
        [op start];
        
        NSData *result = [[[op result] copy] autorelease];
        [op release];
        
        return result;
    }
    else
    {
        return [[self media] mediaData];
    }
    
    return nil;
}

- (NSURL *)mediaURL; { return nil; }

- (BOOL)isEqualToMedia:(id <SVMedia>)otherMedia;
{
    if ([[self mediaURL] ks_isEqualToURL:[otherMedia mediaURL]])
    {
        return YES;
    }
    else if ([otherMedia isKindOfClass:[SVMediaRequest class]])
    {
        // Evalutating -mediaData is expensive, so compare "recipes"
        SVMediaRequest *otherImage = (SVMediaRequest *)otherMedia;
        return ([otherImage.media isEqualToMedia:self.media] &&
                [otherImage.width isEqualToNumber:self.width] &&
                [otherImage.height isEqualToNumber:self.height] &&
                [otherImage.type isEqualToString:self.type]);
    }
    
    return NO;
}

- (BOOL)isEqual:(id)object;
{
    if ([object conformsToProtocol:@protocol(SVMedia)])
    {
        return [self isEqualToMedia:object];
    }   
    
    return NO;
}

- (NSUInteger)hash { return [[self media] hash]; }

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];   // immutable
}

@end
