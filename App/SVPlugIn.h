//
//  SVPlugIn.h
//  Sandvox
//
//  Created by Mike on 29/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <iMedia/IMBImageItem.h>


@class SVPlugIn, SVInspectorViewController;
@protocol SVHTMLWriter, SVPage, SVPageletPlugInContainer;

#pragma mark -


@protocol SVPlugInContext

- (id <SVHTMLWriter>)HTMLWriter;

// Call so Web Editor knows when to update
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;

- (void)writeTitleOfPage:(id <SVPage>)page enclosingElement:(NSString *)element attributes:(NSDictionary *)attributes;

// URLs
- (NSString *)relativeURLStringOfURL:(NSURL *)URL;
- (NSString *)relativeURLStringOfPage:(id <SVPage>)page;

// Resources & Design
- (NSURL *)addResourceWithURL:(NSURL *)fileURL;
- (void)addCSSString:(NSString *)css;
- (void)addCSSWithURL:(NSURL *)cssURL;

// Purpose
- (BOOL)isForEditing; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)isForPublishing;
- (BOOL)liveDataFeeds;
- (BOOL)shouldWriteServerSideScripts;   // YES when -isForPublishing, but not when validating page

- (id <SVPage>)page;

@end


#pragma mark -


@protocol SVHTMLWriter

- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes;
- (void)startElement:(NSString *)tagName;
- (void)startElement:(NSString *)tagName className:(NSString *)className;
- (void)startElement:(NSString *)tagName idName:(NSString *)idName className:(NSString *)className;
- (void)endElement;

- (void)writeText:(NSString *)string;

//  Writes a newline character and the tabs to match -indentationLevel. Nornally newlines are automatically written for you; call this if you need an extra one.
- (void)startNewline;

- (void)writeComment:(NSString *)comment;   // escapes the string, and wraps in a comment tag

- (void)writeHTMLString:(NSString *)html;   // great for when you have an existing snippet of HTML

//  <a href="...." target="..." rel="nofollow">
- (void)startAnchorElementWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;

// The element's size will be taken from plug-in's .width and .height properties. When editing, that will be kept up-to-date, live.
- (void)startElement:(NSString *)elementName
    bindSizeToPlugIn:(SVPlugIn *)plugIn
          attributes:(NSDictionary *)attributes;

- (BOOL)isXHTML;
- (NSStringEncoding)encoding;   // default is UTF-8

@end


#pragma mark -


@protocol SVPageletPlugInContainer <NSObject>

@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL showsTitle;

@property(nonatomic) BOOL showsIntroduction;
@property(nonatomic) BOOL showsCaption;

@property(nonatomic, getter=isBordered) BOOL bordered;

@property(nonatomic, copy) NSNumber *containerWidth;    // switch over to .contentWidth please


#pragma mark Undo Management
// Don't have direct access to undo manager
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

