//
//  PageCounterInspector.m
//  PageCounterElement
//
//  Created by Dan Wood on 2/9/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "PageCounterInspector.h"
#import "PageCounterPagelet.h"


@implementation PageCounterInspector

- (void) awakeFromNib
{
	[oTheme removeAllItems];

	NSEnumerator *themeEnum = [[PageCounterPagelet themes] objectEnumerator];
	NSDictionary *themeDict;
	BOOL hasDoneGraphicsYet = NO;
	int tag = 0;
	
	while ((themeDict = [themeEnum nextObject]) != nil)
	{
		NSString *theme = [themeDict objectForKey:PCThemeKey];
		
		if ([[themeDict objectForKey:PCTypeKey] intValue] == PC_GRAPHICS)
		{
			if (!hasDoneGraphicsYet)
			{
				hasDoneGraphicsYet = YES;
				[[oTheme menu] addItem:[NSMenuItem separatorItem]];		// PROBLEMS WITH TAG BINDING?
			}
			else
			{
				[oTheme addItemWithTitle:@""];	// ADD THE MENU
				
				NSImage *sampleImage = [themeDict objectForKey:PCSampleImageKey];
				if (sampleImage)
				{
					[[oTheme lastItem] setImage:sampleImage];
				}
				[[oTheme lastItem] setTag:tag++];
			}
		}
		else
		{
			[oTheme addItemWithTitle:theme];	// ADD THE MENU
			[[oTheme lastItem] setAttributedTitle:	// make it bold, small system font
				[[[NSAttributedString alloc]
					initWithString:theme
						attributes:[NSDictionary dictionaryWithObjectsAndKeys:
										[NSFont boldSystemFontOfSize: [NSFont smallSystemFontSize]],
										NSFontAttributeName,
										nil]
					] autorelease]];
			[[oTheme lastItem] setTag:tag++];
		}
	}
	
	// CAN'T DO IT THIS WAY ANY MORE
//	int index = [[[self delegateOwner] objectForKey:@"selectedTheme"] unsignedIntValue];
//	[oTheme setBordered:(index < 2)];
	
}

#pragma mark -
#pragma mark Selected Theme

//- (void)setDelegateOwner:(id)newOwner
//{
//	// We keep an eye on "selected theme" so we can add or remove the border from the popup button
//	[[self delegateOwner] removeObserver:self forKeyPath:@"selectedTheme"];
//	[super setDelegateOwner:newOwner];
//	[newOwner addObserver:self forKeyPath:@"selectedTheme" options:0 context:NULL];
//}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"selectedTheme"])
	{
		// Add or remove the popup button's border as appropriate
		int index = [[[[self inspectedObjects] lastObject] objectForKey:@"selectedTheme"] unsignedIntValue];
		[oTheme setBordered:(index < 2)];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}



@end
