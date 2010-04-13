// 
//  SVRootPublishingRecord.m
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRootPublishingRecord.h"

#import "KTHostProperties.h"

@implementation SVRootPublishingRecord 

@dynamic hostProperties;

- (NSString *)path; { return @""; }

- (BOOL)validateFilename:(NSString **)outFilename error:(NSError **)error;
{
    return YES;
}

- (BOOL)validateParentDirectoryRecord:(SVDirectoryPublishingRecord **)outRecord
                                error:(NSError **)error;
{
    return YES;
}

@end
