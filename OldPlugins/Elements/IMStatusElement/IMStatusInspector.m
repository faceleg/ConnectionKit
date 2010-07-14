//
//  IMStatusInspector.m
//  IMStatusElement
//
//  Created by Dan Wood on 3/3/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "IMStatusInspector.h"
#import "IMStatusPlugin.h"


@implementation IMStatusInspector


- (NSString *)nibName { return @"IMStatusPagelet"; }

+ (void) initialize
{
	// Value transformers
	NSValueTransformer *valueTransformer;
	valueTransformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:IMServiceIChat]];
	[NSValueTransformer setValueTransformer:valueTransformer forName:@"IMStatusPageletServiceIsIChat"];
	[valueTransformer release];
}





@end
