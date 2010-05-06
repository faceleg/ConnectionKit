//
//  SVPublishingRecord.h
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>


@class SVDirectoryPublishingRecord;


@interface SVPublishingRecord : NSManagedObject  
{
}

+ (SVPublishingRecord *)insertNewRegularFileIntoManagedObjectContext:(NSManagedObjectContext *)context;
+ (SVPublishingRecord *)insertNewDirectoryIntoManagedObjectContext:(NSManagedObjectContext *)context;

- (BOOL)isRegularFile;
- (BOOL)isDirectory;

#pragma mark Path
- (NSString *)path; // relative to the root record
@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) SVDirectoryPublishingRecord *parentDirectoryRecord;

@property (nonatomic, retain) NSSet *contentRecords;
- (SVPublishingRecord *)publishingRecordForFilename:(NSString *)filename;
- (SVPublishingRecord *)publishingRecordForSHA1Digest:(NSData *)digest;


#pragma mark Attributes
@property(nonatomic, copy) NSNumber *length;
@property(nonatomic, copy) NSData *SHA1Digest;
@property(nonatomic, copy) NSDate *date;
@property(nonatomic, copy) NSDate *modificationDate;


@end



