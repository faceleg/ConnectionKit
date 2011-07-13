//
//  KTApplication.m
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Override methods to clean up when we exit

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Subclass NSApplication

IMPLEMENTATION NOTES & CAUTIONS:
	x

 */


#import "KTApplication.h"


NSString *KTApplicationDidSendFlagsChangedEvent = @"KTApplicationDidSendFlagsChangedEvent";


@implementation KTApplication

- (void)reportException:(NSException *)theException;
{
    // Go through usual report
    [super reportException:theException];
    
#ifndef DEBUG
    // Then terminate since the exception really shoudln't have happened, and has a tendency to mess up saving; it's better for them to go back to autosaved doc
    exit(0);
#endif
}

- (void)sendEvent:(NSEvent *)theEvent
{
    [super sendEvent:theEvent];
    
    if ([theEvent type] == NSFlagsChanged)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:KTApplicationDidSendFlagsChangedEvent object:self];
    }
}

@end

