//
//  SVCallout.m
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVCallout.h"

#import "SVGraphic.h"
#import "SVWebEditorHTMLContext.h"


@implementation SVCallout

- (void)write:(SVHTMLContext *)context pagelets:(NSArray *)pagelets;
{
    [context beginGraphicContainer:self];
    
    // Write the opening tags
    [context startElement:@"div"
                   idName:[[context currentDOMController] elementIdName]
                className:@"callout-container"];
    
    [context startElement:@"div" className:@"callout"];
    
    [context startElement:@"div" className:@"callout-content"];
    
    
    
    [context writeGraphics:pagelets];    
    
    
    
    [context endElement]; // callout-content
    [context endElement]; // callout
    [context endElement]; // callout-container
    
    
    [context endGraphicContainer];
}

- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;
{
    [SVGraphic write:context pagelet:graphic];
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID;
{
    SVDOMController *result = [self newDOMController];
    [result setElementIdName:elementID includeWhenPublishing:YES];
    return result;
}

@end
