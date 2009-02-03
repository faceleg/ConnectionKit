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
//	NSLog(@"resizeWithOldSuperviewSize: %@", NSStringFromSize(oldBoundsSize));
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
	
	
}

- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	
	// Redo placeholder text for the summary field
	
	NSView *field = [self viewWithTag:2];
	OBASSERT(field);
	NSRect frame = [field frame];
	int sizeOfField = frame.size.height;
		
	NSString *longMultiple  = NSLocalizedString(@"Optional summaries. (Setting the same text for multiple pages is discouraged.)", @"multiple items selected, long placeholder");
	NSString *longNull      = NSLocalizedString(@"Optional summary of page. Used by search engines.", @"null summary available, long placeholder");
	NSString *shortMultiple = NSLocalizedString(@"Optional summaries", @"multiple items selected, very short placeholder");
	NSString *shortNull     = NSLocalizedString(@"Optional summary", @"null summary available, very short placeholder");
	
	NSString *desiredMultiPlaceholder = (sizeOfField < (45) ? shortMultiple : longMultiple);
	NSString *desiredNullPlaceholder  = (sizeOfField < (45) ? shortNull : longNull);
	
	NSDictionary *infoForBinding	= [field infoForBinding:NSValueBinding];
	NSDictionary *bindingOptions	= [[[infoForBinding valueForKey:NSOptionsKey] retain] autorelease];
	NSString *bindingKeyPath		= [[[infoForBinding valueForKey:NSObservedKeyPathKey] retain] autorelease];
	id observedObject				= [[[infoForBinding valueForKey:NSObservedObjectKey] retain] autorelease];
	
	if (![[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] isEqualToString:desiredMultiPlaceholder])
	{
		NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
		[newBindingOptions setObject:desiredMultiPlaceholder forKey:NSMultipleValuesPlaceholderBindingOption];
		[newBindingOptions setObject:desiredNullPlaceholder forKey:NSNullPlaceholderBindingOption];
		
		[field unbind:NSValueBinding];
		[field bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
	}

	// Now do it all over for the tags field
	
	field = [self viewWithTag:5];
	OBASSERT(field);
	frame = [field frame];
	sizeOfField = frame.size.height;
	
	longMultiple  = NSLocalizedString(@"Optional words describing these pages, separated by “,”", @"multiple items selected, long placeholder");
	longNull      = NSLocalizedString(@"Optional words describing this page, separated by “,”", @"null keywords available, long placeholder");
	shortMultiple = NSLocalizedString(@"Optional words", @"multiple items selected, very short placeholder");
	shortNull     = NSLocalizedString(@"Optional words", @"null keywords available, very short placeholder");
	
	desiredMultiPlaceholder = (sizeOfField < (45) ? shortMultiple : longMultiple);
	desiredNullPlaceholder  = (sizeOfField < (45) ? shortNull : longNull);
	
	infoForBinding	= [field infoForBinding:NSValueBinding];
	bindingOptions	= [[[infoForBinding valueForKey:NSOptionsKey] retain] autorelease];
	bindingKeyPath	= [[[infoForBinding valueForKey:NSObservedKeyPathKey] retain] autorelease];
	observedObject	= [[[infoForBinding valueForKey:NSObservedObjectKey] retain] autorelease];
	
	if (![[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] isEqualToString:desiredMultiPlaceholder])
	{
		NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
		[newBindingOptions setObject:desiredMultiPlaceholder forKey:NSMultipleValuesPlaceholderBindingOption];
		[newBindingOptions setObject:desiredNullPlaceholder forKey:NSNullPlaceholderBindingOption];
		
		[field unbind:NSValueBinding];
		[field bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
	}
}


@end
