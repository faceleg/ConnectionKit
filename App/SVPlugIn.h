//
//  SVContentPlugIn.h
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>
#import "SVPlugInContext.h"
#import "SVPasteboardItem.h"


// Priority
typedef enum { 
	SVPasteboardPriorityNone = 0,				// Can't handle drag clipboard
	SVPasteboardPriorityMinimum = 1,			// Bare minimum, for a generic file handler
	SVPasteboardPriorityFallback = 10,			// Could handle it, but there are probably better handlers
	SVPasteboardPriorityReasonable = 20,		// Reasonable handler, unless there's a better one
	SVPasteboardPriorityTypical = 30,			// Relatively specialized handler
	SVPasteboardPriorityIdeal = 40,				// More specialized, better equipped than lessers.
	SVPasteboardPrioritySpecialized = 50		// Specialized for these data, e.g. Amazon Books URL
} SVPasteboardPriority;


@protocol SVPage;


@interface SVPlugIn : NSObject
{
  @private
    id  _container;
    id  _template;
    id  _reserved;
    id  _reserved2;
}


#pragma mark Initialization

/*  Called when inserting a fresh new plug-in (e.g. the insert menu), but not from drag 'n' drop etc.
 *  Calls -makeOriginalSize. You can override this method to also set any initial properties. It's also handy to grab the current URL from user's web browser if your plug-in can make use of it.
 */
- (void)awakeFromNew;

// like the Core Data method
- (void)awakeFromFetch;

// More details at http://docs.karelia.com/z/Sandvox_Developers_Guide.html#Plug-In_Initialization


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

/*  Default implementation:
 *   1. Looks up SVPlugInCSSFiles in the Info.plist and adds those files to the context
 *   2. Sets -currentContext to return the context
 *   3. Parses the HTML template if found
 *
 *  Generally, two possible reasons to override this method:
 *   A. Register any additional dependencies, CSS, etc. with the context and call super
 *   B. Don't call super; write HTML directly to the context without using a template
 */
- (void)writeHTML:(id <SVPlugInContext>)context;

// Sandvox supplies the current context for template-based plug-ins. Generally no reason to override this
@property(nonatomic, readonly) id <SVPlugInContext> currentContext;


#pragma mark Layout

@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL showsTitle;

@property(nonatomic) BOOL showsIntroduction;
@property(nonatomic) BOOL showsCaption;

@property(nonatomic, getter=isBordered) BOOL bordered;


#pragma mark Metrics

// The values reported in the Metrics Inspector. A value of nil appears as "auto" in the Inspector.
// It is important to remember that this is the size of your plug-in's *content* as far as users are concerned. Thus, Sandvox will generally NOT generate HTML that enforces these sizes; that is your responsibility. (The exception being that when placed inline, if your plug-in generates no resizable elements of its own, Sandvox will make one to enclose the entire plug-in)
// Both are KVO-compliant
@property(nonatomic, readonly) NSNumber *width;
@property(nonatomic, readonly) NSNumber *height;

// Normally, sizing is left to the user's control, but call this method if you want to customize (e.g. when overriding -makeOriginalSize)
// Please use integer values. A value of nil appears as "auto" in the Inspector.
- (void)setWidth:(NSNumber *)width height:(NSNumber *)height;

// Override these if your plug-in is more liberal than the defaults
- (NSNumber *)minWidth;    // default is 200
- (NSNumber *)minHeight;    // default is 1

// Called when plug-in is first inserted, and whenever 'Original Size' button in the Inspector is clicked. Override to call -setWidth:height: if you're not happy with the default size used (200 x 0 [automatic height] for now).
- (void)makeOriginalSize;


#pragma mark Resizing

// If you need to include some chrome around the content. (e.g. controller on a video player), implement these methods to specify how much padding is needed. Default is nil padding.
- (NSNumber *)elementWidthPadding;
- (NSNumber *)elementHeightPadding;

// Default is nil (unconstrained). You can override to get resizing behaviour that constrains proportions
- (NSNumber *)constrainedAspectRatio;


#pragma mark Pages
// Called whenever the environment for the plug-in changes significantly. This covers:
//
//  - Inserting the plug-in into a page
//  - Changing placement within a page (e.g. from callout to inline)
//  - A significant feature of the page changes, such as the design
//
// Plug-ins might use this to populate some default settings based off the page. e.g. using the page's language
- (void)pageDidChange:(id <SVPage>)page;


#pragma mark UI
// Default implementation looks for a Template.nib file (xibs work too). If found, a view controller is made and returned.
// The class name for the controller is guessed, as described at http://www.karelia.com/sandvox/help/z/Sandvox_Developers_Guide.html#Further_Inspector_Customization
// Override if that behaviour isn't enough
+ (SVInspectorViewController *)makeInspectorViewController;


#pragma mark Pasteboard

/*  These methods are called in order when content is dragged or pasted in
 */

// 1. Default is nil, override to return the types you support. As a starting point, +readableURLTypesForPasteboard: covers all the formats that Sandvox can interpret URLs from for you
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;

// 2. Default is NO. If overridden to return YES, when the user drags multiple items into a page, a single instance of your plug-in will be awoken from the handled items. (The usual behaviour would be to create one plug-in per item). Ideal for plug-ins which have a list-like display
+ (BOOL)supportsMultiplePasteboardItems;

// 3. Override to study the item and return a SVPasteboardPriority to match. The plug-in with the highest priority for an item moves onto step 4
+ (SVPasteboardPriority)priorityForPasteboardItem:(id <SVPasteboardItem>)item;

// 4. items is an array of SVPasteboardItems. Loop through as many items as your plug-in can handle (most will only bother to look at the first), and set properties from it
- (BOOL)awakeFromPasteboardItems:(NSArray *)items;


#pragma mark Pasteboard Support

// All the types that -[SVPasteboardItem URL] supports. Great starting point for your implementation of +readableTypesForPasteboard:
+ (NSArray *)readableURLTypesForPasteboard:(NSPasteboard *)pasteboard;

// For if you need to interpret pasteboard items manually, perhaps as part of a drag & drop implementation for plug-in's inspector
+ (NSArray *)pasteboardItemsFromPasteboard:(NSPasteboard *)pasteboard;


#pragma mark Undo Management
// Don't have direct access to undo manager
- (void)disableUndoRegistration;
- (void)enableUndoRegistration;


@end


#pragma mark -


@interface SVPlugIn (Migration)

#pragma mark Migration from 1.5
// Called to migrate plug-ins from 1.5 properties to 2.0. Probably not applicable to third-party developers
// Default behaviour is to read each +plugInKeys value and set them on self. Subclasses can override to do additional processing
- (void)awakeFromSourceProperties:(NSDictionary *)properties;
- (void)awakeFromSourceInstance:(NSManagedObject *)sInstance;   // calls -awakeFromSourceProperties:

@end

