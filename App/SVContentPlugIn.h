//
//  SVContentPlugIn.h
//  Sandvox
//
//  Created by Mike on 20/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTMediaManager, KTPage;


@interface SVContentPlugIn : NSObject
{
  @private
    id  _delegateOwner;
}

// Default implementation generates a <span> or <div> (with an appropriate id) that cotnains the result of -innerHTMLString.
- (NSString *)HTMLString;
@property(nonatomic, readonly) NSString *elementID;

// Default implementation parses the template specified in Info.plist
- (NSString *)innerHTMLString;

// Convenience method to return the bundle this class was loaded from
@property(nonatomic, readonly) NSBundle *bundle;


// Legacy I'd like to get rid of
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
@property(nonatomic, retain) id delegateOwner;
@property(nonatomic, readonly) KTMediaManager *mediaManager;
@property(nonatomic, readonly) KTPage *page;

@end
