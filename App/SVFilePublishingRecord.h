//
//  SVFilePublishingRecord.h
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVPublishingRecord.h"


@interface SVFilePublishingRecord :  SVPublishingRecord  
{
}

@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSData * SHA1Digest;
@property (nonatomic, retain) NSNumber * length;

@end



