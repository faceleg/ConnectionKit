//
//  KTCodeInjection.m
//  Marvel
//
//  Created by Mike on 15/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTCodeInjection.h"


@implementation KTCodeInjection

+ (void)initialize
{
	// Site Outline
	[self setKeys:[NSArray arrayWithObjects:@"beforeHTML",
                   @"bodyTag",
                   @"bodyTagEnd",
                   @"bodyTagStart",
                   @"earlyHead",
                   @"headArea", nil]
        triggerChangeNotificationsForDependentKey:@"hasCodeInjection"];
}

/*  Returns YES if any of the injection fields have been filled out
 */
- (BOOL)hasCodeInjection
{
	NSString *aCodeInjection;
	
	aCodeInjection = [self valueForKey:@"beforeHTML"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"bodyTag"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"bodyTagEnd"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"bodyTagStart"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"earlyHead"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	aCodeInjection = [self valueForKey:@"headArea"];
	if (aCodeInjection && ![aCodeInjection isEqualToString:@""]) return YES;
	
	return NO;
}

@end
