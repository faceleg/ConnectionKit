//
//  SVPlugInGraphic.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"
#import "SVMediaProtocol.h"
#import "SVPlugIn.h"


@class KTElementPlugInWrapper;


@interface SVPlugInGraphic : SVGraphic <SVMedia>
{
  @private
    SVPlugIn *_plugIn;
}

// Creates both graphic and plug-in at same time, but does not send -awakeFromNew to the plug-in
+ (SVPlugInGraphic *)insertNewGraphicWithPlugInIdentifier:(NSString *)identifier
                                   inManagedObjectContext:(NSManagedObjectContext *)context;

// When pulling content off the pasteboard, the plug-in is already created and populated by the pasteboard. Use this method to create a graphic object to host it
+ (SVPlugInGraphic *)insertNewGraphicWithPlugIn:(SVPlugIn *)plugIn
                         inManagedObjectContext:(NSManagedObjectContext *)context;


@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
@property(nonatomic, retain, readonly) SVPlugIn *plugIn;
- (void)loadPlugInAsNew:(BOOL)inserted;


#pragma mark Metrics
- (NSUInteger)minWidth;
- (NSUInteger)minHeight;
@property(nonatomic, readonly) BOOL constrainProportions;
- (BOOL)isConstrainProportionsEditable;

@end
