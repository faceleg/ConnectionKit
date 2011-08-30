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

- (BOOL)HTMLContext:(SVHTMLContext *)context writeGraphic:(id <SVGraphic>)graphic;
{
    // Graphic body
    OBASSERT(![_graphic isPagelet]);
    [context beginGraphicContainer:graphic];
    
    if (![graphic isExplicitlySized:context])
    {
        [context buildAttributesForResizableElement:@"div"
                                             object:graphic
                                 DOMControllerClass:nil
                                          sizeDelta:NSZeroSize
                                            options:SVResizingDisableVertically];
    }
    
    [context startElement:@"div"]; // <div class="graphic">
    {
        [context pushClassName:@"figure-content"];  // identifies for #84956
        [graphic writeHTML:context];
    }
    [context endElement];
    [context endGraphicContainer];
    
    return YES;
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;
{
    SVDOMController *result = [[SVGraphicContainerDOMController alloc] initWithIdName:elementID ancestorNode:node];
    [result setRepresentedObject:self];
    return result;
}

@end
