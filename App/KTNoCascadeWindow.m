//
//  KTNoCascadeWindow.m
//  Marvel
//
//  Created by Terrence Talbot on 4/21/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTNoCascadeWindow.h"


@implementation KTNoCascadeWindow

- (NSPoint)cascadeTopLeftFromPoint:(NSPoint)topLeftPoint
{
	NSString *autosaveName = [self frameAutosaveName];
	if ( (nil != autosaveName) && ([autosaveName length] > 0) )
	{
		return topLeftPoint;
	}
	else
	{
		return [super cascadeTopLeftFromPoint:topLeftPoint];
	}
}

@end
