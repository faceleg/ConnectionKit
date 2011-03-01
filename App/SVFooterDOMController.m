//
//  SVFooterDOMController.m
//  Sandvox
//
//  Created by Mike on 01/03/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVFooterDOMController.h"


@implementation SVFooterDOMController

@end



#pragma mark -


@implementation SVFooter (SVFooterDOMController)

- (SVTextDOMController *)newTextDOMController;
{
    SVTextDOMController *result = [[SVFooterDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    [result setFieldEditor:YES];
    [(id)result setImportsGraphics:YES];
    return result;
}

@end
