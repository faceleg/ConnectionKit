//
//  SVMediaDOMController.h
//  Sandvox
//
//  Created by Mike on 18/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVResizableDOMController.h"
#import "SVPageletDOMController.h"

#import "SVMediaGraphic.h"


@interface SVMediaDOMController : SVResizableDOMController
{
@private
    BOOL    _drawAsDropTarget;
}

- (BOOL)isMediaPlaceholder;

@end


#pragma mark -


@interface SVMediaGraphicDOMController : SVPageletDOMController
@end
