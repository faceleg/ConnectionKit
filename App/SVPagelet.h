//
//  SVPagelet.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

@class SVPageletBody;
@class KTPage, SVSidebar;


@interface SVPagelet : SVGraphic  

+ (SVPagelet *)pageletWithManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;

@property(nonatomic, retain) NSString *titleHTMLString;
@property(nonatomic, retain, readonly) SVPageletBody *body;
@property(nonatomic, copy) NSNumber *showBorder;


#pragma mark Sidebar

@property(nonatomic, readonly) NSSet *sidebars;

- (void)moveBeforePagelet:(SVPagelet *)pagelet;
- (void)moveAfterPagelet:(SVPagelet *)pagelet;


@end



