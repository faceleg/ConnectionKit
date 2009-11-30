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
#import "KSPlugin.h"
#import "KT.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "SVSiteOutlineViewController.h"

#import "NSArray+Karelia.h"

#import "MGScopeBar.h"


@implementation SVDesignChooserWindowController

- (void)awakeFromNib
{
    // load the xib that contains the collection view
    viewController_ = [[SVDesignChooserViewController alloc] initWithNibName:@"SVDesignChooserImageBrowser" 
                                                                      bundle:nil];

    // pop the collection view into the window.  This awakens SVDesignChooserImageBrowser's nib
    [oTargetView setContentView:[viewController_ view]];
    
    [viewController_ setupTrackingRects];
}

- (void)displayAsSheet
{
    [NSApp beginSheet:[self window]
       modalForWindow:[[self document] windowForSheet]
        modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
          contextInfo:nil];
    
    // Dear Dan,
    // The -mainWindowController API has been removed as it's a nuisance on the whole and kinda breaks encapsulation. Regardless,
    // the design chooser should have no concept of a document; it doesn't need to work at that level. Instead please could you make it
    // so that when ending the sheet, a callback is sent to the object that invoked the sheet in the first place, informing it of
    // the design that has been chosen. In practice, KTDocWindowController will use this callback to update the design of the master.
    // 
    // Lots of love,
    // Mike.
    //
    [self bind:@"selectedDesign"
      toObject:[[[[self document] mainWindowController] siteOutlineViewController] pagesController]
   withKeyPath:@"selection.master.design"
       options:nil];
    
    [oScopeBar setDelegate:self];
    [oScopeBar reloadData];
}

- (IBAction)chooseDesign:(id)sender
{
    // get the selected design
    NSUInteger selectedIndex = [[viewController_ designsArrayController] selectionIndex];
    KTDesign *design = [[viewController_ designs] objectAtIndex:selectedIndex];
    OBASSERT(nil != design);
    
    // prep the design
    [design loadLocalFontsIfNeeded];
    
    // message the document to change its design
    // (by telling the KTDocSiteOutlineController to update its selection.master.design)
    NSDictionary *bindingsInfo = [self infoForBinding:@"selectedDesign"];
    id controller = [bindingsInfo objectForKey:NSObservedObjectKey];
    NSString *keyPath = [bindingsInfo objectForKey:NSObservedKeyPathKey];
    [controller setValue:design forKeyPath:keyPath];
    
    // notify observers ?
    // FIXME: webview needs to actually update/redraw
    // here's the old notification code that the new SVWeb classes don't observe
//    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                              [NSNumber numberWithBool:YES], @"animate",
//                              NSStringFromPoint(NSMakePoint(0, 0)), @"mouse",
//                              nil];
//    [[NSNotificationCenter defaultCenter] postNotificationName:kKTDesignChangedNotification
//                                                        object:[self document]
//                                                      userInfo:userInfo];
    
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

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    OBASSERT(sheet == [self window]);
    [sheet orderOut:self];
    
    [self unbind:@"selectedDesign"];
}

@synthesize selectedDesign = selectedDesign_;
- (void)setSelectedDesign:(KTDesign *)aDesign
{
    [aDesign retain];
    [selectedDesign_ release];
    selectedDesign_ = aDesign;
    
    (void)[[viewController_ designsArrayController] setSelectedObjects:[NSArray arrayWithObject:selectedDesign_]];
}

@synthesize viewController = viewController_;

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
