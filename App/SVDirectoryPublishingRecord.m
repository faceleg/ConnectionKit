// 
//  SVDirectoryPublishingRecord.m
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDirectoryPublishingRecord.h"

#import "SVPublishingRecord.h"

#import "NSError+Karelia.h"


@implementation SVDirectoryPublishingRecord 

- (BOOL)isDirectory; { return YES; }

- (SVPublishingRecord *)directoryPublishingRecordWithFilename:(NSString *)filename;
{
    SVPublishingRecord *result = [self publishingRecordForFilename:filename];
    
    if (![result isDirectory])
    {
        [[result managedObjectContext] deleteObject:result];
        
        result = [SVPublishingRecord insertNewDirectoryIntoManagedObjectContext:
                   [self managedObjectContext]];
        
        [result setFilename:filename];
        [result setParentDirectoryRecord:self];
    }
    
    return result;
}

- (SVPublishingRecord *)regularFilePublishingRecordWithFilename:(NSString *)filename;
{
    SVPublishingRecord *result = [self publishingRecordForFilename:filename];
    
    if (![result isRegularFile])
    {
        [[result managedObjectContext] deleteObject:result];
        
        result = [SVPublishingRecord insertNewRegularFileIntoManagedObjectContext:
                   [self managedObjectContext]];
        
        [result setFilename:filename];
        [result setParentDirectoryRecord:self];
    }
    
    return result;
}

- (BOOL)validateContentRecords:(NSSet **)outRecords error:(NSError **)error;
{
    // Ensure filenames are unique
    NSSet *filenames = [*outRecords valueForKeyPath:@"filename.lowercaseString"];
    BOOL result = ([filenames count] == [*outRecords count]);
    
    if (!result && error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                       code:NSValidationRelationshipLacksMinimumCountError
                                       localizedDescription:@"filenames are not unique"];
    
    return result;
}

@end
