//
//  KTNoCascadePanel.m
//  Marvel
//
//  Created by Terrence Talbot on 4/14/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTNoCascadePanel.h"


@implementation KTNoCascadePanel

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
