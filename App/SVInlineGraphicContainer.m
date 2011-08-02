//
//  SVInlineGraphicContainer.m
//  Sandvox
//
//  Created by Mike on 18/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//


#import "SVGraphicContainer.h"

#import "SVGraphicContainerDOMController.h"


@implementation SVInlineGraphicContainer

- (id)initWithGraphic:(id <SVGraphic>)graphic;
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

@synthesize graphic = _graphic;

- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;
{
    // Graphic body
    OBASSERT(![_graphic isPagelet]);
    [context beginGraphicContainer:graphic];
    [context startElement:@"div"]; // <div class="graphic">
    {
        [context pushClassName:@"figure-content"];  // identifies for #84956
        [graphic writeHTML:context];
    }
    [context endElement];
    [context endGraphicContainer];
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;
{
    SVDOMController *result = [[SVGraphicContainerDOMController alloc] initWithIdName:elementID ancestorNode:node];
    [result setRepresentedObject:self];
    return result;
}

@end
