//
//  SVImageDOMController.h
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"


@interface SVImageDOMController : SVGraphicDOMController
{
}

@end


#pragma mark -


@interface SVImagePageletDOMController : SVGraphicDOMController
{  
  @private
    SVImageDOMController    *_imageDOMController;
}

@property(nonatomic, retain, readonly) SVImageDOMController *imageDOMController;

@end
