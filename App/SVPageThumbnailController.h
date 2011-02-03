//
//  SVPageThumbnailController.h
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVFillController.h"


@interface SVPageThumbnailController : SVFillController
{

}

@property(nonatomic, readonly) BOOL fillTypeIsImage;

@end


#pragma mark -


@interface SVFillTypeFromThumbnailType : NSValueTransformer
@end