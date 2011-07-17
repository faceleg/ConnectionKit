//
//  SVPagelet.m
//  Sandvox
//
//  Created by Mike on 14/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPagelet.h"

#import "SVGraphicContainerDOMController.h"


@implementation SVPagelet

- (id)initWithGraphic:(SVGraphic *)graphic;
{
    if (self = [self init])
    {
        _graphic = [graphic retain];
    }
    return self;
}

- (void)dealloc;
{
    [_graphic release];
    [super dealloc];
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID document:(DOMHTMLDocument *)document;
{
    SVDOMController *result = [[SVGraphicContainerDOMController alloc] initWithElementIdName:elementID document:document];
    [result setRepresentedObject:self];
    return result;
}


@end
