//
//  SVPagelet.m
//  Sandvox
//
//  Created by Mike on 14/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPagelet.h"

#import "SVGraphicDOMController.h"


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

- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;
{
    OBASSERT(graphic == _graphic);
    [graphic writeBody:context];
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID
{
    SVDOMController *result = [[SVGraphicDOMController alloc] initWithRepresentedObject:_graphic];
    [result setElementIdName:elementID includeWhenPublishing:YES];
    return result;
}


@end
