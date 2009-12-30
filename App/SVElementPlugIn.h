//
//  SVContentPlugIn.h
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVElementPlugIn;
@protocol SVElementPlugInFactory
+ (SVElementPlugIn *)elementPlugInWithArguments:(NSDictionary *)propertyStorage;
@end


#pragma mark -


@class KTMediaManager, KTPage;
@protocol SVElementPlugInContainer;


@interface SVElementPlugIn : NSObject <SVElementPlugInFactory>
{
  @private
    id <SVElementPlugInContainer>   _container;
    
    id  _delegateOwner;
}

- (id)initWithArguments:(NSDictionary *)storage;


// Default implementation generates a <span> or <div> (with an appropriate id) that cotnains the result of -innerHTMLString. There is generally NO NEED to override this, and if you do, you MUST return HTML with an enclosing element of the specified ID.
- (NSString *)HTMLString;
@property(nonatomic, readonly) NSString *elementID;

// Default implementation parses the template specified in Info.plist
- (NSString *)innerHTMLString;


#pragma mark Storage

/*
 Returns the list of KVC keys representing the internal settings of the plug-in. At the moment you must override it in all plug-ins that have some kind of storage, but at some point I'd like to make it automatically read the list in from bundle's Info.plist.
 This list of keys is used for automatic serialization of these internal settings.
 */
+ (NSSet *)plugInKeys;

/*
 Override these methods if the plug-in needs to handle internal settings of an unusual type (typically if the result of -valueForKey: does not conform to the <NSCoding> protocol).
 The serialized object must be a non-container Plist compliant object i.e. exclusively NSString, NSNumber, NSDate, NSData.
 The default implementation of -serializedValueForKey: calls -valueForKey: to retrieve the value for the key, then does nothing for NSString, NSNumber, NSDate and uses <NSCoding> encoding for others.
 The default implementation of -setSerializedValue:forKey calls -setValue:forKey: after decoding the serialized value if necessary.
 */
- (id)serializedValueForKey:(NSString *)key;
- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key;


#pragma mark UI

// If your plug-in wants an inspector, override to return an SVInspectorViewController subclass. Default implementation returns nil.
+ (Class)inspectorViewControllerClass;

// Return a subclass of SVDOMController. Default implementation returns SVDOMController.
+ (Class)DOMControllerClass;


#pragma mark Registration
// Plug-ins normally get registered automatically from searching the bundles, but you could perhaps register additional classes manually
//+ (void)registerClass:(Class)plugInClass;


#pragma mark Other

@property(nonatomic, retain, readonly) id <SVElementPlugInContainer> elementPlugInContainer;

// Convenience method to return the bundle this class was loaded from
@property(nonatomic, readonly) NSBundle *bundle;


// Legacy I'd like to get rid of
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
@property(nonatomic, readonly) KTMediaManager *mediaManager;

@end
