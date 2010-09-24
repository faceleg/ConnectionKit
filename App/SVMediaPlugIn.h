//
//  SVMediaPlugIn.h
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPlugIn.h"

#import "SVMediaGraphic.h"


@interface SVMediaPlugIn : SVPlugIn

- (BOOL)validateTypeToPublish:(NSString **)type error:(NSError **)errror;

- (CGSize)originalSize;

- (BOOL)shouldWriteHTMLInline;

@end


@interface SVMediaPlugIn (Inherited)
@property(nonatomic, readonly) SVMediaGraphic *container;
@end
