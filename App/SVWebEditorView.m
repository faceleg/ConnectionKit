//
//  SVWebEditorView.m
//  Sandvox
//
//  Created by Mike on 14/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"

#import "WEKWebEditorItem.h"


@implementation SVWebEditorView

- (BOOL)dragSelectionWithEvent:(NSEvent *)event offset:(NSSize)mouseOffset slideBack:(BOOL)slideBack;
{
    // Try to get a controller to move the selection
    id anItem = [self firstResponderItem];
    while (anItem)
    {
        if ([anItem respondsToSelector:_cmd])
        {
            return [anItem dragSelectionWithEvent:event offset:mouseOffset slideBack:slideBack];
        }
        
        anItem = [anItem parentWebEditorItem];
    }
    
    return NO;
}

@end
