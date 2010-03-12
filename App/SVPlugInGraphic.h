//
//  SVPlugInGraphic.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"


@protocol SVPageletPlugIn;
@class KTElementPlugin;


@interface SVPlugInGraphic : SVIntroAndCaptionGraphic
{
  @private
    NSObject <SVPageletPlugIn> *_plugIn;
}


- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;

@property(nonatomic, retain, readonly) NSObject <SVPageletPlugIn> *plugIn;
@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (KTElementPlugin *)plugin;



@end
