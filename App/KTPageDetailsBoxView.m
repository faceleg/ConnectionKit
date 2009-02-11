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
14		NSTextField 1 = Window Title
| 2px
?       NSTexField 2 - window title field
| 4px
		NSTextField 3 {{8, 458}, {136, 14}}, MinY|WidthSizable 'Description'			stick to top
	&   NSTExtField 4 -- countdown .... 11 Px tall, 3 px from below.
| 2px
?		NSTextField 5 {{10, 311}, {130, 144}}, HeightSizable|MinY|WidthSizable ''		resizable according space avaialble
| 4px
14px	NSTextField 6 {{7, 240}, {136, 14}}, MaxY|MinY|WidthSizable 'Tags'				then Tags
| 2px
???		NSTokenField 7 {{10, 53}, {130, 300}}, HeightSizable|WidthSizable ''			Then this according to how much space we have
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
	
	NSView *bottommost = [self viewWithTag:8];
	OBASSERT(bottommost);
	int topOfBottommost = NSMaxY([bottommost frame]);
	
	NSView *topmost = [self viewWithTag:1];
	OBASSERT(topmost);
	int bottomOfTopmost = NSMinY([topmost frame]);
	
	int topOfTitleField = bottomOfTopmost - 2;
	const int kSpaceBetweenResizableFields = 20;
	int spaceToDivide = topOfTitleField - topOfBottommost - (2 * kSpaceBetweenResizableFields);
	int sizeOfField = MIN(spaceToDivide / 3, 62);		// Try to get a third, but no more than 4 lines for title tag.

	NSView *field;
	NSRect frame;
	int newBottom;

	// Window Title Resizable Field
	newBottom = bottomOfTopmost-sizeOfField;
	field = [self viewWithTag:2];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	frame.size.height = sizeOfField;
	[field setFrame:frame];

	// Description label
	newBottom = newBottom - 14 - 4;		// field is 14 pixels high and we want 4 px gap
	field = [self viewWithTag:3];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	[field setFrame:frame];
	
	// Countdown field ... next to Description label
	field = [self viewWithTag:4];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom+ 1;		// just one pixel up from the 14-pixel one
	[field setFrame:frame];
	
	// Desc Resizable Field
	spaceToDivide -= sizeOfField;		// keep track of what's left
	sizeOfField = spaceToDivide / 2;	// will round down
	
	newBottom = newBottom-sizeOfField - 2;	// we want gap of 2 between field and label above
	field = [self viewWithTag:5];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	frame.size.height = sizeOfField;
	[field setFrame:frame];
	
	// Tag label
	newBottom = newBottom - 14 - 4;
	field = [self viewWithTag:6];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	[field setFrame:frame];
	
	// Tags resizable field
	sizeOfField = spaceToDivide - sizeOfField;		// take what's left for last field
	
	newBottom = newBottom - sizeOfField - 2;
	field = [self viewWithTag:7];
	OBASSERT(field);
	frame = [field frame];
	frame.origin.y = newBottom;
	frame.size.height = sizeOfField;
	[field setFrame:frame];
}

- (void) rebindSubviewPlaceholdersAccordingToSize;
{
	// Redo placeholder text for the summary field
	
	NSView *field;
	NSRect frame;
	int sizeOfField;
	
	NSString *longMultiple;
	NSString *longNull;
	NSString *shortMultiple;
	NSString *shortNull;
	NSString *desiredMultiPlaceholder;
	NSString *desiredNullPlaceholder;
	
	NSDictionary *infoForBinding;
	NSDictionary *bindingOptions;
	NSString *bindingKeyPath;
	id observedObject;
	
	// The window title field

	field = [self viewWithTag:2];	OBASSERT(field);
	frame = [field frame];
	sizeOfField = frame.size.height;
	
	longMultiple  = NSLocalizedString(@"Titles of browser window for selected pages. (Duplicates are discouraged.)", @"multiple items selected, longer placeholder");
	longNull      = NSLocalizedString(@"Custom title of window for page", @"null summary available, longer placeholder");
	shortMultiple = NSLocalizedString(@"Custom titles", @"multiple items selected, very short placeholder");
	shortNull     = NSLocalizedString(@"Custom title", @"null summary available, very short placeholder");
	
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

	// The summary field

	field = [self viewWithTag:5];	OBASSERT(field);
	frame = [field frame];
	sizeOfField = frame.size.height;
	
	longMultiple  = NSLocalizedString(@"Optional summaries. (Duplicates are discouraged.)", @"multiple items selected, longer placeholder");
	longNull      = NSLocalizedString(@"Optional summary of page. Used by search engines.", @"null summary available, longer placeholder");
	shortMultiple = NSLocalizedString(@"Optional summaries", @"multiple items selected, very short placeholder");
	shortNull     = NSLocalizedString(@"Optional summary", @"null summary available, very short placeholder");
	
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
	
	// Now do it all over for the tags field
	
	field = [self viewWithTag:7];	OBASSERT(field);
	frame = [field frame];
	sizeOfField = frame.size.height;
	
	longMultiple  = NSLocalizedString(@"Optional words describing pages, separated by “,”", @"multiple items selected, longer placeholder");
	longNull      = NSLocalizedString(@"Optional words describing this page, separated by “,”", @"null keywords available, longer placeholder");
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

// This is actually redundant since the RBSplitView gets a live update.  
- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[self rebindSubviewPlaceholdersAccordingToSize];
}


@end
