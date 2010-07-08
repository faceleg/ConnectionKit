//
//  SVRawHTMLDOMController.m
//  Sandvox
//
//  Created by Mike on 09/07/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLDOMController.h"


@implementation SVRawHTMLDOMController

@end


#pragma mark -


@implementation SVRawHTMLGraphic (SVRawHTMLDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVRawHTMLDOMController alloc] initWithRepresentedObject:self];
}

@end
