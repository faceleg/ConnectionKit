//
//  SVPagelet.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

@class SVTextField, SVBody;
@class KTPage, SVSidebar;


@interface SVPagelet : SVGraphic  

+ (SVPagelet *)pageletWithManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;


#pragma mark Title
@property(nonatomic, retain) SVTextField *title;
- (void)setTitleWithString:(NSString *)title;   // creates Title object if needed


#pragma mark Other
@property(nonatomic, retain, readonly) SVBody *body;
@property(nonatomic, copy) NSNumber *showBorder;


#pragma mark Sidebar

@property(nonatomic, readonly) NSSet *sidebars;

- (void)moveBeforePagelet:(SVPagelet *)pagelet;
- (void)moveAfterPagelet:(SVPagelet *)pagelet;


@end



