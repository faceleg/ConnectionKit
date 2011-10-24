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
    [context setCurrentHeaderLevel:2];  // HACK to force it for updates. #151617
    {{
        // Graphic body
        OBASSERT(![_graphic isPagelet]);
        [context beginGraphicContainer:graphic];
        {{
            if ([graphic isExplicitlySized:context])
            {
                [context startElement:@"div"]; // <div class="graphic">
            }
            else
            {
                [context startResizableElement:@"div"
                                        object:graphic
                                       options:SVResizingDisableVertically
                                     sizeDelta:NSZeroSize];
            }
            
            {
                [context pushClassName:@"figure-content"];  // identifies for #84956
                [graphic writeHTML:context];
            }
            [context endElement];
        }}
        [context endGraphicContainer];
    }}
    
    
    return YES;
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;
{
    SVDOMController *result = [[SVGraphicContainerDOMController alloc] initWithIdName:elementID ancestorNode:node];
    [result setRepresentedObject:self];
    return result;
}

@end
