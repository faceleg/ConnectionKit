//
//  ContactElementInspectorController.m
//  ContactElement
//
//  Created by Mike on 11/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ContactElementInspectorController.h"
#import <SandvoxPlugin.h>


@implementation ContactElementInspectorController

+ (void)initialize
{
	// Register value transformers
	KSIsEqualValueTransformer *transformer = nil;
	
// TODO: when we can mess with the nib, just take out this transformer binding.
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:             @"email___"];	// HACK -- "DISABLE" THIS SO EMAIL PLACEHOLDER IS ALWAYS ENABLED.  COMPARISON WILL NEVER SUCCEED.
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotEmail"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"visitorName"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotName"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"subject"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSubject"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"message"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotMessage"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:@"send"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSend"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
}

- (void)awakeFromNib
{
	// Set up the box under the table
	[oFieldsTableButtonsBox setDrawsFrame:YES];
	[oFieldsTableButtonsBox setFill:NTBoxBevel];
	[oFieldsTableButtonsBox setBorderMask:(NTBoxLeft | NTBoxRight | NTBoxBottom)];
	[oFieldsTableButtonsBox setFrameColor:[NSColor lightGrayColor]];
	
	// Give the buttons their icons
	[oAddLinkButton setImage:[NSImage addToTableButtonIcon]];
	[oRemoveLinkButton setImage:[NSImage removeFromTableButtonIcon]];
}

@end
