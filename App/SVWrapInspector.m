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
        
        [oWrapFloatLeftButton setState:[wraps containsObject:SVContentObjectWrapFloatLeft]];
        [oWrapFloatRightButton setState:[wraps containsObject:SVContentObjectWrapFloatRight]];
        [oWrapLeftButton setState:[wraps containsObject:SVContentObjectWrapBlockLeft]];
        [oWrapCenterButton setState:[wraps containsObject:SVContentObjectWrapBlockCenter]];
        [oWrapRightButton setState:[wraps containsObject:SVContentObjectWrapBlockRight]];
        
        [oWrapFloatLeftButton setEnabled:YES];
        [oWrapFloatRightButton setEnabled:YES];
        [oWrapLeftButton setEnabled:YES];
        [oWrapCenterButton setEnabled:YES];
        [oWrapRightButton setEnabled:YES];
    }
    @catch (NSException *exception)
    {
        if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        
        [oWrapFloatLeftButton setState:NSOffState];
        [oWrapFloatRightButton setState:NSOffState];
        [oWrapLeftButton setState:NSOffState];
        [oWrapCenterButton setState:NSOffState];
        [oWrapRightButton setState:NSOffState];
        
        [oWrapFloatLeftButton setEnabled:NO];
        [oWrapFloatRightButton setEnabled:NO];
        [oWrapLeftButton setEnabled:NO];
        [oWrapCenterButton setEnabled:NO];
        [oWrapRightButton setEnabled:NO];
    }
}

@end
