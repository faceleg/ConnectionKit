//
//  SVRootPublishingRecord.h
//  Sandvox
//
//  Created by Mike on 19/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVDirectoryPublishingRecord.h"

@class KTHostProperties;

@interface SVRootPublishingRecord :  SVDirectoryPublishingRecord  
{
}

@property (nonatomic, retain) KTHostProperties * hostProperties;

@end



