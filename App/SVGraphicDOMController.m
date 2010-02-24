//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"

#import "SVBodyTextDOMController.h"
#import "SVWebEditorView.h"


@implementation SVGraphicDOMController

- (SVBodyTextDOMController *)enclosingBodyTextDOMController;
{
    id result = [self parentWebEditorItem];
    while (result && ![result isKindOfClass:[SVBodyTextDOMController class]])
    {
        result = [result parentWebEditorItem];
    }
    return result;
}

- (IBAction)placeBlockLevel:(id)sender;    // tells all selected graphics to become placed as block
{
    SVBodyTextDOMController *bodyController = [self enclosingBodyTextDOMController];
    
    
    SVWebEditorView *webEditor = [self webEditor];
    [webEditor willChange];
    
    
    // Seek out the paragraph nearest myself. Place my HTML element before/after there
    DOMNode *refNode = [self HTMLElement];
    DOMNode *parentNode = [refNode parentNode];
    while (parentNode != [bodyController HTMLElement])
    {
        refNode = parentNode;
        parentNode = [parentNode parentNode];
    }
    
    [parentNode insertBefore:[self HTMLElement] refChild:refNode];
    [[self webEditorViewController] setNeedsUpdate];
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:[webEditor webView]];
}

@end
