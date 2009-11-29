//
//  SVPlugInContentObject.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@protocol SVElementPlugIn;


@interface SVPlugInGraphic : SVGraphic
{
  @private
    id  _plugIn;
}


- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;

@property(nonatomic, retain, readonly) id <SVElementPlugIn> plugIn;
@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (KTElementPlugin *)plugin;


@property(nonatomic, copy) SVContentObjectWrap *wrap;
@property(nonatomic, copy) NSNumber *wrapIsFloatOrBlock;    // setter picks best wrap type
@property(nonatomic) BOOL wrapIsFloatLeft;
@property(nonatomic) BOOL wrapIsFloatRight;
@property(nonatomic) BOOL wrapIsBlockLeft;
@property(nonatomic) BOOL wrapIsBlockCenter;
@property(nonatomic) BOOL wrapIsBlockRight;


@end
