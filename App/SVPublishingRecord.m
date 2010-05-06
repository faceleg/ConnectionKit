// 
//  SVPublishingRecord.m
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishingRecord.h"

#import "SVDirectoryPublishingRecord.h"

#import "NSError+Karelia.h"
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

#pragma mark Path

- (NSString *)path; // relative to the root record
{
    NSString *result = [[[self parentDirectoryRecord] path] stringByAppendingPathComponent:[self filename]];
    return result;
}

@dynamic filename;
- (BOOL)validateFilename:(NSString **)outFilename error:(NSError **)error;
{
    // Don't allow filename to change once it's been set
    if ([self filename])
    {
        if (![[self filename] isEqualToString:*outFilename])
        {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSManagedObjectValidationError
                                    localizedDescription:@"Publishing record paths are immutable"];
            return NO;
        }
    }
    
    // Filename is non-optional
    else if (!*outFilename)
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
    if (![self isDirectory])
    {
        if ([[self SHA1Digest] isEqual:digest])
        {
            return self;
        }
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

#pragma mark Attributes

@dynamic date;
@dynamic modificationDate;
@dynamic SHA1Digest;
@dynamic length;

@end
