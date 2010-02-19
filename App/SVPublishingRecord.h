//
//  SVPublishingRecord.h
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class SVDirectoryPublishingRecord;

@interface SVPublishingRecord :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * filename;
@property (nonatomic, retain) SVDirectoryPublishingRecord * parentDirectoryRecord;

@end



