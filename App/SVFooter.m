//
//  SVFooter.m
//  Sandvox
//
//  Created by Mike on 10/01/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVFooter.h"


@implementation SVFooter

- (SVTextDOMController *)newTextDOMController;
{
    SVTextDOMController *result = [super newTextDOMController];
    [result setFieldEditor:YES];
    [(id)result setImportsGraphics:YES];
    return result;
}

@end