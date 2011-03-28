//
//  SVPlugInGraphic.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  Since plug-ins cannot be actual Core Data objects (that would expose too much power to them, and is pretty much impossible anyway!), SVPlugInGraphic is a special graphic whose job is to host a plug-in instance.
//  A plug-in is created from .plugInIdentifier and matches the lifetime of its hosting object. Many of SVGraphic's methods are then delegated to the plug-in to implement as desired (e.g. HTML generation)


#import "SVGraphic.h"
#import "SVMediaProtocol.h"
#import "SVPlugIn.h"


@class KTElementPlugInWrapper;


@interface SVPlugInGraphic : SVGraphic
{
  @private
    SVPlugIn *_plugIn;
}

// Creates both graphic and plug-in at same time, but does not send -awakeFromNew to the plug-in
+ (SVPlugInGraphic *)insertNewGraphicWithPlugInIdentifier:(NSString *)identifier
                                   inManagedObjectContext:(NSManagedObjectContext *)context;


@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
@property(nonatomic, retain, readonly) SVPlugIn *plugIn;
- (void)loadPlugInAsNew:(BOOL)inserted;


#pragma mark Metrics

@property(nonatomic, copy) NSNumber *contentHeight;

@property(nonatomic) BOOL constrainsProportions;
- (BOOL)isConstrainProportionsEditable;


#pragma mark Indexes
@property(nonatomic, retain) KTPage *indexedCollection;


@end
