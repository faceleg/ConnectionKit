//
//  KTPageDetailsBoxView.m
//  Marvel
//
//  Created by Dan Wood on 2/2/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTPageDetailsBoxView.h"


/*
 top area:151x155 (with x at -1)
 bottom area:150x244
*/

@implementation KTPageDetailsBoxView

/*
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize;
{
	NSLog(@"resizeSubviewsWithOldSize: %@", NSStringFromSize(oldSize));
	
	[super resizeSubviewsWithOldSize:oldSize];
	
}
*/



- (NSString *)maskAsString:(int)mask
{
	if (mask == 0) return @"NotSizable";
	
	NSMutableString *buf = [NSMutableString string];
	if (mask & NSViewMaxYMargin)	[buf appendString:@"MaxY|"];
	if (mask & NSViewHeightSizable) [buf appendString:@"HeightSizable|"];
	if (mask & NSViewMinYMargin)	[buf appendString:@"MinY|"];
	if (mask & NSViewMaxXMargin)	[buf appendString:@"MaxX|"];
	if (mask & NSViewWidthSizable)	[buf appendString:@"WidthSizable|"];
	if (mask & NSViewMinXMargin)	[buf appendString:@"MinX|"];
	if (![buf isEqualToString:@""])	[buf deleteCharactersInRange:NSMakeRange([buf length]-1,1)];
	return buf;
}

/*
 
		NSTextField 1 {{8, 458}, {136, 14}}, MinY|WidthSizable 'Description'			stick to top
| 2px
?		NSTextField 2 {{10, 311}, {130, 144}}, HeightSizable|MinY|WidthSizable ''		resizable according space avaialble
| 2px
11px	NSTextField 3 {{7, 275}, {136, 11}}, MaxY|MinY|MinX '156 remaining'			stick to bottom of above
| 4px
14px	NSTextField 4 {{7, 240}, {136, 14}}, MaxY|MinY|WidthSizable 'Tags'				then Tags
| 2px
???		NSTokenField 5 {{10, 53}, {130, 300}}, HeightSizable|WidthSizable ''			Then this according to how much space we have
| 8px
 
 Then everything else stuck to the bottom
 KSLabel 6 {{8, 31}, {135, 14}}, MaxY|WidthSizable 'File Name'					
 NSTextField 7 {{10, 10}, {104, 19}}, MaxY|WidthSizable ''
 KTCollectionIndexFilenameButton 8 {{112, 8}, {31, 22}}, MaxY|MinX '1'
 KSLabel 9 {{102, 12}, {8, 14}}, MaxY|MinX '.'
 KSPopUpButton 10 {{98, 8}, {45, 22}}, MaxY|MinX '1'
 NSTextField 11 {{10, 10}, {93, 19}}, MaxY|WidthSizable ''
 KSLabel 12 {{108, 12}, {36, 14}}, MaxY|MinX 'html'
 
 
 
 */

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
	NSLog(@"resizeWithOldSuperviewSize: %@", NSStringFromSize(oldBoundsSize));
	[super resizeWithOldSuperviewSize:oldBoundsSize];
	
	NSView *bottommost = [self viewWithTag:6];
	OBASSERT(bottommost);
	int topOfBottommost = NSMaxY([bottommost frame]);
	
	NSView *topmost = [self viewWithTag:1];
	OBASSERT(topmost);
	int bottomOfTopmost = NSMinY([topmost frame]);
	
	int topOfDescField = bottomOfTopmost - 2;
	const int kSpaceBetweenTwoResizableFields = 37;
	int spaceToDivide = topOfDescField - topOfBottommost - kSpaceBetweenTwoResizableFields;
	int sizeOfDescField = spaceToDivide / 2;		// will round down

	NSView *field;
	NSRect frame;
	int newBottom;
	
	// Desc Resizable Field
	newBottom = bottomOfTopmost-sizeOfDescField;
	field = [self viewWithTag:2];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	frame.size.height = sizeOfDescField;
	[field setFrame:frame];
	
//	NSLog(@"desc bindings: %@", [field exposedBindings]);
	NSLog(@"desc value binding: %@", [field infoForBinding:@"value"]);
	
	NSString *descLongMultiple  = NSLocalizedString(@"Optional summaries. (Setting the same text for multiple pages is discouraged.)", @"multiple items selected, long placeholder");
	NSString *descLongNull      = NSLocalizedString(@"Optional summary of page. Used by search engines.", @"null summary available, long placeholder");
	NSString *descShortMultiple = NSLocalizedString(@"Optional summaries", @"multiple items selected, short placeholder");
	NSString *descShortNull     = NSLocalizedString(@"Optional summary", @"null summary available, short placeholder");
	
	NSString *desiredMultiPlaceholder = (sizeOfDescField < (16 * 3) ? descShortMultiple : descLongMultiple);
	NSString *desiredNullPlaceholder  = (sizeOfDescField < (16 * 3) ? descShortNull : descLongNull);
	
	NSDictionary *infoForBinding = [field infoForBinding:NSValueBinding];
	NSDictionary *bindingOptions = [infoForBinding valueForKey:NSOptionsKey];
	NSString *bindingKeyPath = [infoForBinding valueForKey:NSObservedKeyPathKey];
	id observedObject = [infoForBinding valueForKey:NSObservedObjectKey];

	NSLog(@"currentMultipleValuesPlaceholderBindingOption = %@", [bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption]);
	if (![[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] isEqualToString:desiredMultiPlaceholder])
	{
//		NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
//		[newBindingOptions setObject:desiredMultiPlaceholder forKey:NSMultipleValuesPlaceholderBindingOption];
//		[newBindingOptions setObject:desiredNullPlaceholder forKey:NSNullPlaceholderBindingOption];
//		
//		[field unbind:NSContentValuesBinding];
//		[field bind:NSContentValuesBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
	}
	

	// Countdown field
	newBottom = newBottom - 11 - 2;
	field = [self viewWithTag:3];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	[field setFrame:frame];
	
	// Tag label
	newBottom = newBottom - 14 - 4;
	field = [self viewWithTag:4];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	[field setFrame:frame];
	
	// Tags resizable field
	newBottom = topOfBottommost + 8;
	field = [self viewWithTag:5];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	frame.size.height = spaceToDivide - sizeOfDescField;
	[field setFrame:frame];
	
//	NSLog(@"tags bindings: %@", [field exposedBindings]);
	NSLog(@"tags value binding: %@", [field infoForBinding:@"value"]);

	NSString *tagsLongMultiple  = NSLocalizedString(@"Optional words describing these pages, separated by “,”", @"multiple items selected, long placeholder");
	NSString *tagsLongNull      = NSLocalizedString(@"Optional words describing this page, separated by “,”", @"null keywords available, long placeholder");
	NSString *tagsShortMultiple = NSLocalizedString(@"Optional words", @"multiple items selected, short placeholder");
	NSString *tagsShortNull     = NSLocalizedString(@"Optional words", @"null keywords available, short placeholder");
	
	// I should set the null / multiple values placeholder for the tags field....
	// and the multiple values and null value placeholder for the desc field
	// NSMultipleValuesPlaceholderBindingOption
	// NSNullPlaceholderBindingOption
	/*
	 
	 [errorNameFormCell bind:NSValueBinding
	 toObject:lookerUpperObjectController
	 withKeyPath:@"content.errorName"
	 options:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The headers do not define a name for this error.",  @"Error name nil placeholder") forKey:NSNullPlaceholderBindingOption]];

	*/
	
/*	NSArray *subviews = [self subviews];
	NSEnumerator *enumerator = [subviews objectEnumerator];
	NSView *subview;

	while ((subview = [enumerator nextObject]) != nil)
	{
		int autoresizingMask = [subview autoresizingMask];
		NSLog(@"subview = %@ %d %@, %@ '%@'", [subview class], [subview tag], NSStringFromRect([subview frame]), [self maskAsString:autoresizingMask],
			  ([subview respondsToSelector:@selector(stringValue)] ? [subview stringValue] : @"")
		);
	}
*/	
}




@end
