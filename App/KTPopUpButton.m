//
//  KTPopUpButton.m
//  Marvel
//
//  Created by Mike on 24/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPopUpButton.h"


@interface KTPopUpButton (Private)
- (void)generateMenu;
- (NSMenuItem *)setMenuItemAtIndex:(unsigned)index toTitle:(NSString *)title;
- (NSMenuItem *)menuItemForExtension:(NSString *)extension;
@end


@implementation KTPopUpButton

#pragma mark -
#pragma mark Init & Dealloc

+ (void)initialize
{
	[self exposeBinding:@"content"];
	[self exposeBinding:@"contentValues"];
	[self exposeBinding:@"selectedObject"];
	[self exposeBinding:@"menuTitle"];
	[self exposeBinding:@"defaultValue"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	[super initWithCoder:decoder];
	
	myDefaultValue = [NSLocalizedString(@"Default", "The default item in a list.") copy];
	
	return self;
}

- (void)dealloc
{
	[myContent release];
	[myContentValues release];
	[mySelectedObject release];
	[myMenuTitle release];
	[myDefaultValue release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSArray *)content { return myContent; }

- (void)setContent:(NSArray *)content
{
	content = [content copy];
	[myContent release];
	myContent = content;
	
	[self generateMenu];
}

- (NSArray *)contentValues { return myContentValues; }

- (void)setContentValues:(NSArray *)values
{
	values = [values copy];
	[myContentValues release];
	myContentValues = values;
	
	[self generateMenu];
}

- (id)selectedObject { return mySelectedObject; }

- (void)setSelectedObject:(id)anObject
{
	[anObject retain];
	[mySelectedObject release];
	mySelectedObject = anObject;
	
	[self generateMenu];
}

- (NSString *)menuTitle { return myMenuTitle; }

- (void)setMenuTitle:(NSString *)title
{
	title = [title copy];
	[myMenuTitle release];
	myMenuTitle = title;
	
	[self generateMenu];
}

- (NSString *)defaultValue { return myDefaultValue; }

- (void)setDefaultValue:(NSString *)defaultValue
{
	defaultValue = [defaultValue copy];
	[myDefaultValue release];
	myDefaultValue = defaultValue;
	
	[self generateMenu];
}

#pragma mark -
#pragma mark Menu

/*	Iterate through everything that should be in the menu, altering it as necessary
 */
- (void)generateMenu
{
	id selectedObject = [self selectedObject];
	unsigned index = 0;
	
	// Title
	NSString *menuTitle = [self menuTitle];
	if (menuTitle)
	{
		[self setMenuItemAtIndex:index toTitle:menuTitle];
		[[self itemAtIndex:index] setEnabled:NO];
		index++;
	}
	
	// Default value
	NSString *defaultValue = [self defaultValue];
	if (defaultValue)
	{
		[self setMenuItemAtIndex:index toTitle:defaultValue];
		if (!selectedObject) [self selectItemAtIndex:index];
		index++;
		
		// Separator
		[self setMenuItemAtIndex:index toTitle:nil];
		index++;
	}
	
	// Content
	NSArray *content = [self content];
	NSArray *contentValues = [self contentValues];
	
	unsigned contentIndex;
	for (contentIndex = 0; contentIndex < [content count]; contentIndex++)
	{
		id contentObject = [content objectAtIndex:contentIndex];
		
		// If a value is available from the contentValues array, use it. Otherwise fallback to -description
		NSString *value = [contentObject description];
		if (contentIndex < [contentValues count])
		{
			value = [contentValues objectAtIndex:contentIndex];
		}
		[self setMenuItemAtIndex:index toTitle:value];
		
		// Select the item if appropriate
		if ([selectedObject isEqual:contentObject]) [self selectItemAtIndex:index];
		index++;
	}
}

- (NSMenuItem *)setMenuItemAtIndex:(unsigned)index toTitle:(NSString *)title	// nil for a separator
{
	NSMenuItem *result = nil;
	
	NSMenu *menu = [self menu];
	unsigned count = [menu numberOfItems];
	
	// Create a new item if it doesn't already exist
	if (index >= count)
	{
		if (title)
		{
			result = [menu insertItemWithTitle:title action:@selector(menuItemSelected:) keyEquivalent:@"" atIndex:index];
			[result setTarget:self];
		}
		else
		{
			result = [NSMenuItem separatorItem];
			[menu insertItem:result atIndex:index];;
		}
	}
	else
	{
		// Replace the menu item if it is of the wrong sort
		result = [menu itemAtIndex:index];
		if ([result isSeparatorItem] != (title == nil))
		{
			[menu removeItemAtIndex:index];
			
			if (title)
			{
				result = [menu insertItemWithTitle:title action:@selector(menuItemSelected:) keyEquivalent:@"" atIndex:index];
				[result setTarget:self];
			}
			else
			{
				result = [NSMenuItem separatorItem];
				[menu insertItem:result atIndex:index];
			}
		}
		else if (title)
		{
			[result setTitle:title];
			[result setTarget:self];	[result setAction:@selector(menuItemSelected:)];
		}
	}
	
	return result;
}

- (unsigned)indexOfFirstContentMenuItem
{
	unsigned result = 0;
	
	if ([self menuTitle]) result++;
	if ([self defaultValue]) result += 2;
	
	return result;
}

- (IBAction)menuItemSelected:(id)sender
{
	if (![sender isKindOfClass:[NSMenuItem class]]) {
		return;
	}
	
	unsigned index = [[sender menu] indexOfItem:sender];
	id contentObject = nil;
	if (index >= [self indexOfFirstContentMenuItem])
	{
		contentObject = [[self content] objectAtIndex:(index - [self indexOfFirstContentMenuItem])];
	}
	
	NSDictionary *bindingInfo = [self infoForBinding:@"selectedObject"];
	id controller = [bindingInfo objectForKey:NSObservedObjectKey];
	NSString *keyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
	[controller setValue:contentObject forKeyPath:keyPath];
}

@end
