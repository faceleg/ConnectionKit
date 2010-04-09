//
//  SVDesignChooserWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserWindowController.h"
#import "SVDesignChooserViewController.h"

#import "Debug.h"
#import "KSPlugInWrapper.h"
#import "KT.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "SVSiteOutlineViewController.h"

#import "NSArray+Karelia.h"

#import "MGScopeBar.h"


@implementation SVDesignChooserWindowController

#pragma mark Properties

- (KTDesign *)design
{
    [self window];    // make sure nib is loaded
    return oViewController.selectedDesign;
}
- (void)setDesign:(KTDesign *)design
{
    [self window];    // make sure nib is loaded
    oViewController.selectedDesign = design;
}

@synthesize selectorWhenChosen = _selectorWhenChosen;
@synthesize targetWhenChosen = _targetWhenChosen;
@synthesize allDesigns = _allDesigns;
@synthesize genre = _genre;
@synthesize color = _color;

enum { kGenreGroup, kColorGroup };

#pragma mark -

- (void)awakeFromNib
{
	NSArray *designs = [KSPlugInWrapper sortedPluginsWithFileExtension:kKTDesignExtension];

	// Get all designs; we'll be filtering...
	self.allDesigns = [KTDesign consolidateDesignsIntoFamilies:designs];
	oViewController.designs = self.allDesigns;
}

- (void)beginSheetModalForWindow:(NSWindow *)window delegate:(id)aTarget didEndSelector:(SEL)aSelector;
{
	self.selectorWhenChosen = aSelector;
	self.targetWhenChosen = aTarget;
	
    [NSApp beginSheet:[self window]
       modalForWindow:window
        modalDelegate:self
       didEndSelector:@selector(designChooserDidEndSheet:returnCode:contextInfo:)
          contextInfo:nil];
    
    [oScopeBar setDelegate:self];
    [oScopeBar reloadData];

    [oViewController setupTrackingRects];
}

- (IBAction)chooseDesign:(id)sender		// Design was chosen.  Now call back to notify of change.
{
    // get the selected design
	KTDesign *selectedDesign = [oViewController selectedDesign];
	if (selectedDesign)
	{
		if (self.targetWhenChosen && [self.targetWhenChosen respondsToSelector:self.selectorWhenChosen])
		{
			[self.targetWhenChosen performSelector:self.selectorWhenChosen withObject:selectedDesign];
		}
	}
    
    // close up shop, we're done
    [NSApp endSheet:[self window]];    
}

- (void)terminate:(id)sender
{
    // in 10.6 we could use setPreventsApplicationTerminationWhenModal:NO instead
    [self cancelSheet:sender];
    [NSApp terminate:sender];
}

- (IBAction)cancelSheet:(id)sender
{
    [NSApp endSheet:[self window]];
}

- (void)designChooserDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    OBASSERT(sheet == [self window]);
    [sheet orderOut:self];
}

@synthesize viewController = oViewController;

#pragma mark -
#pragma mark MGScopeBarDelegate


- (NSInteger)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar
{
    return 2;
}

- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(NSInteger)groupNumber
{
	NSArray *result = nil;
	switch(groupNumber)
	{
		case kGenreGroup:
			result = [NSArray arrayWithObjects:@"Business", @"Artistic", @"Family", nil ];
#ifdef DEBUG
			result = [result arrayByAddingObject:@"NULL"];
#endif
			break;
		case kColorGroup:
			result = [NSArray arrayWithObjects:@"Light", @"Dark", @"Color", nil ];
#ifdef DEBUG
			result = [result arrayByAddingObject:@"NULL"];
#endif
			break;
	}
	return result;
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(NSInteger)groupNumber
{
//	NSString *result = nil;
//	switch(groupNumber)
//	{
//		case kGenreGroup:
//			result = NSLocalizedString(@"Genre");
//			break;
//		case kColorGroup:
//			result = NSLocalizedString(@"Background");
//			break;
//	}
	return @"";
}

- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(NSInteger)groupNumber
{
    return MGMultipleSelectionMode;		// we will handle selection to be radio-like
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar 
           titleOfItem:(NSString *)identifier 
               inGroup:(NSInteger)groupNumber
{
	static NSDictionary *sDesignScopeBarTitles = nil;
	if (!sDesignScopeBarTitles)
	{
		sDesignScopeBarTitles = [[NSDictionary alloc] initWithObjectsAndKeys:
NSLocalizedString(@"Business", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Business",
NSLocalizedString(@"Artistic", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Artistic",
NSLocalizedString(@"Family", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Family",
NSLocalizedString(@"Light", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Light",
NSLocalizedString(@"Dark", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Dark",
								 
								 
								 NSLocalizedString(@"Colorful", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Color",

								 
								 
								 nil];
	}
	NSString *result = [sDesignScopeBarTitles objectForKey:identifier];
	if (!result)
	{
		result = identifier;	// fallback, but it won't be localized
	}
	return result;
}

// Respond to clicks by acting sort of like a radio button, but allowing for none to be clicked.
// thus we de-select any old item in the group if we are setting a new one.
// Then, based on which ones are selected, build up our filter predicate.

- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(NSInteger)groupNumber;
{
	switch (groupNumber)
	{
		case kGenreGroup:
		{
			if (selected && self.genre)
			{
				// turn off previous selection in this group
				[theScopeBar setSelected:NO forItem:self.genre inGroup:kGenreGroup];
			}
			self.genre = selected ? identifier : nil;
			break;
		}	
		case kColorGroup:
		{
			if (selected && self.color)
			{
				// turn off previous selection in this group
				[theScopeBar setSelected:NO forItem:self.color inGroup:kColorGroup];
			}
			self.color = selected ? identifier : nil;
			break;
		}
	}

	if (self.genre || self.color)
	{
		NSMutableArray *preds = [NSMutableArray array];
		if (self.color)
		{
			if (![@"NULL" isEqualToString:self.color])
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"color == %@", [self.color lowercaseString]]];
			}
			else
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"color == NULL"]];
			}
			
		}
		if (self.genre)
		{
			if (![@"NULL" isEqualToString:self.genre])
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"genre == %@", [self.genre lowercaseString]]];
			}
			else
			{
				[preds addObject:[NSPredicate predicateWithFormat:@"genre == NULL"]];
			}

		
		}
		
		oViewController.designs = [self.allDesigns filteredArrayUsingPredicate:
								   [NSCompoundPredicate andPredicateWithSubpredicates:preds]
								   ];
	}
	else	// no filter -- all
	{
		oViewController.designs = self.allDesigns;
	}
}

@end
