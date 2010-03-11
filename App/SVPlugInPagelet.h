//
//  SVPlugInContentObject.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"


@class SVPageletPlugIn, KTElementPlugin;


@interface SVPlugInPagelet : SVIntroAndCaptionGraphic
{
  @private
    SVPageletPlugIn *_plugIn;
}


- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;

@property(nonatomic, retain, readonly) SVPageletPlugIn *plugIn;
@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (KTElementPlugin *)plugin;



@end
