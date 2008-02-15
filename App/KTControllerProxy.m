//
//  KTControllerProxy.m
//  Marvel
//
//  Created by Mike on 15/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTControllerProxy.h"


@implementation KTControllerProxy

/*	We hijack NSObjectController's default -setContent and -selection behavior in order to act as a simple proxy for another controller.
 */
- (void)setContent:(id)anObject
{
	[self willChangeValueForKey:@"selection"];
	[super setContent:anObject];
	[self didChangeValueForKey:@"selection"];
}

- (id)selection { return [self content]; }

@end
