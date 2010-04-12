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

+ (SVPublishingRecord *)insertNewRegularFileIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPublishingRecord *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"FilePublishingRecord"
                                  inManagedObjectContext:context];
    
    return result;
}

+ (SVPublishingRecord *)insertNewDirectoryIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVPublishingRecord *result =
    [NSEntityDescription insertNewObjectForEntityForName:@"DirectoryPublishingRecord"
                                  inManagedObjectContext:context];
    
    return result;
}

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

- (SVPublishingRecord *)publishingRecordForSHA1Digest:(NSData *)digest;
{
    if ([[self SHA1Digest] isEqual:digest])
    {
        return self;
    }
    else
    {
        for (SVPublishingRecord *aRecord in [self contentRecords])
        {
            SVPublishingRecord *result = [aRecord publishingRecordForSHA1Digest:digest];
            if (result) return result;
        }
    }
    
    return nil;
}

@dynamic date;
@dynamic SHA1Digest;
@dynamic length;

@end
