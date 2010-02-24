//
//  SVWrapInspector.m
//  Sandvox
//
//  Created by Mike on 22/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWrapInspector.h"

#import "SVGraphic.h"


@implementation SVWrapInspector

- (void)refresh;
{
    [super refresh];
    
    @try
    {
        NSArray *wraps = [(NSObject *)[self inspectedObjects] valueForKey:@"wrap"];
        
        [oWrapLeftButton setState:[wraps containsObject:SVContentObjectWrapFloatLeft]];
        [oWrapRightButton setState:[wraps containsObject:SVContentObjectWrapFloatRight]];
        [oWrapLeftSplitButton setState:[wraps containsObject:SVContentObjectWrapBlockLeft]];
        [oWrapCenterButton setState:[wraps containsObject:SVContentObjectWrapBlockCenter]];
        [oWrapRightSplitButton setState:[wraps containsObject:SVContentObjectWrapBlockRight]];
        
        [oWrapLeftButton setEnabled:YES];
        [oWrapRightButton setEnabled:YES];
        [oWrapLeftSplitButton setEnabled:YES];
        [oWrapCenterButton setEnabled:YES];
        [oWrapRightSplitButton setEnabled:YES];
    }
    @catch (NSException *exception)
    {
        if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        
        [oWrapLeftButton setState:NSOffState];
        [oWrapRightButton setState:NSOffState];
        [oWrapLeftSplitButton setState:NSOffState];
        [oWrapCenterButton setState:NSOffState];
        [oWrapRightSplitButton setState:NSOffState];
        
        [oWrapLeftButton setEnabled:NO];
        [oWrapRightButton setEnabled:NO];
        [oWrapLeftSplitButton setEnabled:NO];
        [oWrapCenterButton setEnabled:NO];
        [oWrapRightSplitButton setEnabled:NO];
    }
}

@end
