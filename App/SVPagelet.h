//
//  SVPagelet.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

@class SVTextField, SVBody;
@class KTPage, SVSidebar, SVTemplate;


@interface SVPagelet : SVGraphic  

+ (SVPagelet *)insertNewPageletIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;


#pragma mark Title
@property(nonatomic, retain) SVTextField *title;
- (void)setTitleWithString:(NSString *)title;   // creates Title object if needed
+ (NSString *)placeholderTitleText;


#pragma mark Body Text
@property(nonatomic, retain, readonly) SVBody *body;


#pragma mark Layout/Styling
@property(nonatomic, copy) NSNumber *showBorder;
- (BOOL)isCallout;  // name is hangover from 1.x. Not KVO-compliant. Yet.


#pragma mark Sidebar

@property(nonatomic, readonly) NSSet *sidebars;

- (void)moveBeforePagelet:(SVPagelet *)pagelet;
- (void)moveAfterPagelet:(SVPagelet *)pagelet;


#pragma mark HTML
- (NSString *)HTMLString;
+ (SVTemplate *)pageletHTMLTemplate;
+ (SVTemplate *)calloutHTMLTemplate;

@end



