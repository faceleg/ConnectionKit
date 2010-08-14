//
//  SVImageDOMController.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVSizeBindingDOMController.h"
#import "SVGraphicDOMController.h"
#import "SVImage.h"


@interface SVImageDOMController : SVSizeBindingDOMController
@end


#pragma mark -


@interface SVImagePageletDOMController : SVGraphicDOMController
{  
  @private
    SVImageDOMController    *_imageDOMController;
}

@property(nonatomic, retain) SVImageDOMController *imageDOMController;

@end
