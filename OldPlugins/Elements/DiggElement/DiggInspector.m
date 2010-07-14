//
//  DiggInspector.m
//  DiggElement
//
//  Created by Terrence Talbot on 5/4/10.
//  Copyright 2010 Terrence Talbot. All rights reserved.
//

#import "DiggInspector.h"


@implementation DiggInspector

#pragma mark -
#pragma mark Actions

- (IBAction)openDigg:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.digg.com/"]];
}

@end
