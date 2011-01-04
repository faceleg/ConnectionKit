//
//  SVMediaDOMController.h
//  Sandvox
//
//  Created by Mike on 18/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVSizeBindingDOMController.h"
#import "SVGraphicDOMController.h"

#import "SVMediaGraphic.h"


@interface SVMediaDOMController : SVSizeBindingDOMController
{
@private
    BOOL    _drawAsDropTarget;
}

- (BOOL)isMediaPlaceholder;

@end


#pragma mark -


@interface SVMediaGraphicDOMController : SVGraphicDOMController
@end
