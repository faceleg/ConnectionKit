//
//  SVGraphic.h
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  We use the term "graphic" in the same way that Pages does through its scripting API (and probably in its class hierarchy). That is, a graphic is basically anything on the page that can be selected. From there, e.g. images are a type of graphic.
//  All graphics are persisted in the model using SVGraphic or one of its subclasses.



#import "SVContentObject.h"
#import "SVGraphicContainer.h"

#import "SVPlugIn.h"

#import "NSManagedObject+KTExtensions.h"    // for serialization

#import <iMedia/iMedia.h>


typedef enum {
    SVGraphicPlacementInline,
    SVGraphicPlacementCallout,
    SVGraphicPlacementSidebar,
} SVGraphicPlacement;

typedef enum {  // Note that "left" or "right" refers to the side of the graphic *text* will be placed
    SVGraphicWrapFloat_1_0, // to handle migrated docs only
    SVGraphicWrapLeftSplit,
    SVGraphicWrapCenterSplit,
    SVGraphicWrapRightSplit,
    SVGraphicWrapLeft,
    SVGraphicWrapCenter,
    SVGraphicWrapRight,
} SVGraphicWrap;


#define SVContentObjectWrapNone [NSNumber numberWithInteger:SVGraphicWrapFloat_1_0]
#define SVContentObjectWrapFloatLeft [NSNumber numberWithInteger:SVGraphicWrapLeft]
#define SVContentObjectWrapFloatRight [NSNumber numberWithInteger:SVGraphicWrapRight]
#define SVContentObjectWrapBlockLeft [NSNumber numberWithInteger:SVGraphicWrapLeftSplit]
#define SVContentObjectWrapBlockCenter [NSNumber numberWithInteger:SVGraphicWrapCenterSplit]
#define SVContentObjectWrapBlockRight [NSNumber numberWithInteger:SVGraphicWrapRightSplit]
//typedef NSNumber SVContentObjectWrap;
#define SVContentObjectWrap NSNumber


#pragma mark -


@protocol SVGraphic <SVGraphicContainer>

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *contentWidth;  // what appears in the Inspector
- (NSNumber *)containerWidth;
- (BOOL)isExplicitlySized;

- (id <SVGraphic>)captionGraphic;


#pragma mark HTML
- (void)writeBody:(SVHTMLContext *)context;  // Subclasses MUST override
- (BOOL)shouldWriteHTMLInline;
- (BOOL)isPagelet;      // whether to generate <div class="pagelet"> etc. HTML. KVO-compliant


@end


#pragma mark -


extern NSString *kSVGraphicPboardType;


@class KTPage, SVTitleBox;
@class SVTextAttachment, SVHTMLContext, SVTemplate;
@class SVAuxiliaryPageletText;
@protocol SVPage, SVMedia, SVEnclosure;


@interface SVGraphic : KSExtensibleManagedObject <SVGraphic, IMBImageItem>

#pragma mark Initialization
- (void)awakeFromNew;
- (void)pageDidChange:(id <SVPage>)page;


#pragma mark Placement
@property(nonatomic, readonly) NSNumber *placement; // SVGraphicPlacement
- (BOOL)isPlacementEditable;    // yes for sidebar & article embedded graphics


#pragma mark Pagelet

- (BOOL)canWriteHTMLInline;   // NO for most graphics. Images and Raw HTML return YES

- (BOOL)isCallout;  // whether to generate enclosing <div class="callout"> etc.
- (NSString *)calloutWrapClassName; // nil if not a callout

+ (void)write:(SVHTMLContext *)context pagelet:(id <SVGraphic>)graphic;


#pragma mark Title
@property(nonatomic, copy) NSString *title;         // convenience
@property(nonatomic) BOOL showsTitle;               // convenience
@property(nonatomic, retain) SVTitleBox *titleBox;  // full API
+ (NSString *)placeholderTitleText;


#pragma mark Intro & Caption

@property(nonatomic, retain) SVAuxiliaryPageletText *introduction;
@property(nonatomic) BOOL showsIntroduction;    // convenience
- (BOOL)canHaveIntroduction;

@property(nonatomic, retain) SVAuxiliaryPageletText *caption;
@property(nonatomic) BOOL showsCaption;         // convenience
- (BOOL)canHaveCaption;

- (void)createDefaultIntroAndCaption;


#pragma mark Layout/Styling
@property(nonatomic, copy) NSNumber *showBackground;
@property(nonatomic, getter=isBordered) BOOL bordered;
@property(nonatomic, copy) NSNumber *showBorder;


#pragma mark Metrics

@property(nonatomic, copy) NSNumber *width;
@property(nonatomic, copy) NSNumber *height;
- (NSUInteger)area; // 0 if either dimension is auto. Used for thumbnail

- (NSUInteger)minWidth; // 200 by default
- (CGFloat)maxWidthOnPage:(id <SVPage>)page;
- (NSNumber *)maxHeight;    // nil, the default, if there isn't one
- (BOOL)validateWidth:(NSNumber **)width error:(NSError **)error;

- (NSNumber *)constrainedProportionsRatio;

- (void)makeOriginalSize;
- (BOOL)canMakeOriginalSize;

- (NSNumber *)elementWidthPadding;
- (NSNumber *)elementHeightPadding;


#pragma mark Text Attachment

/*  There is generally no need to directly adjust a graphic's wrap setting. In particular, one hazard is that you could cause a block-level object appear inline. i.e. invalid HTML. Instead, use the higher-level DOM Controller API to modify wrap/placement of the selection.
 */

@property(nonatomic, retain) SVTextAttachment *textAttachment;


#pragma mark Sidebar

// Checks that a given set of pagelets have unique sort keys
+ (BOOL)validateSortKeyForPagelets:(NSSet **)pagelets error:(NSError **)error;

// Shouldn't really have any need to set this yourself. Use an SVSidebarPageletsController instead please.
@property(nonatomic, copy) NSNumber *sortKey;

@property(nonatomic, readonly) NSSet *sidebars;


#pragma mark Pages
- (NSSet *)pages;   // all the pages graphic is known to appear on


#pragma mark Template
@property(nonatomic) BOOL wasCreatedByTemplate;


#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;  // Subclasses MUST override

- (void)buildClassName:(SVHTMLContext *)context;
- (NSString *)inlineGraphicClassName;

+ (SVTemplate *)template;

- (NSString *)parsedPlaceholderHTMLFromContext:(SVHTMLContext *)context;


#pragma mark Thumbnail
- (void)writeThumbnailImage:(SVHTMLContext *)context
                   width:(NSUInteger)width
                  height:(NSUInteger)height
                  options:(SVThumbnailOptions)options;


#pragma mark RSS
@property(nonatomic, copy) NSNumber *includeAsRSSEnclosure; // BOOL, mandatory
- (id <SVEnclosure>)enclosure;  // default is nil


#pragma mark Pasteboard
- (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
- (BOOL)awakeFromPasteboardItems:(NSArray *)items;


#pragma mark Inspector
// To get yourself in the plug-in Inspector, need to:
//  1.  Implement -plugInIdentifier to return a unique value like a plug-in would
//  2.  Override +makeInspectorViewController to create and return a controller
+ (SVInspectorViewController *)makeInspectorViewController;
- (id)objectToInspect;


#pragma mark Serialization

- (void)writeToPasteboard:(NSPasteboard *)pboard;   // like other Cocoa methods of same sig.

+ (NSArray *)graphicsFromPasteboard:(NSPasteboard *)pasteboard
     insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

+ (id)graphicWithSerializedProperties:(id)properties
       insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


@end


