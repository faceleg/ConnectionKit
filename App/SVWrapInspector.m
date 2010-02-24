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
    }
    @catch (NSException *exception)
    {
        if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        
        [oWrapLeftButton setState:NSOffState];
        [oWrapRightButton setState:NSOffState];
        [oWrapLeftSplitButton setState:NSOffState];
        [oWrapCenterButton setState:NSOffState];
        [oWrapRightSplitButton setState:NSOffState];
    }
}

@end
