//
//  SVContentPlugIn.h
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPlugIn.h"


@protocol SVPage, SVPageletPlugInContainer;


@interface SVPageletPlugIn : NSObject <SVPageletPlugIn, SVPageletPlugInFactory>
{
  @private
    id <SVPageletPlugInContainer>   _container;
    
    id  _delegateOwner;
}

#pragma mark Initialization
// Designated initializer. Called by +newPlugInWithArguments:
- (id)initWithArguments:(NSDictionary *)storage;

//  Default implementation retrieves KTPluginInitialProperties from the bundle and calls -setSerializedValue:forKey: with them
- (void)awakeFromInsertIntoPage:(id <SVPage>)page;


#pragma mark Storage
/*
 Override these methods if the plug-in needs to handle internal settings of an unusual type (typically if the result of -valueForKey: does not conform to the <NSCoding> protocol).
 The default implementation of -serializedValueForKey: calls -valueForKey: to retrieve the value for the key, then does nothing for NSString, NSNumber, NSDate and uses <NSCoding> encoding for others.
 The default implementation of -setSerializedValue:forKey calls -setValue:forKey: after decoding the serialized value if necessary.
 */
- (id)serializedValueForKey:(NSString *)key;
- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;
//  SEE SVPlugIn.h FOR MORE DETAILS


#pragma mark HTML

// Default implementation generates a <span> or <div> (with an appropriate id) that contains the result of -writeInnerHTML. There is generally NO NEED to override this, and if you do, you MUST write HTML with an enclosing element of the specified ID.
- (void)writeHTML:(SVHTMLContext *)context;
@property(nonatomic, readonly) NSString *elementID;

// Default implementation parses the template specified in Info.plist
- (void)writeInnerHTML:(SVHTMLContext *)context;


#pragma mark The Wider World
@property(nonatomic, readonly) NSBundle *bundle;    // the object representing the plug-in's bundle


#pragma mark Undo Management
// TODO: Should these be methods on some kind of SVPlugInHost or SVPlugInManager object?
- (void)disableUndoRegistration;
- (void)enableUndoRegistration;


#pragma mark UI

// If your plug-in wants an inspector, override to return an SVInspectorViewController subclass. Default implementation returns nil.
+ (Class)inspectorViewControllerClass;

// Return a subclass of SVDOMController. Default implementation returns SVDOMController.
+ (Class)DOMControllerClass;


#pragma mark Registration
// Plug-ins normally get registered automatically from searching the bundles, but you could perhaps register additional classes manually
//+ (void)registerClass:(Class)plugInClass;


#pragma mark Other
@property(nonatomic, retain, readonly) id <SVPageletPlugInContainer> elementPlugInContainer;


#pragma mark Pasteboard
// Default implementation returns result of +supportedPasteboardTypesForCreatingPagelet: (if receiver confroms to KTDataSource) for backward compatibility.
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;


#pragma mark Legacy

// Called by -awakeFromInsert:... and -awakeFromFetch: for backward compatibility
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
// Called by -awakeFromInsert:... when there is a pasteboard for backward compatibility
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary;

@end
