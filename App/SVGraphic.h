//
//  SVGraphic.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"


typedef enum {
    SVGraphicPlacementInline,
    SVGraphicPlacementBlock,
} SVGraphicPlacement;

typedef enum {
    SVGraphicWrapNone,
    SVGraphicWrapLeftSplit,
    SVGraphicWrapCenterSplit,
    SVGraphicWrapRightSplit,
    SVGraphicWrapLeft,
    SVGraphicWrapCenter,
    SVGraphicWrapRight,
} SVGraphicWrap;


#define SVContentObjectWrapNone [NSNumber numberWithInteger:SVGraphicWrapNone]
#define SVContentObjectWrapFloatLeft [NSNumber numberWithInteger:SVGraphicWrapLeft]
#define SVContentObjectWrapFloatRight [NSNumber numberWithInteger:SVGraphicWrapRight]
#define SVContentObjectWrapBlockLeft [NSNumber numberWithInteger:SVGraphicWrapLeftSplit]
#define SVContentObjectWrapBlockCenter [NSNumber numberWithInteger:SVGraphicWrapCenterSplit]
#define SVContentObjectWrapBlockRight [NSNumber numberWithInteger:SVGraphicWrapRightSplit]
//typedef NSNumber SVContentObjectWrap;
#define SVContentObjectWrap NSNumber


#pragma mark -


//  Have decided to use the term "graphic" in the same way that Pages does through its scripting API (and probably in its class hierarchy). That is, a graphic is anything on the page that can be selected and isn't text. e.g. pagelets, images, plug-ins.

//  I'm declaring a protocol for graphics first to keep things nice and pure. (Also, it means I can make some things @optional so that Core Data will still generate accessors when the superclass chooses not to implement the method)

@protocol SVGraphic
- (NSString *)elementID;
@optional
@end


#pragma mark -


@class SVTitleBox;
@class SVCallout, SVTextAttachment, SVTemplate;


@interface SVGraphic : SVContentObject <SVGraphic>

#pragma mark Pagelet
- (BOOL)isPagelet;  // whether to generate <div class="pagelet"> etc. HTML


#pragma mark Title
@property(nonatomic, retain) SVTitleBox *titleBox;
- (void)setTitle:(NSString *)title;   // creates Title object if needed
+ (NSString *)placeholderTitleText;


#pragma mark Layout/Styling
@property(nonatomic, copy) NSNumber *showBackground;
@property(nonatomic, copy) NSNumber *showBorder;


#pragma mark Placement

/*  There is generally no need to directly adjust a graphic's wrap setting. In particular, one hazard is that you could cause a block-level object appear inline. i.e. invalid HTML. Instead, use the higher-level DOM Controller API to modify wrap/placement of the selection.
 */

@property(nonatomic, readonly) SVCallout *callout;

@property(nonatomic, retain) SVTextAttachment *textAttachment;
- (BOOL)canBePlacedInline;  // default is NO. Subclasses can override

@property(nonatomic, copy) SVContentObjectWrap *wrap;
@property(nonatomic, copy) NSNumber *wrapIsFloatOrBlock;    // setter picks best wrap type
@property(nonatomic) BOOL wrapIsFloatLeft;
@property(nonatomic) BOOL wrapIsFloatRight;
@property(nonatomic) BOOL wrapIsBlockLeft;
@property(nonatomic) BOOL wrapIsBlockCenter;
@property(nonatomic) BOOL wrapIsBlockRight;


#pragma mark Sidebar

+ (NSArray *)sortedPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)arrayBySortingPagelets:(NSSet *)pagelets;
+ (NSArray *)pageletSortDescriptors;

// Checks that a given set of pagelets have unique sort keys
+ (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;

// Shouldn't really have any need to set this yourself. Use a proper array controller instead please.
@property(nonatomic, copy) NSNumber *sortKey;

@property(nonatomic, readonly) NSSet *sidebars;

- (void)moveBeforeSidebarPagelet:(SVGraphic *)pagelet;
- (void)moveAfterSidebarPagelet:(SVGraphic *)pagelet;


#pragma mark HTML

- (void)writeBody;  // Subclasses MUST override

@property(nonatomic, retain, readonly) NSString *elementID;
- (NSString *)className;

+ (SVTemplate *)template;


@end


