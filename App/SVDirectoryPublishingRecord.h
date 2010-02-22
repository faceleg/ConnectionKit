//
//  SVDirectoryPublishingRecord.h
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVPublishingRecord.h"

@class SVPublishingRecord;

@interface SVDirectoryPublishingRecord :  SVPublishingRecord  

- (SVPublishingRecord *)directoryPublishingRecordWithFilename:(NSString *)filename;
- (SVPublishingRecord *)regularFilePublishingRecordWithFilename:(NSString *)filename;

@end



