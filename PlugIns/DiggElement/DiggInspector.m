//
//  DiggInspector.m
//  DiggElement
//
//  Created by Terrence Talbot on 4/9/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "DiggInspector.h"


@implementation DiggInspector

- (IBAction)openDigg:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.digg.com/"]];
}

@end
