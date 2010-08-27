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

@synthesize fileURL = _fileURL;

- (NSData *)data;
{
    NSData *result = _data;
    if (!result && [self fileURL])
    {
        result = [NSData dataWithContentsOfURL:[self fileURL]];
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVMedia (SVMedia)

- (NSURL *)fileURL
{
    return _fileURL;
}

- (NSData *)fileContents
{
    return [self data];
}

- (NSString *)filename // non-nil value means the media should be inside the doc package (or deleted)
{
    return [self preferredFilename];
}

- (NSString *)preferredFilename    // what the media would like to named given the chance
{
    return [[[self fileURL] absoluteString] lastPathComponent];
}

- (NSString *)typeOfFile           // based on preferred filename, what the UTI is
{
    NSString *path = [[self fileURL] path];
    return path ? [NSString UTIForFileAtPath:path] : nil;
}

- (id)imageRepresentation
{
    return (nil != [self fileContents]) 
    ? (id)[self fileContents] 
    : (id)[self fileURL];
}

- (NSString *)imageRepresentationType
{
    return (nil != [self fileContents]) 
    ? IKImageBrowserNSDataRepresentationType 
    : IKImageBrowserNSURLRepresentationType;
}

@end
