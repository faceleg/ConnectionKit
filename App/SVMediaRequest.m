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

#import "NSData+Karelia.h"
#import "NSString+Karelia.h"

#import "KSPathUtilities.h"
#import "KSURLUtilities.h"


@implementation SVMediaRequest

- (id)initWithMedia:(SVMedia *)media
              width:(NSNumber *)width
             height:(NSNumber *)height
               type:(NSString *)type
preferredUploadPath:(NSString *)path
      scalingSuffix:(NSString *)suffix;
{
    OBPRECONDITION(media);
    
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
            if (![[KSWORKSPACE ks_typeForFilenameExtension:[path pathExtension]] isEqualToUTI:type])
            {
                NSLog(@"Warning: Request for image whose filename does not match format: %@", type);
            }
        }
    }
    
    self = [self init];
    
    _media = [media retain];
    _width = [width copy];
    _height = [height copy];
    _type = [type copy];
    _uploadPath = [path copy];
    _scalingOrConversionPathSuffix = [suffix copy];
    
    return self;
}

- (id)initWithMedia:(SVMedia *)media preferredUploadPath:(NSString *)path;   // convenience
{
    return [self initWithMedia:media
                         width:nil
                        height:nil
                          type:nil
           preferredUploadPath:path
                 scalingSuffix:nil];
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

#pragma mark Source

@synthesize media = _media;

- (SVMediaRequest *)sourceRequest;
{
    return [[[SVMediaRequest alloc] initWithMedia:[self media] preferredUploadPath:nil] autorelease];
}

#pragma mark Properties

@synthesize width = _width;
@synthesize height = _height;
@synthesize type = _type;
@synthesize scalingPathSuffix = _scalingOrConversionPathSuffix;


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
                            scalingMode:KSImageScalingModeFill
                            sharpening:0.0f
                            compressionFactor:0.7f
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
            
            OBASSERT(![name isEqualToString:@""]);
            _uploadPath = [name stringByAppendingPathExtension:
                           [KSWORKSPACE preferredFilenameExtensionForType:[self type]]];
            [_uploadPath retain];
        }
        else
        {
            _uploadPath = [[[self media] preferredUploadPath] copy];
        }
    }
    
    return _uploadPath;
}

- (SVMediaRequest *)requestWithScalingSuffixApplied;
{
    if (![self scalingPathSuffix]) return self;
    
    
    NSString *path = [[self preferredUploadPath] ks_stringWithPathSuffix:[self scalingPathSuffix]];
    
    return [[[SVMediaRequest alloc] initWithMedia:[self media]
                                            width:[self width]
                                           height:[self height]
                                             type:[self type]
                              preferredUploadPath:path
                                    scalingSuffix:nil] autorelease];
}

- (NSData *)contentHashWithSourceMediaDigest:(NSData *)digest;
{
    NSData *result = nil;
    
    NSString *query = [[NSURL sandvoxImageURLWithMediaRequest:self] query];
    if (query)
    {
        query = [@"?" stringByAppendingString:query];
        
        result = [digest ks_dataByAppendingData:
                  [query dataUsingEncoding:NSASCIIStringEncoding]];
    }
    
    return result;
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

#pragma mark Debug

- (NSString *)description;
{
    NSString *result = [super description];
    result = [result stringByAppendingFormat:@" %@", [self media]];
    
    if ([self width] || [self height])
    {
        result = [result stringByAppendingFormat:@" %@x%@", [self width], [self height]];
    }
    
    result = [result stringByAppendingFormat:@" %@", [self preferredUploadPath]];
    
    if ([self scalingPathSuffix])
    {
        result = [result stringByAppendingFormat:@" (%@)", [self scalingPathSuffix]];
    }
    
    return result;
}

@end
