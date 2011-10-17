//
//  SVCallout.m
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVCallout.h"

#import "SVCalloutDOMController.h"
#import "SVGraphic.h"
#import "SVWebEditorHTMLContext.h"


@implementation SVCallout

#pragma mark Lifecycle

- (void)dealloc;
{
    [_pagelets release];
    [super dealloc];
}

@synthesize pagelets = _pagelets;

#pragma mark Writing

- (void)writeHTML:(SVHTMLContext *)context;
{
    // register before callout begins
    for (SVGraphic *aGraphic in [self pagelets])
    {
        [context addDependencyForKeyPath:@"textAttachment.placement" ofObject:aGraphic];
    }
    
    
    [context beginGraphicContainer:self];
    
    // Write the opening tags
    [context startElement:@"div" className:@"callout-container"];
    [context startElement:@"div" className:@"callout"];
    [context startElement:@"div" className:@"callout-content"];
    
    
    
    [context writeGraphics:[self pagelets]];    
    
    
    
    [context endElement]; // callout-content
    [context endElement]; // callout
    [context endElement]; // callout-container
    
    
    [context endGraphicContainer];
}

- (BOOL)HTMLContext:(SVHTMLContext *)context writeGraphic:(SVGraphic *)graphic;
{
    [SVGraphic write:context pagelet:graphic];
    return YES;
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;
{
    SVDOMController *result = [[SVCalloutDOMController alloc] initWithIdName:elementID
                                                                ancestorNode:node];
    
    [result setRepresentedObject:self];
    return result;
}

@end
