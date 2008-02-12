//
//  NSWindow+KTExtensions.m
//  FeedbackTester
//
//  Created by Terrence Talbot on 9/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSWindow+KTExtensions.h"

#import "NSView+KTExtensions.h"

@implementation NSWindow ( KTExtensions )

- (NSImage *)snapshot
{
	return [[self contentView] snapshot];
}

@end
