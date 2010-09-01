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
#import "NSURL+Karelia.h"


@implementation SVMedia

- (id)initWithURL:(NSURL *)fileURL;
{
    [self init];
    
    _fileURL = [fileURL copy];
    
    return self;
}

- (void)dealloc;
{
    [_fileURL release];
    [_data release];
    
    [super dealloc];
}

@synthesize mediaURL = _fileURL;

@end


#pragma mark -


@implementation SVMedia (SVMedia)

- (NSData *)mediaData;
{
    return nil;
    NSData *result = _data;
    return result;
}

- (NSString *)preferredFilename    // what the media would like to named given the chance
{
    return [[self mediaURL] lastPathComponent];
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
