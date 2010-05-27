//
//  SVPlugIn.h
//  Sandvox
//
//  Created by Mike on 29/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KT.h"

#import <iMedia/IMBImageItem.h>


@class KSHTMLWriter, SVInspectorViewController;
@protocol SVPlugInContext, SVPage, SVPageletPlugInContainer;


@protocol SVPlugIn <NSObject>

#pragma mark Managing Life Cycle

// Just like the Core Data methods of same name really
- (void)awakeFromInsert;
- (void)awakeFromFetch;

- (void)setContainer:(id <SVPageletPlugInContainer>)container;


#pragma mark Identifier
+ (NSString *)plugInIdentifier; // use standard reverse DNS-style string


#pragma mark HTML Generation
- (void)writeHTML:(id <SVPlugInContext>)context;


#pragma mark Storage
/*
 Returns the list of KVC keys representing the internal settings of the plug-in. At the moment you must override it in all plug-ins that have some kind of storage, but at some point I'd like to make it automatically read the list in from bundle's Info.plist.
 This list of keys is used for automatic serialization of these internal settings.
 */
+ (NSSet *)plugInKeys;

// The serialized object must be a non-container Plist compliant object i.e. exclusively NSString, NSNumber, NSDate, NSData.
- (id)serializedValueForKey:(NSString *)key;
- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;


/*  FAQ:    How do I reference a page from a plug-in?
 *
 *      Once you've gotten hold of an SVPage object, it's fine to hold it in memory like any other object; just shove it in an instance variable and retain it. You should then also observe SVPageWillBeDeletedNotification and use it discard your reference to the page, as it will become invalid after that.
 *      To persist your reference to the page, override -serializedValueForKey: to use the page's -identifier property. Likewise, override -setSerializedValue:forKey: to take the serialized ID string and convert it back into a SVPage using -pageWithIdentifier:
 *      All of these methods are documented in SVPageProtocol.h
 */


#pragma mark Pages
- (void)didAddToPage:(id <SVPage>)page;


#pragma mark Thumbnail
- (id <IMBImageItem>)thumbnail;


#pragma mark UI
+ (SVInspectorViewController *)makeInspectorViewController; // return nil if you don't want an Inspector


@end


#pragma mark -


@protocol SVHTMLWriter

- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes;
- (void)startElement:(NSString *)tagName;
- (void)startElement:(NSString *)tagName className:(NSString *)className;
- (void)startElement:(NSString *)tagName idName:(NSString *)idName className:(NSString *)className;
- (void)endElement;

- (void)writeText:(NSString *)string;

- (void)writeComment:(NSString *)comment;   // escapes the string, and wraps in a comment tag

- (void)writeHTMLString:(NSString *)html;

//  <a href="...." target="..." rel="nofollow">
- (void)startAnchorElementWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;

//  <img src="..." alt="..." width="..." height="..." />
- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                         src:(NSString *)src
                         alt:(NSString *)alt
                       width:(NSString *)width
                      height:(NSString *)height;

- (BOOL)isXHTML;

@end


#pragma mark -


@protocol SVPlugInContext

- (id <SVHTMLWriter>)HTMLWriter;

// Call so Web Editor knows when to update
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;

// URLs
- (NSString *)relativeURLStringOfPage:(id <SVPage>)page;

// Resources
- (NSURL *)addResourceWithURL:(NSURL *)fileURL;
- (void)addCSSWithURL:(NSURL *)cssURL;

- (BOOL)isForEditing; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)isForPublishing;
- (BOOL)liveDataFeeds;

// Call if your plug-in supports only particular HTML doc types. Otherwise, leave along! Calling mid-write may have no immediate effect; instead the system will try another write after applying the limit.
- (void)limitToMaxDocType:(KTDocType)docType;

- (id <SVPage>)page;

@end


#pragma mark -


@protocol SVPageletPlugInContainer <NSObject>

@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL showsTitle;

@property(nonatomic) BOOL showsIntroduction;
@property(nonatomic) BOOL showsCaption;

@property(nonatomic, getter=isBordered) BOOL bordered;

#pragma mark Undo Management    // don't have direct access to undo manager
- (void)disableUndoRegistration;
- (void)enableUndoRegistration;

@end


#pragma mark -


/*  NSPasteboardReadingOptions specify how data is read from the pasteboard.  You can specify only one option from this list.  If you do not specify an option, the default NSPasteboardReadingAsData is used.  The first three options specify how and if pasteboard data should be pre-processed by the pasteboard before being passed to -initWithPasteboardPropertyList:ofType.  The fourth option, NSPasteboardReadingAsKeyedArchive, should be used when the data on the pasteboard is a keyed archive of this class.  Using this option, a keyed unarchiver will be used and -initWithCoder: will be called to initialize the new instance. 
 */
enum {
    SVPlugInPasteboardReadingAsData 		= 0,	  // Reads data from the pasteboard as-is and returns it as an NSData
    SVPlugInPasteboardReadingAsString 	= 1 << 0, // Reads data from the pasteboard and converts it to an NSString
    SVPlugInPasteboardReadingAsPropertyList 	= 1 << 1, // Reads data from the pasteboard and un-serializes it as a property list
                                                          //SVPlugInPasteboardReadingAsKeyedArchive 	= 1 << 2, // Reads data from the pasteboard and uses initWithCoder: to create the object
    SVPlugInPasteboardReadingAsWebLocation = 1 << 31,
};
typedef NSUInteger SVPlugInPasteboardReadingOptions;


@protocol SVPlugInPasteboardReading <NSObject>
// See SVPlugInPasteboardReading for full details. Sandvox doesn't support +readingOptionsForType:pasteboard: yet
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
+ (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard;
+ (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type;
- (void)awakeFromPasteboardContents:(id)pasteboardContents ofType:(NSString *)type;
@end


#pragma mark -


@protocol SVIndexPlugIn <SVPlugIn>
// We need an API! In the meantime, the protocol declaration serves as a placeholder for the registration system.
@end

