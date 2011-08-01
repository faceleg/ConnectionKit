//
//  SVGraphicDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVAuxiliaryPageletText.h"
#import "SVGraphic.h"

#import "SVOffscreenWebViewController.h"


// And provide a base implementation of the protocol:
@interface SVGraphic (SVDOMController)
- (BOOL)requiresPageLoad;
@end

@interface SVAuxiliaryPageletText (SVDOMController)
@end


#pragma mark -


@interface SVGraphicDOMController : SVDOMController
{
  @private
    BOOL    _drawAsDropTarget;
}

@end
