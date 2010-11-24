//
//  SVContentPlugIn.h
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPlugInContext.h"
#import "SVPasteboardItem.h"


@protocol SVPage, SVWebLocation;


@interface SVPlugIn : NSObject
{
  @private
    id  _container;
    id  _template;
}


#pragma mark Initialization

/*  Called when inserting a fresh new plug-in (e.g. the insert menu), but not from drag 'n' drop etc.
 *  Retrieves KTPluginInitialProperties from the bundle and calls -setSerializedValue:forKey: with them. Finally, calls -makeOriginalSize
 */
- (void)awakeFromNew;

- (void)awakeFromFetch; // like the Core Data method


#pragma mark Storage

/*
 Returns the list of KVC keys representing the internal settings of the plug-in. At the moment you must override it in all plug-ins that have some kind of storage, but at some point I'd like to make it automatically read the list in from bundle's Info.plist.
 This list of keys is used for automatic serialization of these internal settings.
 */
+ (NSArray *)plugInKeys;

/*
 The default implementation of -serializedValueForKey: calls -valueForKey: to retrieve the value for the key, then does nothing for NSString, NSNumber, NSDate and uses <NSCoding> encoding for others.
 The default implementation of -setSerializedValue:forKey calls -setValue:forKey: after decoding the serialized value if necessary.
 Override these methods if the plug-in needs to handle internal settings of an unusual type (typically if the result of -valueForKey: does not conform to the <NSCoding> protocol). If so, returned value must be a Plist compliant object i.e. exclusively NSString, NSNumber, NSDate, NSData.
 */
- (id)serializedValueForKey:(NSString *)key;
- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;

- (void)setNilValueForKey:(NSString *)key;  // default implementation calls -setValue:forKey: with 0 number


/*  FAQ:    How do I reference a page from a plug-in?
 *
 *      Once you've gotten hold of an SVPage object, it's fine to hold it in memory like any other object; just shove it in an instance variable and retain it. You should then also observe SVPageWillBeDeletedNotification and use it discard your reference to the page, as it will become invalid after that.
 *      To persist your reference to the page, override -serializedValueForKey: to use the page's -identifier property. Likewise, override -setSerializedValue:forKey: to take the serialized ID string and convert it back into a SVPage using -pageWithIdentifier:
 *      All of these methods are documented in SVPageProtocol.h
 */


#pragma mark HTML

/*  Default implementation generates a <span> or <div> (with an appropriate id) that contains the result of -writeInnerHTML:. There is generally NO NEED to override this, and if you do, you MUST write HTML with an enclosing element of the specified ID.
 *  Also looks in Info.plist for CSS files to add to the context
 */
- (void)writeHTML:(id <SVPlugInContext>)context;

// For the benefit of methods which don't have direct access to the context. e.g. methods called from an HTML template.
+ (id <SVPlugInContext>)currentContext;

// Default implementation parses the template specified in Info.plist
- (void)writeInnerHTML:(id <SVPlugInContext>)context;


#pragma mark Layout

@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL showsTitle;

@property(nonatomic) BOOL showsIntroduction;
@property(nonatomic) BOOL showsCaption;

@property(nonatomic, getter=isBordered) BOOL bordered;


#pragma mark Metrics

// Nil values are treated as "auto" size
- (NSNumber *)width;
- (NSNumber *)height;
- (void)setWidth:(NSNumber *)width height:(NSNumber *)height;

// Override these if your plug-in is more liberal than the defaults
- (NSUInteger)minWidth;    // default is 200
- (NSUInteger)minHeight;    // default is 1

// Called when plug-in is first inserted, and whenever 'Original Size' button in the Inspector is clicked. Override to call -setWidth:height: if you're not happy with the default size used (200 x 0 for now).
- (void)makeOriginalSize;


#pragma mark Resizing

// Default is NO. If your plug-in is based around a sizeable object (e.g. YouTube) return YES to get proper behaviour. This makes width editable in the Inspector when not placed inline (and perhaps more, but you get the idea).
+ (BOOL)isExplicitlySized;
// If you also need to include some chrome around the content. (e.g. controller on a video player), implement these methods to specify how much padding is needed. Default is nil padding.
- (NSNumber *)elementWidthPadding;
- (NSNumber *)elementHeightPadding;

// Default is nil (unconstrained). You can override to get resizing behaviour that constrains proportions
- (NSNumber *)constrainedAspectRatio;


#pragma mark Pages
// Called whenever the plug-in is added to a different page, moves placement within a page, or a significant feature of the page changes such as the design.
- (void)didAddToPage:(id <SVPage>)page;


#pragma mark UI
// Default implementation guesses classname and nib, returning nil if they're not found. Override if you that's not good enough.
+ (SVInspectorViewController *)makeInspectorViewController;


#pragma mark Pasteboard
// Default is to refuse all items. You should study the location and return a KTSourcePriority to match
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
+ (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
+ (BOOL)supportsMultiplePasteboardItems;


#pragma mark Undo Management
// Don't have direct access to undo manager
- (void)disableUndoRegistration;
- (void)enableUndoRegistration;


@end


#pragma mark -


// Priority
typedef enum { 
	KTSourcePriorityNone = 0,				// Can't handle drag clipboard
	KTSourcePriorityMinimum = 1,			// Bare minimum, for a generic file handler
	KTSourcePriorityFallback = 10,			// Could handle it, but there are probably better handlers
	KTSourcePriorityReasonable = 20,		// Reasonable handler, unless there's a better one
	KTSourcePriorityTypical = 30,			// Relatively specialized handler
	KTSourcePriorityIdeal = 40,				// More specialized, better equipped than lessers.
	KTSourcePrioritySpecialized = 50		// Specialized for these data, e.g. Amazon Books URL
} KTSourcePriority;

