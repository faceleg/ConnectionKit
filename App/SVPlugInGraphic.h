//
//  SVPlugInContentObject.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@class SVElementPlugIn;


@interface SVPlugInGraphic : SVGraphic
{
  @private
    SVElementPlugIn *_plugIn;
}


- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;

@property(nonatomic, retain, readonly) SVElementPlugIn *plugIn;
@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (KTElementPlugin *)plugin;



@end
