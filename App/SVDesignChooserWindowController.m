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

#pragma mark -

- (void)awakeFromNib
{
    [oViewController setupTrackingRects];

	NSArray *designs = [KSPlugInWrapper sortedPluginsWithFileExtension:kKTDesignExtension];
	oViewController.designs = [KTDesign consolidateDesignsIntoFamilies:designs];
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
    return 1;
}

- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(NSInteger)groupNumber
{
    return [NSArray arrayWithObjects:@"All", @"Business", @"Artistic", @"Family", @"Light", @"Dark", nil ];
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(NSInteger)groupNumber
{
    return NSLocalizedString (@"Kind:", @"Label for kind of design; right before list of kinds of designs");
}

- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(NSInteger)groupNumber
{
    return MGRadioSelectionMode;
}

- (NSString *)scopeBar:(MGScopeBar *)theScopeBar 
           titleOfItem:(NSString *)identifier 
               inGroup:(NSInteger)groupNumber
{
	static NSDictionary *sDesignScopeBarTitles = nil;
	if (!sDesignScopeBarTitles)
	{
		sDesignScopeBarTitles = [[NSDictionary alloc] initWithObjectsAndKeys:
							  NSLocalizedString(@"All", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"All",
NSLocalizedString(@"Business", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Business",
NSLocalizedString(@"Artistic", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Artistic",
NSLocalizedString(@"Family", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Family",
NSLocalizedString(@"Light", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Light",
NSLocalizedString(@"Dark", @"category for kind of design, goes below 'Choose a design for your site:', after 'Kind:', and above list of designs."), @"Dark",
								 nil];
	}
	return [sDesignScopeBarTitles objectForKey:identifier];
}


@end
