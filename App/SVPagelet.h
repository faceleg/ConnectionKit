//
//  SVPagelet.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

@class SVTitleBox, SVBody;
@class KTPage, SVSidebar, SVCallout, SVTemplate;


@interface SVPagelet : SVContentObject

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;
+ (NSArray *)pageletSortDescriptors;

// Checks that a given set of pagelets have unique sort keys
+ (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;


#pragma mark Title
@property(nonatomic, retain) SVTitleBox *titleBox;
- (void)setTitleWithString:(NSString *)title;   // creates Title object if needed
+ (NSString *)placeholderTitleText;


#pragma mark Layout/Styling
@property(nonatomic, copy) NSNumber *showBorder;


#pragma mark Sidebar

@property(nonatomic, readonly) NSSet *sidebars;

- (void)moveBeforePagelet:(SVPagelet *)pagelet;
- (void)moveAfterPagelet:(SVPagelet *)pagelet;

// Shouldn't really have any need to set this yourself. Use a proper array controller instead please.
@property(nonatomic, copy) NSNumber *sortKey;


#pragma mark Callout
@property(nonatomic, readonly) SVCallout *callout;


#pragma mark HTML
+ (SVTemplate *)template;

@property(nonatomic, retain, readonly) NSString *elementID;


@end



