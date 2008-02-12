//
//  ContactElementInspectorController.m
//  ContactElement
//
//  Created by Mike on 11/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ContactElementInspectorController.h"

#import <NSImage+KTExtensions.h>
#import <NTBoxView.h>
#import <ValuesAreEqualTransformer.h>


@implementation ContactElementInspectorController

+ (void)initialize
{
	// Register value transformers
	ValuesAreEqualTransformer *transformer = nil;
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:@"email"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotEmail"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:@"visitorName"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotName"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:@"subject"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotSubject"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:@"message"];
	[NSValueTransformer setValueTransformer:transformer forName:@"ContactElementFieldIsNotMessage"];
	[transformer setNegatesResult:YES];
	[transformer release];
	
	transformer = [[ValuesAreEqualTransformer alloc] initWithComparisonValue:@"send"];
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
