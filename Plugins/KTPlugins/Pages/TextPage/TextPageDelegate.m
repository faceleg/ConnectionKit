//
//  TextPageDelegate.m
//  KTPlugins
//
//  Created by Mike on 31/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "TextPageDelegate.h"


@implementation TextPageDelegate

- (NSString *)summaryHTMLKeyPath
{
	return @"mainElement.richTextHTML";
}

- (BOOL)summaryHTMLIsEditable { return YES; }

@end
