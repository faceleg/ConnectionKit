//
//  SVMediaRequest.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
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
    OBPRECONDITION(mediaRecord);
    
    if (type)
    {
        // Warn if trying a non-standard format
        if (![type isEqualToUTI:(NSString *)kUTTypeJPEG] &&
            ![type isEqualToUTI:(NSString *)kUTTypePNG] &&
            ![type isEqualToUTI:(NSString *)kUTTypeGIF] &&
            ![type isEqualToUTI:(NSString *)kUTTypeICO])
        {
            NSLog(@"Warning: Request for non-standard image format: %@", type);
        }
        
        // Warn if path doesn't match type
        if (path)
        {
            if (![[[NSWorkspace sharedWorkspace] ks_typeForFilenameExtension:[path pathExtension]] isEqualToUTI:type])
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

- (id)initWithMedia:(SVMedia *)media;   // convenience
{
    return [self initWithMedia:media
                         width:nil
                        height:nil
                          type:nil
           preferredUploadPath:[media preferredUploadPath]];
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

#pragma mark Image Scaling

- (BOOL)isNativeRepresentation;
{
    BOOL result = ![self width] && ![self height] && ![self type];
    return result;
}

- (NSDictionary *)imageScalingParameters;
{
    NSDictionary *result = [NSURL
                            sandvoxImageParametersWithSize:NSMakeSize([[self width] floatValue], [[self height] floatValue])
                            scalingMode:KSImageScalingModeAspectFit
                            sharpening:0.0f
                            compressionFactor:1.0f
                            fileType:[self type]];
    
    return result;
}

#pragma mark Publishing

- (NSString *)preferredUploadPath;
{
    if (!_uploadPath)
    {
        if ([self type])
        {
            NSString *name = [[[self media] preferredUploadPath] stringByDeletingPathExtension];
            
            _uploadPath = [name stringByAppendingPathExtension:
                           [[NSWorkspace sharedWorkspace] preferredFilenameExtensionForType:[self type]]];
            [_uploadPath retain];
        }
        else
        {
            _uploadPath = [[[self media] preferredUploadPath] copy];
        }
    }
    
    return _uploadPath;
}

- (BOOL)isEqualToMediaRequest:(SVMediaRequest *)otherMedia;
{
    if (otherMedia == self) return YES;
    
    // Evalutating -mediaData is expensive, so compare "recipes"
    return ([otherMedia.media isEqualToMedia:self.media] &&
            KSISEQUAL(otherMedia.width, self.width) &&
            KSISEQUAL(otherMedia.height, self.height) &&
            KSISEQUAL(otherMedia.type, self.type));
}

- (BOOL)isEqual:(id)object;
{
    BOOL result = [super isEqual:object];
    if (!result && [object isKindOfClass:[SVMediaRequest class]])
    {
        result = [self isEqualToMediaRequest:object];
    }   
    
    return result;
}

- (NSUInteger)hash { return [[self media] hash]; }

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];   // immutable
}

@end
