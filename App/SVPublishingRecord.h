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

- (BOOL)isRegularFile;
- (BOOL)isDirectory;

@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) SVDirectoryPublishingRecord *parentDirectoryRecord;

@property (nonatomic, retain) NSSet *contentRecords;
- (SVPublishingRecord *)publishingRecordForFilename:(NSString *)filename;

@property(nonatomic, retain) NSDate *date;
@property(nonatomic, retain) NSData *SHA1Digest;
@property(nonatomic, retain) NSNumber *length;

@end



