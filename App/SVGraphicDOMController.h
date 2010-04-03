//
//  SVGraphicDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@class SVRichTextDOMController;


@interface SVGraphicDOMController : SVDOMController

- (SVRichTextDOMController *)enclosingBodyTextDOMController;

@end
