//
//  NSScanner+KTComponents.m
//  KTComponents
//
//  Created by Dan Wood on 4/13/07.
//  Copyright (c) 2007 Karelia Software. All rights reserved.
//

#import "NSScanner+KTComponents.h"


@implementation NSScanner ( KTComponents )

//
//  Created by Uli Kusterer on Sat Dec 13 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

-(BOOL) skipUpToCharactersFromSet:(NSCharacterSet*)set
{
	NSString*		vString = [self string];
	int				x = [self scanLocation];
	
	while( x < [vString length] )
	{
		if( ![set characterIsMember: [vString characterAtIndex: x]] )
			x++;
		else
			break;
	}
	
	if( x > [self scanLocation] )
	{
		[self setScanLocation: x];
		return YES;
	}
	else
		return NO;
}

@end

