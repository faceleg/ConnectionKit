//
//  SVDocWebEditorView.m
//  Sandvox
//
//  Created by Mike on 29/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDocWebEditorView.h"
#import "SVWebViewController.h"

#import "SVWebEditorItem.h"

#import "DOMNode+Karelia.h"


@implementation SVDocWebEditorView

- (NSDragOperation)validateDrop:(id <NSDraggingInfo>)dragInfo proposedOperation:(NSDragOperation)op;
{
    NSDragOperation result = [super validateDrop:dragInfo proposedOperation:op];
    
    // Drags are generally fine unless they fall in the drop zone between pagelets.
    SVWebViewController *controller = (SVWebViewController *)[self dataSource];
    NSArray *pagelets = [controller contentItems];
    
    NSUInteger i, count = [pagelets count] - 1;
    for (i = 0; i < count; i++)
    {
        SVWebEditorItem *item1 = [pagelets objectAtIndex:i];
        SVWebEditorItem *item2 = [pagelets objectAtIndex:i+1];
        
        NSRect aDropZone = [self rectOfDragCaretAfterDOMNode:[item1 DOMElement]
                                               beforeDOMNode:[item2 DOMElement]
                                                 minimumSize:25.0f];;
        
        if ([self mouse:[self convertPointFromBase:[dragInfo draggingLocation]]
                 inRect:aDropZone])
        {
            result = NSDragOperationMove;
            [self moveDragCaretToAfterDOMNode:[item1 DOMElement] beforeDOMNode:[item2 DOMElement]];
            break;
        }
    }
    
    
    return result;
}

@end
