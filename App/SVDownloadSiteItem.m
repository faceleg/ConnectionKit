//
//  SVDownloadSiteItem.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDownloadSiteItem.h"

#import "SVMediaRecord.h"
#import "KTPage.h"
#import "KTPublishingEngine.h"

#import "NSString+Karelia.h"


@implementation SVDownloadSiteItem

@dynamic media;
- (void)setMedia:(SVMediaRecord *)media
{
    [self willChangeValueForKey:@"media"];
    [self setPrimitiveValue:media forKey:@"media"];
    [self didChangeValueForKey:@"media"];
    
    [self setTitle:[[media preferredFilename] stringByDeletingPathExtension]];
}

- (id <SVMedia>)mediaRepresentation;
{
    return [self media];
}
+ (NSSet *)keyPathsForValuesAffectingMediaRepresentation
{
    return [NSSet setWithObject:@"media"];
}

#pragma mark Publishing

- (void)publish:(id <SVPublishingContext>)publishingEngine recursively:(BOOL)recursive;
{
    id <SVMedia> media = [self media];
    
    NSString *uploadPath = [publishingEngine baseRemotePath];
    uploadPath = [uploadPath stringByAppendingPathComponent:[[self parentPage] uploadPath]];
    uploadPath = [uploadPath stringByDeletingLastPathComponent];
    uploadPath = [uploadPath stringByAppendingPathComponent:
                  [[media preferredFilename] legalizedWebPublishingFilename]];
    
    [publishingEngine publishContentsOfURL:[media fileURL] toPath:uploadPath];
}

@end
