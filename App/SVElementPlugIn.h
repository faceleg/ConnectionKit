//
//  SVContentPlugIn.h
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVElementPlugIn <NSObject>

- (NSString *)HTMLString;
@property(nonatomic, readonly) NSString *elementID;

@end


@protocol SVElementPlugInFactory
+ (id <SVElementPlugIn>)elementPlugInWithArguments:(NSDictionary *)propertyStorage;
@end


#pragma mark -


@class KTMediaManager, KTPage;
@protocol SVElementPlugInContainer;


@interface SVElementPlugIn : NSObject <SVElementPlugIn, SVElementPlugInFactory>
{
  @private
    NSMutableDictionary             *_propertiesStorage;
    id <SVElementPlugInContainer>   _container;
    
    id  _delegateOwner;
}

- (id)initWithArguments:(NSDictionary *)storage;


// Default implementation generates a <span> or <div> (with an appropriate id) that cotnains the result of -innerHTMLString. There is generally NO NEED to override this, and if you do, you MUST return HTML with an enclosing element of the specified ID.
- (NSString *)HTMLString;
@property(nonatomic, readonly) NSString *elementID;

// Default implementation parses the template specified in Info.plist
- (NSString *)innerHTMLString;


@property(nonatomic, retain, readonly) NSMutableDictionary *propertiesStorage;
@property(nonatomic, retain, readonly) id <SVElementPlugInContainer> elementPlugInContainer;

// Convenience method to return the bundle this class was loaded from
@property(nonatomic, readonly) NSBundle *bundle;


// Legacy I'd like to get rid of
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
@property(nonatomic, readonly) KTMediaManager *mediaManager;

@end
