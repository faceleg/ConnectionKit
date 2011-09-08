//
//  SVWebEditorView.m
//  Sandvox
//
//  Created by Mike on 14/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"

#import "SVGraphicContainerDOMController.h"
#import "WEKWebEditorItem.h"


@implementation SVWebEditorView

- (id)initWithFrame:(NSRect)frameRect;
{
    self = [super initWithFrame:frameRect];
    
    // Adjust user agent to feature version number so that Google's +1 badge loads properly!
    NSString *agent = [[self webView] userAgentForURL:[NSURL URLWithString:@"http://google.com/"]]; 
    agent = [agent stringByAppendingFormat:@" Version/%@ Sandvox", [NSApplication marketingVersion]];
    [[self webView] setCustomUserAgent:agent];
    
    return self;
}

- (BOOL)dragSelectionWithEvent:(NSEvent *)event offset:(NSSize)mouseOffset slideBack:(BOOL)slideBack;
{
    // Try to get a controller to move the selection
    WEKWebEditorItem *dragged = [self firstResponderItem];
    id anItem = [dragged parentWebEditorItem];
    
    while (anItem)
    {
        if ([anItem respondsToSelector:@selector(dragItem:withEvent:offset:slideBack:)])
        {
            @try
            {
                return [anItem dragItem:dragged withEvent:event offset:mouseOffset slideBack:slideBack];
            }
            @finally
            {
                [self setXGuide:nil yGuide:nil];
            }            
        }
        
        anItem = [anItem parentWebEditorItem];
    }
    
    return NO;
}

@end
