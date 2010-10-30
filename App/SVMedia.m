//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 27/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMedia.h"
#import "SVMediaProtocol.h"

#import "NSString+Karelia.h"
#import "KSURLUtilities.h"


@implementation SVMedia

#pragma mark Init & Dealloc

- (id)initByReferencingURL:(NSURL *)fileURL;
{
    [self init];
    
    _fileURL = [fileURL copy];
    [self setPreferredFilename:[fileURL ks_lastPathComponent]];
    
    return self;
}

- (id)initWithContentsOfURL:(NSURL *)URL error:(NSError **)outError;
{
    [self init];
    
    _data = [[NSData alloc] initWithContentsOfURL:URL options:0 error:outError];
    if (_data)
    {
        _fileURL = [URL copy];
        [self setPreferredFilename:[URL ks_lastPathComponent]];
    }
    else
    {
        [self release]; self = nil;
    }
    
    return self;
}

- (id)initWithWebResource:(WebResource *)resource;
{
    [self init];
    
    _webResource = [resource copy];
    [self setPreferredFilename:[[resource URL] ks_lastPathComponent]];
    
    return self;
}

- (void)dealloc;
{
    [_fileURL release];
    [_data release];
    [_webResource release];
    [_preferredFilename release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize mediaURL = _fileURL;

- (NSData *)mediaData;
{
    return (_webResource ? [_webResource data] : _data);
}

@synthesize preferredFilename = _preferredFilename;

- (NSString *)preferredUploadPath;
{
    NSString *result = [@"_Media" stringByAppendingPathComponent:
                        [[self preferredFilename] legalizedWebPublishingFilename]];
    
    if ([[result pathExtension] isEqualToString:@"jpg"])
    {
        result = [[result stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"];
    }
    
    return result;
}

- (id)imageRepresentation
{
    return (nil != [self mediaData]
            ? (id)[self mediaData] 
            : (id)[self mediaURL]);
}

- (NSString *)imageRepresentationType
{
    return ([self mediaData] 
            ? IKImageBrowserNSDataRepresentationType 
            : IKImageBrowserNSURLRepresentationType);
}

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
    return ([[self mediaURL] ks_isEqualToURL:[otherMedia mediaURL]] ||
            [[self mediaData] isEqualToData:[otherMedia mediaData]]);
}

- (NSUInteger)hash; { return 0; }

@end


#pragma mark -


@implementation NSData (SVMedia)

+ (NSData *)newDataWithContentsOfMedia:(id <SVMedia>)media;
{
    NSData *result = [[media mediaData] copy];
    if (!result) result = [[NSData alloc] initWithContentsOfURL:[media mediaURL]];
    return result;
}

@end
