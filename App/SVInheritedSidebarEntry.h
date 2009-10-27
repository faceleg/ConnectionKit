//
//  SVInheritedSidebarEntry.h
//  Sandvox
//
//  Created by Mike on 27/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "SVSidebarEntry.h"

@class SVSidebarEntry;

@interface SVInheritedSidebarEntry :  SVSidebarEntry  
{
}

@property (nonatomic, retain) SVSidebarEntry * sourceEntry;

@end



