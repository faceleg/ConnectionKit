//
//  SVImageDOMController.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVMediaDOMController.h"
#import "SVGraphicDOMController.h"
#import "SVImage.h"
#import "SVMediaGraphic.h"


@interface SVImageDOMController : SVSizeBindingDOMController    // should descend from SVMediaDOMController when I get time
{
  @private
    BOOL    _drawAsDropTarget;
}

- (BOOL)isMediaPlaceholder;

@end


#pragma mark -


@interface SVImagePageletDOMController : SVGraphicDOMController
{  
  @private
    SVImageDOMController    *_imageDOMController;
}

@property(nonatomic, retain) SVImageDOMController *imageDOMController;

@end
