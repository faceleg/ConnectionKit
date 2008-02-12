//
//  ABPerson+IMStatus.m
//  IMStatusPagelet
//
//  Created by Mike on 25/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "ABPerson+IMStatus.h"


@implementation ABPerson (IMStatus)

- (NSString *)firstAIMUsername;
{
	NSString *result = nil;
	
	ABMultiValue *usernames = [self valueForProperty:kABAIMInstantProperty];
	if (usernames && [usernames count] > 0) {
		result = [usernames valueAtIndex:0];
	}
	
	return result;
}

- (NSString *)firstYahooUsername;
{
	NSString *result = nil;
	
	ABMultiValue *usernames = [self valueForProperty:kABYahooInstantProperty];
	if (usernames && [usernames count] > 0) {
		result = [usernames valueAtIndex:0];
	}
	
	return result;
}

@end
