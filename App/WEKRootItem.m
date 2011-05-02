//
//  WEKRootItem.m
//  Sandvox
//
//  Created by Mike on 15/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "WEKRootItem.h"


@implementation WEKRootItem

- (DOMHTMLElement *)HTMLElement { return nil; }

@synthesize webEditor = _webEditor;

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;
{
    //  We don't have an HTML element, so need special implementation
    
    OBPRECONDITION(node);
    
    WEKWebEditorItem *result = nil;
    
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        result = [anItem hitTestDOMNode:node];
        if (result) break;
    }
    
    return result;
}

/*  Route events back to the web editor since no item handled it
 */
- (void)mouseDown:(NSEvent *)theEvent;
{
    [[self webEditor] performSelector:@selector(mouseDown2:) withObject:theEvent];
}

@end



