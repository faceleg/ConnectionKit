// 
//  SVPublishingRecord.m
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishingRecord.h"

#import "SVDirectoryPublishingRecord.h"

#import "NSString+Karelia.h"


@implementation SVPublishingRecord 

- (BOOL)isRegularFile; { return NO; }
- (BOOL)isDirectory; { return NO; }

@dynamic filename;
- (BOOL)validateFilename:(NSString **)outFilename error:(NSError **)error;
{
    if (!*outFilename)
    {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationMissingMandatoryPropertyError userInfo:nil];
        return NO;
    }
    
    return YES;
}

@dynamic parentDirectoryRecord;
- (BOOL)validateParentDirectoryRecord:(SVDirectoryPublishingRecord **)outRecord
                                error:(NSError **)error;
{
    if (!*outRecord)
    {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationMissingMandatoryPropertyError userInfo:nil];
        return NO;
    }
    
    return YES;
}

@dynamic contentRecords;

- (SVPublishingRecord *)publishingRecordForFilename:(NSString *)filename;
{
    SVPublishingRecord *result = nil;
    for (result in [self contentRecords])
    {
        if ([[result filename] isEqualToStringCaseInsensitive:filename]) break;
    }
    
    return result;
}

@end
