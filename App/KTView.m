//
//  KTView.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/4/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTView.h"


@implementation KTView

- (void)awakeFromNib
{
	myMinimumSize = [self bounds].size;
}

- (NSSize)minimumSize
{
	return myMinimumSize;
}

- (float)minimumWidth
{
	return myMinimumSize.width;
}

- (float)minimumHeight
{
	return myMinimumSize.height;
}

@end
