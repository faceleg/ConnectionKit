//
//  SVMediaGatheringPublishingContext.m
//  Sandvox
//
//  Created by Mike on 14/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGatheringPublishingContext.h"


@implementation SVMediaGatheringPublishingContext

@synthesize publishingEngine = _mediaPublisher;

/*  Ignore most publishing commands */
- (CKTransferRecord *)publishData:(NSData *)data toPath:(NSString *)remotePath;
{
    return nil;
}
- (CKTransferRecord *)publishContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath
{
    return nil;
}
- (NSString *)publishResourceAtURL:(NSURL *)fileURL;
{
    return nil;
}

- (SVHTMLContext *)beginPublishingHTMLToPath:(NSString *)path
{
    return [[self publishingEngine] beginPublishingHTMLToPath:path];
}

- (NSString *)publishMediaRepresentation:(SVMediaRepresentation *)mediaRep;
{
    return [[self publishingEngine] publishMediaRepresentation:mediaRep];
}

- (NSString *)baseRemotePath; { return [[self publishingEngine] baseRemotePath]; }

@end
