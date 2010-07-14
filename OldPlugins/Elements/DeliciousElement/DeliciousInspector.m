//
//  DeliciousInspector.m
//  DeliciousElement
//
//  Created by Dan Wood on 3/3/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "DeliciousInspector.h"
#import "DeliciousPlugin.h"


@implementation DeliciousInspector

- (IBAction) openDelicious:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://delicious.com/"]];
}

@end
