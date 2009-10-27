//
//  SVPageletSidebarEntry.h
//  Sandvox
//
//  Created by Mike on 27/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVSidebarEntry.h"

@class SVPagelet;

@interface SVPageletSidebarEntry :  SVSidebarEntry  
{
}

@property (nonatomic, retain) SVPagelet * pagelet;

@end



