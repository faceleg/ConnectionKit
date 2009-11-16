//
//  SVPlugInContentObject.h
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"


@interface SVPlugInContentObject : SVContentObject

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;

@property(nonatomic, retain, readonly) id <SVElementPlugIn> plugIn;
@property(nonatomic, copy, readonly) NSString *plugInIdentifier;
- (KTElementPlugin *)plugin;

@end
