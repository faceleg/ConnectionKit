//
//  SVPublishingRecord.h
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
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


#pragma mark Attributes
@property(nonatomic, copy) NSNumber *length;
@property(nonatomic, copy, readonly) NSData *SHA1Digest;    // pub engine maintains
@property(nonatomic, copy, readonly) NSData *contentHash; // like SHA1Digest, but content-specific
@property(nonatomic, copy) NSDate *date;
@property(nonatomic, copy) NSDate *modificationDate;


@end



