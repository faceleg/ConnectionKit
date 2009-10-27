//
//  SVSidebar.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <CoreData/CoreData.h>

@class KTAbstractPage;
@class SVSidebarEntry;


@interface SVSidebar :  NSManagedObject  

@property(nonatomic, retain) KTAbstractPage * page;

@property(nonatomic, retain) SVSidebarEntry *firstEntry;
//- (NSMutableArray *)pagelets; // NOT KVO-compliant

@end

