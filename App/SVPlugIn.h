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


@class KSHTMLWriter;
@protocol SVPlugInContext, SVPage, SVPageletPlugInContainer;


@protocol SVPlugIn <NSObject>

#pragma mark Managing Life Cycle

// Called once persistent properties have been restored (by Sandvox calling -setSerializedValue:forKey:)
- (void)awakeFromFetch;

// Called for new pagelets. Pasteboard is non-nil if inserting by pasting or drag & drop.
- (void)awakeFromInsertIntoPage:(id <SVPage>)page;

- (void)setContainer:(id <SVPageletPlugInContainer>)container;


#pragma mark Identifier
+ (NSString *)plugInIdentifier; // use standard reverse DNS-style string


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


#pragma mark HTML Generation
- (void)writeHTML:(id <SVPlugInContext>)context;


#pragma mark Thumbnail
- (id <IMBImageItem>)thumbnail;


#pragma mark Pasteboard
// See NSPasteboardReading for full details. Sandvox doesn't support +readingOptionsForType:pasteboard: yet
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
@optional
- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type;


@end


#pragma mark -


@protocol SVPlugInContext

- (KSHTMLWriter *)HTMLWriter;
- (NSURL *)addResourceWithURL:(NSURL *)fileURL;

- (BOOL)isForEditing; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)isForPublishing;

// Call if your plug-in supports only particular HTML doc types. Otherwise, leave along! Calling mid-write may have no immediate effect; instead the system will try another write after applying the limit.
- (void)limitToMaxDocType:(KTDocType)docType;

@end


#pragma mark -


@protocol SVPageletPlugInContainer <NSObject>

@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL showsTitle;

@property(nonatomic) BOOL showsIntroduction;
@property(nonatomic) BOOL showsCaption;

@property(nonatomic, getter=isBordered) BOOL bordered;

@end


#pragma mark -


@protocol SVIndexPlugIn <SVPlugIn>
// We need an API! In the meantime, the protocol declaration serves as a placeholder for the registration system.
@end

