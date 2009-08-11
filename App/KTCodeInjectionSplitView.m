//
//  KTCodeInjectionSplitView.m
//  Marvel
//
//  Created by Mike on 20/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTCodeInjectionSplitView.h"

#import "KSVerticallyAlignedTextCell.h"


@interface KTCodeInjectionSplitView ()
+ (NSTextFieldCell *)dividerDescriptionCell;
@end


@implementation KTCodeInjectionSplitView

- (void)dealloc
{
	[myDividerDescription release];
	[super dealloc];
}

- (NSString *)dividerDescription { return myDividerDescription; }

- (void)setDividerDescription:(NSString *)description
{
	description = [description copy];
	[myDividerDescription release];
	myDividerDescription = description;
}

/*	Draw our text in addition to the default divider
 */
- (void)drawDivider:(NSImage *)anImage inRect:(NSRect)rect betweenView:(RBSplitSubview *)leading andView:(RBSplitSubview *)trailing;
{
	[super drawDivider:anImage inRect:rect betweenView:leading andView:trailing];
	
	NSTextFieldCell *descriptionCell = [[self class] dividerDescriptionCell];
	[descriptionCell setStringValue:[self dividerDescription]];
	[descriptionCell drawWithFrame:rect inView:self];
}

+ (NSTextFieldCell *)dividerDescriptionCell
{
	static KSVerticallyAlignedTextCell *result;
	
	if (!result)
	{
		result = [[KSVerticallyAlignedTextCell alloc] initTextCell:@""];
		[result setControlSize:NSSmallControlSize];
		[result setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[result setTextColor:[NSColor darkGrayColor]];
		[result setAlignment:NSLeftTextAlignment];
		[result setBezeled:NO];
		[result setBordered:NO];
		[result setEnabled:YES];
		[result setVerticalAlignment:KSVerticalCenterTextAlignment];
	}
	
	return [[result copy] autorelease];
}

@end
