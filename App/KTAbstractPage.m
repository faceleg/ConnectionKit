//
//  KTAbstractPage.m
//  Marvel
//
//  Created by Mike on 28/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTAbstractPage.h"

#import "NSManagedObject+KTExtensions.h"


@implementation KTAbstractPage

+ (NSString *)extensiblePropertiesDataKey { return nil; }

- (KTPage *)parent { return [self wrappedValueForKey:@"parent"]; }

/*	Only KTPages can be collections
 */
- (BOOL)isCollection { return NO; }

- (BOOL)isRoot
{
	BOOL result = ((id)self == [self root]);
	return result;
}

@end
