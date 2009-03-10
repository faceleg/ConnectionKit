
//
//  KTInfoWindowController.m
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTInfoWindowController.h"

#import "Debug.h"
#import "KSEmailAddressComboBox.h"
#import "KSPathInfoField.h"
#import "KSSmallDatePicker.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTApplication.h"
#import "KTDesign.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocWindow.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTElementPlugin.h"
#import "KTIndexPlugin.h"
#import "KTMaster.h"
#import "KTMediaManager.h"
#import "KTPage+Internal.h"
#import "KTPagelet.h"
#import "KTPluginInspectorViewsManager.h"
#import "KTPseudoElement.h"
#import "KTStackView.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "KSIsEqualValueTransformer.h"

#import "Registration.h"

enum { kPageletInSidebarPosition = 0, kPageletInCalloutPosition = 1 };

#define CUSTOM_TAG -99

// selectedLevel = root


@interface KTInfoWindowController ( Private )
- (BOOL)preventWindowAnimation;
- (void)setPreventWindowAnimation:(BOOL)flag;
- (void)adjustWindow;
- (void)updateCollectionStylePopup;
- (BOOL)disclosedPreset;
- (void)setDisclosedPreset:(BOOL)flag;

- (NSManagedObjectContext *)currentManagedObjectContext;

- (void)setCurrentSelection:(id)aCurrentSelection;

- (NSView *)selectionInspectorView;
- (void)setSelectionInspectorView:(NSView *)aSelectionInspectorView;

- (NSView *)pageInspectorView;
- (void)setPageInspectorView:(NSView *)aPageInspectorView;

- (int)selectedSegmentIndex;
- (void)setSelectedSegmentIndex:(int)aSelectedSegmentIndex;

- (void)setMainWindow:(NSWindow *)mainWindow;
- (void)setPluginInspectorViews:(NSMutableDictionary *)aPluginInspectorViews;
- (void)setPluginInspectorObjectControllers:(NSMutableDictionary *)aPluginInspectorObjectControllers;

// Support
- (KTDocSiteOutlineController *)siteOutlineController;

@end

@implementation KTInfoWindowController

#pragma mark shared controller/init

+ (void)initialize
{
	NSValueTransformer *aTransformer;
	
	aTransformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:
		[NSNumber numberWithInt:KTCalloutPageletLocation]];
	[NSValueTransformer setValueTransformer:aTransformer forName:@"PageletLocationIsCallout"];
	[aTransformer release];
	
	aTransformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:
		[NSNumber numberWithInt:KTSidebarPageletLocation]];
	[NSValueTransformer setValueTransformer:aTransformer forName:@"PageletLocationIsSidebar"];
	[aTransformer release];
}

- (id)init
{
	// need to set these options before loading the nib
	[KSEmailAddressComboBox setWillIncludeNames:NO];
	[KSEmailAddressComboBox setWillAddAnonymousEntry:NO];
	
	if (self = [super initWithWindowNibName:@"Info"])
	{
		mySelectedSegmentIndex = SEGMENT_NONE;	// uninititialized
	}
	return self;
}

#pragma mark awake

- (void)windowDidLoad
{
    [super windowDidLoad];
	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];

	if (nil == gRegistrationString)
	{
		// Name it with "PRO" to show it's pro
		NSTabViewItem *item = [oSiteTabView tabViewItemAtIndex:[oSiteTabView indexOfTabViewItemWithIdentifier:@"google"]];
		[item setLabel:[NSString stringWithFormat:@"%@ [PRO]", [item label]]];
	}
	else	// registered, remove if not pro
	{
		if (!gIsPro)
		{
			[oSiteTabView removeTabViewItem:[oSiteTabView tabViewItemAtIndex:[oSiteTabView indexOfTabViewItemWithIdentifier:@"google"]]];
		}
	}
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(mainWindowChanged:)
												 name:NSWindowDidBecomeMainNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateSelectedItemForInspector:)
												 name:kKTItemSelectedNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(anyWindowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(objectsDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:nil];
	
	NSString *path = [[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"];
	if (nil != path)
	{
		NSArray *languages = [NSArray arrayWithContentsOfFile:path];
		NSEnumerator *theEnum = [languages objectEnumerator];
		id object;
		int theIndex = 0;

		while (nil != (object = [theEnum nextObject]) )
		{
			NSString *ownName = [[object objectForKey:@"Name"] trim];
// not using
//			NSString *englishName = [[object objectForKey:@"Eng"]
//				trim];
//			NSString *charset = [[object objectForKey:@"Charset"] 
//				trim];
			NSString *code = [[object objectForKey:@"Code"] 
				trim];
			[oLanguagePopup insertItemWithTitle:ownName atIndex:theIndex];
			NSMenuItem *thisItem = [oLanguagePopup itemAtIndex:theIndex];
			[thisItem setRepresentedObject:code];
			theIndex++;
		}
	}
	
	
	/*/ Bind the page controller to its proxy object
	[oPageController bind:@"proxyObject"
				 toObject:oInfoWindowController
			  withKeyPath:@"selection.associatedDocument.windowController.siteOutlineController"
				  options:nil];
	*/
		
	[oPageController addObserver:self
		   forKeyPath:@"selection.selection.indexPresetDictionary"
			  options:NSKeyValueObservingOptionNew
			  context:nil];
	
			
	// Page menu title placeholder binding
	[oPageMenuTitleField bind:@"placeholderValue"
					 toObject:oPageController
				  withKeyPath:@"selection.selection.titleText"
					  options:nil];
	
	
	[[[oSortPopup menu] itemWithTag:KTCollectionUnsorted] setImage:[NSImage imageNamed:@"unsorted"]];
	[[[oSortPopup menu] itemWithTag:KTCollectionSortAlpha] setImage:[NSImage imageNamed:@"A"]];
	[[[oSortPopup menu] itemWithTag:KTCollectionSortReverseAlpha] setImage:[NSImage imageNamed:@"Z"]];
	[[[oSortPopup menu] itemWithTag:KTCollectionSortLatestAtBottom] setImage:[NSImage imageNamed:@"bigbot"]];
	[[[oSortPopup menu] itemWithTag:KTCollectionSortLatestAtTop] setImage:[NSImage imageNamed:@"bigtop"]];
	
	[[oIndexPopup itemAtIndex:0] setAction:@selector(changeIndexType:)];
	[[oIndexPopup itemAtIndex:0] setTarget:self];

	NSDictionary *indexPlugins = [KSPlugin pluginsWithFileExtension:kKTIndexExtension];
	[KTElementPlugin addPlugins:[NSSet setWithArray:[indexPlugins allValues]]
		toMenu:[oIndexPopup menu] target:self action:@selector(changeIndexType:) pullsDown:NO showIcons:NO smallIcons:NO smallText:YES];

	[oCollectionStylePopup removeAllItems];
	
	// first item: no index.
 	[oCollectionStylePopup addItemWithTitle:NSLocalizedString(@"No Index",@"First menu item to indicate no index")];
	[[oCollectionStylePopup lastItem] setAction:@selector(changeCollectionStyle:)];
	[[oCollectionStylePopup lastItem] setTarget:self];
	[[oCollectionStylePopup lastItem] setRepresentedObject:
		[NSDictionary dictionaryWithObjectsAndKeys:
			
//			// Other properties don't really matter, but we need to match the dictionary
//			[NSNumber numberWithBool:YES], @"collectionHyperlinkPageTitles",
//			[NSNumber numberWithInt:99], @"collectionMaxIndexItems",
//			[NSNumber numberWithBool:NO], @"collectionShowPermanentLink",
//			[NSNumber numberWithInt:0], @"collectionSortOrder",
//			[NSNumber numberWithBool:NO], @"collectionSyndicate",
			nil]];
	[[oCollectionStylePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// Middle: All the presets
	[KTIndexPlugin addPresetPluginsToMenu:[oCollectionStylePopup menu]
								   target:self
								   action:@selector(changeCollectionStyle:)
								pullsDown:NO
								showIcons:NO
							   smallIcons:NO
								smallText:YES allowNewPageTypes:NO];
	
	// Last item: custom
	[[oCollectionStylePopup menu] addItem:[NSMenuItem separatorItem]];
 	[oCollectionStylePopup addItemWithTitle:NSLocalizedString(@"Custom",@"Last menu item to indicate custom index type")];
	[[oCollectionStylePopup lastItem] setTag:CUSTOM_TAG];
	[[oCollectionStylePopup lastItem] setAction:@selector(changeCollectionStyle:)];
	[[oCollectionStylePopup lastItem] setTarget:self];
	
	[oGoogleVerificationExplanationTextView setDrawsBackground:NO];
	[[oGoogleVerificationExplanationTextView enclosingScrollView] setDrawsBackground:NO];
	[[[oGoogleVerificationExplanationTextView enclosingScrollView] contentView] setCopiesOnScroll:NO];
	
	[oGoogleAnalyticsExplanationTextView setDrawsBackground:NO];
	[[oGoogleAnalyticsExplanationTextView enclosingScrollView] setDrawsBackground:NO];
	[[[oGoogleAnalyticsExplanationTextView enclosingScrollView] contentView] setCopiesOnScroll:NO];
	
	
	// Force initial layout of tab view
	BOOL preventWindowAnimation = [self preventWindowAnimation];
	[self setPreventWindowAnimation:YES];
	[self tabView:oSiteTabView didSelectTabViewItem:[oSiteTabView selectedTabViewItem]];
	[self setPreventWindowAnimation:preventWindowAnimation];

	[oStackView retain];
	[oStackView setDataSource:self];		// ready to hook up UI, not before!
	
	[oTabSegmentedControl setFocusRingType: NSFocusRingTypeNone];	// don't draw focus since it's truncated top/sides
	
	// FIXME: disable Disqus for 1.6 beta
	//[[oCommentsProviderPopup itemAtIndex:[oCommentsProviderPopup indexOfItemWithTag:KTCommentsProviderDisqus]] setEnabled:NO];
}

- (IBAction) languageChosen:(id)sender;
{
	BOOL isOther = [[sender selectedItem] tag] < 0;
	[oLanguageCodeField setEnabled:isOther];
	
	NSString *languageCode = [[sender selectedItem] representedObject];
	[[[self selectedLevel] valueForKey:@"master"] setValue:languageCode forKey:@"language"];
}

- (IBAction) changeCollectionStyle:(id)sender
{
	OBASSERTSTRING( [sender respondsToSelector:@selector(representedObject)], @"Sender needs to have a representedObject" );
	NSDictionary *presetDict= [sender representedObject];
	
	if (CUSTOM_TAG == [sender tag])
	{
		[self setDisclosedPreset:YES];	// force the custom settings view to disclose
	}
	else if (nil != presetDict)
	{
		NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
		KTIndexPlugin *plugin = (identifier) ? [KTIndexPlugin pluginWithIdentifier:identifier] : nil;
		NSDictionary *pageSettings = [presetDict objectForKey:@"KTPageSettings"];
		
		myIgnoreCollectionStyleChanges = YES;
		KTPage *collection = [[self siteOutlineController] selectedPage];
		[collection setIndexFromPlugin:plugin];
		[collection setValuesForKeysWithDictionary:pageSettings];
		
		// Update the index menu "manually" since there's no bindings
		NSString *indexIdentifier = [collection valueForKey:@"collectionIndexBundleIdentifier"];
		int itemIndex = (indexIdentifier) ? [oIndexPopup indexOfItemWithRepresentedObject:indexIdentifier] : -1;
		if (itemIndex == -1) itemIndex = 0;
		[oIndexPopup selectItemAtIndex:itemIndex];
		
		myIgnoreCollectionStyleChanges = NO;
	}
	else
	{
		NSLog(@"Collection style popup should have a preset dict!");
	}
	// load the view stack since it's changed
	[oStackView reloadSubviews];	
	[self adjustWindow];
}

- (IBAction)changeIndexType:(id)sender
{
	NSString *pluginIdentifier = [sender representedObject];
	KTIndexPlugin *plugin = (pluginIdentifier) ? [KSPlugin pluginWithIdentifier:pluginIdentifier] : nil;
	
	[[[self siteOutlineController] selectedPage] setIndexFromPlugin:plugin];
}

- (IBAction)openHaloscan:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.haloscan.com/"]];
}

#pragma mark dealloc

- (void)dealloc
{
	[oStackView release];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[oPageController removeObserver:self forKeyPath:@"selection.selection.indexPresetDictionary"];
    
    
//	[self setCurrentlyBoundControllers:nil];
	
	[self setPluginInspectorViews:nil];
    [self setPluginInspectorObjectControllers:nil];
    [self setAssociatedDocument:nil];
    [self setCurrentSelection:nil];
    [self setSelectedPagelet:nil];
    [self setSelectedLevel:nil];
    [self setSelectionInspectorView:nil];
    [self setPageInspectorView:nil];

	[super dealloc];
}

- (void)clearAll		// see also anyWindowWillClose, dealloc
{
	[self clearObjectControllers];
    [self setAssociatedDocument:nil];
    [self setSelectedPagelet:nil];
    [self setSelectedLevel:nil];
	[self setSelectionInspectorView:nil];
    [self setPageInspectorView:nil];
	[self setCurrentSelection:nil];
	[self setupViewStackFor:nil selectLevel:NO];
	
	[[self window] orderOut:nil];
}

#pragma mark notifications

- (void)mainWindowChanged:(NSNotification *)notification
{
	id object = [notification object];
	if ([object isKindOfClass:[KTDocWindow class]])
	{
		[self setMainWindow:object];
	}
}

- (void)windowWillClose:(NSNotification *)notification;
{
	[oInfoWindowController unbind:@"contentObject"];
	[oInfoWindowController setContent:nil];

	// clear out the display for the most part
	[oStackView reloadSubviews];
}

- (void)anyWindowWillClose:(NSNotification *)aNotification
{
	if ([[aNotification object] isKindOfClass:[KTDocWindow class]])
	{
		[self clearObjectControllers];				/// these are pretty much from clearAll
		[self setAssociatedDocument:nil];
		[self setSelectedPagelet:nil];
		[self setSelectedLevel:nil];
		[self setSelectionInspectorView:nil];
		[self setPageInspectorView:nil];
		[self setCurrentSelection:nil];
		[self setupViewStackFor:nil selectLevel:NO];
	}
}

- (void)setMainWindow:(NSWindow *)mainWindow
{
    NSWindowController *controller = [mainWindow windowController];
	KTDocument *document = (KTDocument *)[controller document];
	if ( document != myAssociatedDocument )
	{
		[self setAssociatedDocument:document];
		[self setupViewStackFor:[[[document windowController] siteOutlineController] selectedPage] selectLevel:NO];
	}
}

- (void)updateSelectedItemForInspector:(NSNotification *)aNotification
{
	id selectedItem = [aNotification object];
	[self setupViewStackFor:selectedItem selectLevel:NO];	// only select level if we actually click on segment
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if (tabView == oSiteTabView)
	{
		;/// took out buggy attempt to resize the window.  Sizes are all the same anyhow so it's OK without it.
	}
	[oStackView reloadSubviews];
	[self adjustWindow];
}

- (void)objectsDidChange:(NSNotification *)aNotification
{
	NSManagedObjectContext *context = [aNotification object];
	if ( (nil != context) && [context isEqual:[myAssociatedDocument managedObjectContext]] )
	{
		NSSet *deletedObjects = [[aNotification userInfo] valueForKey:NSDeletedObjectsKey];
		if ( nil != deletedObjects )
		{
			id subsituteItem = nil;
			
			if ( nil != myCurrentSelection )
			{
				if ( [deletedObjects containsObject:myCurrentSelection] )
				{
					//LOG((@"info noticing current selection has been deleted"));
					[self setCurrentSelection:nil];
					subsituteItem = [[self siteOutlineController] selectedPage];
				}
			}
			
			if ( nil != mySelectedPagelet )
			{
				if ( [deletedObjects containsObject:mySelectedPagelet] )
				{
					//LOG((@"info noticing selected pagelet has been deleted"));
					[self setSelectedPagelet:nil];
					subsituteItem = [[self siteOutlineController] selectedPage];
				}
			}
			
			if (subsituteItem && [subsituteItem isKindOfClass:[KTPage class]])
			{
				[self setupViewStackFor:subsituteItem selectLevel:NO];
			}
		}
	}
}

#pragma mark stackview

- (void)adjustWindow
{
	if (nil != [[self window] contentView])
	{
		[oStackView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
			
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		BOOL shouldAnimate = (!myPreventWindowAnimation) && [defaults boolForKey:@"DoAnimations"];
			
		NSWindow *window = [self window];
		NSSize stackSize = [oStackView bounds].size;
		NSRect windowFrame = [window frame];
		NSRect contentFrame = [NSWindow contentRectForFrameRect:windowFrame styleMask:[window styleMask]];
		
		float heightChange = contentFrame.size.height - stackSize.height;
		contentFrame.origin.y += heightChange;
		contentFrame.size = stackSize;

		NSRect frame = [NSWindow frameRectForContentRect:contentFrame styleMask:[window styleMask]];
		
//		// Now make sure it will fit (vertically), and adjust if needed
		
// WHY DOESN'T THIS WORK?  IT SEEMS TO MOVE THE WINDOW WAY UP TOO HIGH!
		
//		NSRect screenRect = [[window screen] visibleFrame];
//		if (!NSContainsRect(screenRect, frame))
//		{
//			if (NSMaxY(frame) > NSMaxY(screenRect))
//			{
//				frame.origin.y = NSMaxY(screenRect);	// top edge
//			}
//			if (NSMinY(frame) < NSMinY(screenRect))
//			{
//				frame.origin.y = NSMinY(screenRect) + frame.size.height;	// bottom edge
//			}
//		}
		[window setFrame:frame display:!myPreventWindowAnimation animate:shouldAnimate];
	}
	else
	{
		// Still some problem here -- for some reason, reattaching to drawer when collection has custom stuff disclosed hides the disclosed stuff
		[oStackView setAutoresizingMask: NSViewMinYMargin];

		NSView *superview = [oStackView superview];
		NSSize supersize = [superview frame].size;
		NSSize stacksize = [oStackView frame].size;
		[oStackView setFrameOrigin:NSMakePoint(0,supersize.height - stacksize.height)];		// will be negative if it won't fit -- that should be OK

		[superview setNeedsDisplay:YES];
	}
}

- (void)clearObjectControllers
{
	/*if ( nil != mySelectedPagelet )
	{
		KTPagelet *pagelet = mySelectedPagelet;
        
		NSEnumerator *e = [[mySelectedPagelet wrappedValueForKey:@"elements"] objectEnumerator];
        KTElement *element;
        while ( element = [e nextObject] )
        {
            [element clearObjectController];
        }
        
		[pagelet clearObjectController];
	}

	if ( nil != [self selectedPage] )
	{
		KTPage *page = [self selectedPage];
        
		NSEnumerator *e = [[[self selectedPage] wrappedValueForKey:@"elements"] objectEnumerator];
        KTElement *element;
        while ( element = [e nextObject] )
        {
            [element clearObjectController];
        }

		[page clearObjectController];
	}*/
}

- (void)setupViewStackFor:(id)selectedItem selectLevel:(BOOL)aWantLevel
{
	/// in some cases, selectedItem == [self selectedPage]
	[selectedItem retain]; // don't lose this!
	
	[self window];	// make sure window is loaded

	if (!myAssociatedDocument) return;
	
	
	
	[self setSelectedLevel:[[myAssociatedDocument documentInfo] root]];
	
	// Manually synchronize the language popup and field
	NSString *languageCode = [[[self selectedLevel] master] valueForKey:@"language"];
	int theIndex = [oLanguagePopup indexOfItemWithRepresentedObject:languageCode];
	BOOL otherLanguage = (theIndex < 0);
	[oLanguageCodeField setEnabled:otherLanguage];
	if (otherLanguage)
	{
		theIndex = [oLanguagePopup indexOfItemWithTag:-1];
	}
	[oLanguagePopup selectItemAtIndex:theIndex];
	
	
	if (selectedItem != myCurrentSelection ||
		[selectedItem isKindOfClass:[KTPseudoElement class]] ||
		[[[self siteOutlineController] selectionIndexes] count] > 1)
	{
//		NSLog(@"setupViewStackFor: %@", 
//			  ( [selectedItem respondsToSelector:@selector(entity)] 
//				? [[selectedItem entity] name] 
//				: [selectedItem className]));
	
		[self setCurrentSelection:selectedItem];
		[self setSelectedPagelet:nil];
	
		// Do a little initialization
		
		// Configure the value of customFileExtension, which should initially be checked if
		// our custom page type is NOT html
		[self setCustomFileExtension:NO];		// TODO: fix
		
		if (![[self siteOutlineController] selectedPage])
		{
//			NSLog(@"Level = %p Page = %p Pagelet = %p", mySelectedLevel, [self selectedPage], mySelectedPagelet);
			
			[self setPageInspectorView:nil];
			[self setSelectionInspectorView:nil];
			
            [oTabSegmentedControl setEnabled:YES forSegment:SEGMENT_PAGE];
			[oTabSegmentedControl setLabel:NSLocalizedString(@"Selection",@"Segment Label") forSegment:SEGMENT_SELECTION];
			[oTabSegmentedControl setEnabled:NO forSegment:SEGMENT_SELECTION];
			
			// Select page if we didn't have anything selected before
			if (SEGMENT_NONE == mySelectedSegmentIndex)
			{
				[self setSelectedSegmentIndex:SEGMENT_PAGE];	// switch to page if we were on selection
			}
		}
		else if ([myCurrentSelection isKindOfClass:[KTPage class]])	// was the selected item the page?
		{
			if ([((KTPage *)myCurrentSelection) isCollection])
			{
				// Select the right choice in the "Index" popup
				NSString *pluginIdentifier = [myCurrentSelection wrappedValueForKey:@"collectionIndexBundleIdentifier"];
				int itemIndex = (pluginIdentifier) ? [oIndexPopup indexOfItemWithRepresentedObject:pluginIdentifier] : -1;
				if (itemIndex == -1) itemIndex = 0;
				[oIndexPopup selectItemAtIndex:itemIndex];
				
				[self updateCollectionStylePopup];
			}
			// load the appropriate inspector view
			NSView *inspectorView = [[[myAssociatedDocument windowController] pluginInspectorViewsManager] inspectorViewForPlugin:myCurrentSelection];	///[myCurrentSelection inspectorView];
			
			// If needs to be pro, substitute with oProRequiredView
			BOOL isProFeature = (9 == [[[myCurrentSelection plugin] pluginPropertyForKey:@"KTPluginPriority"] intValue]);
			if (isProFeature && (!gIsPro) && (nil != gRegistrationString))
			{
				inspectorView = oProRequiredView;
			}			
			
			[self setPageInspectorView:inspectorView];
			[oTabSegmentedControl setEnabled:YES forSegment:SEGMENT_PAGE];
			
			BOOL shouldSeparateInspectorSegment = [((KTPage *)myCurrentSelection) separateInspectorSegment];
			if (shouldSeparateInspectorSegment && (nil != inspectorView))
			{
				NSString *pageTypeName = [[((KTPage *)myCurrentSelection) plugin] pluginPropertyForKey:@"KTPluginName"];
				//float width = [oTabSegmentedControl widthForSegment:SEGMENT_SELECTION];
// TODO: Nicely truncate the label with ...
				
				[oTabSegmentedControl setLabel:pageTypeName forSegment:SEGMENT_SELECTION];
				[oTabSegmentedControl setEnabled:YES forSegment:SEGMENT_SELECTION];
				
				// leave segment alone if already on page, or site is selected.
			}
			else	// put details below, so don't enable details segment
			{
				[oTabSegmentedControl setLabel:NSLocalizedString(@"Selection",@"Segment Label") forSegment:SEGMENT_SELECTION];
				[oTabSegmentedControl setEnabled:NO forSegment:SEGMENT_SELECTION];

				if (SEGMENT_SELECTION == mySelectedSegmentIndex)
				{
					[self setSelectedSegmentIndex:SEGMENT_PAGE];	// switch to page if we were on selection
				}
			}
			
			// Select page if we didn't have anything selected before
			if (SEGMENT_NONE == mySelectedSegmentIndex)
			{
				[self setSelectedSegmentIndex:SEGMENT_PAGE];	// switch to page if we were on selection
			}
		}
		else if ([myCurrentSelection isKindOfClass:[KTPagelet class]])
		{
			KTPagelet *pagelet = ((KTPagelet *)myCurrentSelection);
			
			[self setSelectedPagelet:pagelet];
			
			if ([pagelet location] == KTCalloutPageletLocation) {
				mySelectedPageletPosition = kPageletInCalloutPosition;
			}
			else {
				mySelectedPageletPosition = kPageletInSidebarPosition;
			}
			
						
//			NSLog(@"Level = %p Page = %p Pagelet = %p", mySelectedLevel, [self selectedPage], mySelectedPagelet);
			
			NSView *pageletInspectorView = [[[myAssociatedDocument windowController] pluginInspectorViewsManager] inspectorViewForPlugin:myCurrentSelection];
			
			// If needs to be pro, substitute with oProRequiredView
			BOOL isProFeature = (9 == [[[myCurrentSelection plugin] pluginPropertyForKey:@"KTPluginPriority"] intValue]);
			if (isProFeature && (!gIsPro) && (nil != gRegistrationString))
			{
				pageletInspectorView = oProRequiredView;
			}			
			
			[self setSelectionInspectorView:pageletInspectorView];

			[oTabSegmentedControl setEnabled:YES forSegment:SEGMENT_PAGE];
			[oTabSegmentedControl setLabel:NSLocalizedString(@"Pagelet",@"Segment Label") forSegment:SEGMENT_SELECTION];
			[oTabSegmentedControl setEnabled:YES forSegment:SEGMENT_SELECTION];	// always something for pagelets!
			// Always select selection when you click on a pagelet
			[self setSelectedSegmentIndex:SEGMENT_SELECTION];
		}
		else if ([myCurrentSelection isKindOfClass:[KTPseudoElement class]])
		{
			NSView *pluginInspectorView = [[[myAssociatedDocument windowController] pluginInspectorViewsManager] inspectorViewForPlugin:myCurrentSelection];
			[self setSelectionInspectorView:pluginInspectorView];

			[oTabSegmentedControl setEnabled:YES forSegment:SEGMENT_PAGE];
			[oTabSegmentedControl setLabel:NSLocalizedString(@"Image",@"Segment Label") forSegment:SEGMENT_SELECTION];
			[oTabSegmentedControl setEnabled:(nil != pluginInspectorView) forSegment:SEGMENT_SELECTION];
			
			// Try to select selection if we clicked on element
			[self setSelectedSegmentIndex:(nil != pluginInspectorView) ? SEGMENT_SELECTION : SEGMENT_PAGE];
		}
		else
		{
//			NSLog(@"What do we to do swap in %@", 
//				  ([myCurrentSelection respondsToSelector:@selector(entity)] 
//				   ? [[myCurrentSelection entity] name] 
//				   : myCurrentSelection));
			//Here we need an inspector related to the element selected.  It goes either in final tabview, or replaces content!
		}
		
		// Now notify that things have changed
		[oStackView reloadSubviews];
		[self adjustWindow];
	}
	
	/// balance retain at top of method
	[selectedItem release]; // ok, we should be done with this
}

- (NSArray *)subviewsForStackView:(KTStackView *)stackView
{
	NSMutableArray *result = [NSMutableArray array];
	
	[result addObject:oSegmentsView];		// almost everything starts with the segments view
	
	if (nil == [oInfoWindowController content])
	{
		return result;
	}
		
	switch ([oTabSegmentedControl selectedSegment])
	{
		case SEGMENT_SITE:
			[result addObject:oSiteView];
			[result addObject:oHelpBottomView];
			break;
		case SEGMENT_PAGE:
		{
			[result addObject:oPageView];
			
			// If only a single page is selected, show other more specialised information
			KTPage *selectedPage = [[self siteOutlineController] selectedPage];
			if (selectedPage)
			{
				if ([selectedPage isCollection])
				{
					[result addObject:oDividerView];
					[result addObject:oCollectionView];
					
					if ([self disclosedPreset])
					{
						[result addObject:oCustomIndexView];
					}
				}
				if (![myCurrentSelection isKindOfClass:[KTPseudoElement class]] &&
					myPageInspectorView &&
					![selectedPage separateInspectorSegment])
				{
					[result addObject:oDividerView];
					[result addObject:oPageDetailsHeaderView];		// shows page type name
					[result addObject:myPageInspectorView];
				}
			}
			
			[result addObject:oHelpBottomView];
			
			break;
		}
		case SEGMENT_SELECTION:
		{
			if ([myCurrentSelection isKindOfClass:[KTPagelet class]])
			{
				[result addObject:oPageletGeneralView];
				if (nil != mySelectionInspectorView)
				{
					[result addObject:oDividerView];
					[result addObject:oPageletDetailsHeaderView];		// shows pagelet type name
					[result addObject:mySelectionInspectorView];
				}
			}
			else	// page or pseudo element
			{
				if ([myCurrentSelection isKindOfClass:[KTPseudoElement class]])
				{
					[result addObject:mySelectionInspectorView];
				}
				else if (nil != myPageInspectorView && [[[self siteOutlineController] selectedPage] separateInspectorSegment])
				{
					[result addObject:myPageInspectorView];
				}
				else
				{
					[result addObject:oNothingView];
				}
			}
			[result addObject:oHelpBottomView];
			break;
		}
	}
	
	return result;
}

#pragma mark plugin inspection

///*!	Find view already set up.  May return [NSNull null] if already found none exists
//*/
//- (NSView *)inspectorViewForPluginIdentifier:(NSString *)anIdentifier
//{
//	return [myPluginInspectorViews objectForKey:anIdentifier];
//}
//
//- (NSObjectController *)objectControllerForPluginIdentifier:(NSString *)anIdentifier
//{
//	return [myPluginInspectorObjectControllers objectForKey:anIdentifier];
//}
//
//- (void)setPluginInspectorViews:(NSMutableDictionary *)aDictionary
//{
//	[aDictionary retain];
//	[myPluginInspectorViews release];
//	myPluginInspectorViews = aDictionary;
//}
//
//- (void)setPluginInspectorObjectControllers:(NSMutableDictionary *)aPluginInspectorObjectControllers
//{
//    [aPluginInspectorObjectControllers retain];
//    [myPluginInspectorObjectControllers release];
//    myPluginInspectorObjectControllers = aPluginInspectorObjectControllers;
//}
//
///*!	Store away existing.  May be [NSNull null] if it's known to not exist.
//*/
//- (void)setInspectorView:(NSView *)aView
//	 andObjectController:(NSObjectController *)anObjectController
//	 forPluginIdentifier:(NSString *)anIdentifier;
//{
//	if ( nil == myPluginInspectorViews )
//	{
//		[self setPluginInspectorViews:[NSMutableDictionary dictionary]];
//	}
//	if ( nil == myPluginInspectorObjectControllers )
//	{
//		[self setPluginInspectorObjectControllers:[NSMutableDictionary dictionary]];
//	}
//	
//	[myPluginInspectorViews setObject:aView forKey:anIdentifier];
//	[myPluginInspectorObjectControllers setObject:anObjectController forKey:anIdentifier];
//}

#pragma mark pagelet inspection

- (BOOL)enableShowPageletBorderButton
{
	BOOL result = NO;
//	KTDesign *currentDesign = [[self selectedPage] design];
	
	// sidebarBorderable, calloutBorderable
// TODO: finish
	return result;
}

- (IBAction) movePageletUp:(id)sender;
{
	KTPagelet *pagelet = [self selectedPagelet];
    if ([pagelet canMoveUp])
    {
        [pagelet moveUp];
    }
}

- (IBAction) movePageletDown:(id)sender;
{
	KTPagelet *pagelet = [self selectedPagelet];
    if ([pagelet canMoveDown])
    {
        [pagelet moveDown];
    }
}

#pragma mark -
#pragma mark Comments

- (IBAction)chooseCommentsProvider:(id)sender
{
	KTCommentsProvider provider = [sender selectedTag];
	[[[self selectedLevel] master] setCommentsProvider:provider];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Disable Disqus for 1.6 beta
	//if ( KTCommentsProviderDisqus == [menuItem tag] ) return NO;
	return YES;
}

#pragma mark -
#pragma mark Media

- (IBAction)chooseBannerImagePath:(id)sender;
{
	NSOpenPanel *imageChooser = [NSOpenPanel openPanel];
	[imageChooser setCanChooseDirectories:NO];
	[imageChooser setAllowsMultipleSelection:NO];
	[imageChooser setTreatsFilePackagesAsDirectories:YES];
	[imageChooser setPrompt:NSLocalizedString(@"Choose", "choose button - open panel")];
	
// TODO: Open the panel at a reasonable location
	[imageChooser runModalForDirectory:nil
								  file:nil
								 types:[NSImage imageFileTypes]];
	
	NSArray *selectedPaths = [imageChooser filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
	KTMediaContainer *media  = [[[self associatedDocument] mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
	[[[self selectedLevel] master] setBannerImage:media];
}

- (IBAction)clearBannerImage:(id)sender;
{
	[[self selectedLevel] setValue:nil forKeyPath:@"master.bannerImage"];
}

- (IBAction)chooseLogoImagePath:(id)sender;
{
	NSOpenPanel *imageChooser = [NSOpenPanel openPanel];
	[imageChooser setCanChooseDirectories:NO];
	[imageChooser setAllowsMultipleSelection:NO];
	[imageChooser setTreatsFilePackagesAsDirectories:YES];
	[imageChooser setPrompt:NSLocalizedString(@"Choose", "choose button - open panel")];
	
// TODO: Open the panel at a reasonable location
	[imageChooser runModalForDirectory:nil
								  file:nil
								 types:[NSImage imageFileTypes]];
	
	NSArray *selectedPaths = [imageChooser filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
	KTMediaContainer *logo = [[[self associatedDocument] mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
	[[[self selectedLevel] master] setLogoImage:logo];
}

- (IBAction)clearLogoImage:(id)sender;
{
	[[[self selectedLevel] master] setLogoImage:nil];
}

/*	Only allow images to be dropped
 */
- (NSArray *)supportedDragTypesForPathInfoField:(KSPathInfoField *)pathInfoField
{
	return [NSImage imagePasteboardTypes];
}

- (NSDragOperation)pathInfoField:(KSPathInfoField *)field
				validateFileDrop:(NSString *)path operationMask:(NSDragOperation)dragMask
{
	NSDragOperation result = NSDragOperationNone;
	
	if ([NSString UTI:[NSString UTIForFileAtPath:path] conformsToUTI:(NSString *)kUTTypeImage])
	{
		// The file is of a suitable type. Ask the media manager whether it'd like to copy or alias it
		KTMediaManager *mediaManager = [[self associatedDocument] mediaManager];
		NSDragOperation preferredOperation = NSDragOperationCopy;
		if ([mediaManager mediaFileShouldBeExternal:path])
		{
			preferredOperation = dragMask & NSDragOperationLink;
		}
		
		// If the preferred action is available, take it, otherwise do what the user requested
		if (dragMask & preferredOperation)
		{
			result = preferredOperation;
		}
		else
		{
			if (dragMask & NSDragOperationLink) {
				result = NSDragOperationLink;
			}
			else if (dragMask & NSDragOperationCopy) {
				result = NSDragOperationCopy;
			}
		}
	} 
	
	return result;
}

/*	Set the banner or logo image as appropriate
 */
- (BOOL)pathInfoField:(KSPathInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp
{
	BOOL result = NO;
	
	BOOL fileShouldBeExternal = NO;
	if (dragOp & NSDragOperationLink)
	{
		fileShouldBeExternal = YES;
	}
	
	if (field == oBannerPathInfoField)
	{
		KTMediaContainer *banner = [[[self associatedDocument] mediaManager] mediaContainerWithDraggingInfo:sender
																				  preferExternalFile:fileShouldBeExternal];
		
		[[[self selectedLevel] master] setBannerImage:banner];
		result = YES;
	}
	else if (field == oLogoPathInfoField)
	{
		KTMediaContainer *logo = [[[self associatedDocument] mediaManager] mediaContainerWithDraggingInfo:sender
																				preferExternalFile:fileShouldBeExternal];
		
		[[[self selectedLevel] master] setLogoImage:logo];
		result = YES;
	}
	
	return result;
}

- (IBAction)chooseFaviconPath:(id)sender
{
	NSOpenPanel *imageChooser = [NSOpenPanel openPanel];
	[imageChooser setCanChooseDirectories:NO];
	[imageChooser setAllowsMultipleSelection:NO];
	[imageChooser setTreatsFilePackagesAsDirectories:YES];
	[imageChooser setPrompt:NSLocalizedString(@"Choose", "choose button - open panel")];
	
// TODO: Open the panel at a reasonable location
	[imageChooser runModalForDirectory:nil
								  file:nil
								 types:[NSImage imageFileTypes]];
	
	NSArray *selectedPaths = [imageChooser filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
	KTMediaContainer *favicon = [[[self associatedDocument] mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
	[[[self selectedLevel] master] setFavicon:favicon];
}

- (IBAction)clearFavicon:(id)sender
{
	[[self selectedLevel] setValue:nil forKeyPath:@"master.favicon"];
}

- (IBAction)choosePageThumbnail:(id)sender
{
	NSOpenPanel *imageChooser = [NSOpenPanel openPanel];
	[imageChooser setCanChooseDirectories:NO];
	[imageChooser setAllowsMultipleSelection:NO];
	[imageChooser setTreatsFilePackagesAsDirectories:YES];
	[imageChooser setPrompt:NSLocalizedString(@"Choose", "choose button - open panel")];
	
// TODO: Open the panel at a reasonable location
	[imageChooser runModalForDirectory:nil
								  file:nil
								 types:[NSImage imageFileTypes]];
	
	NSArray *selectedPaths = [imageChooser filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
	KTMediaContainer *thumbnail = [[[self associatedDocument] mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
	[[[self siteOutlineController] selection] setValue:thumbnail forKey:@"thumbnail"];
}

- (IBAction)resetPageThumbnail:(id)sender
{
	NSArray *pages = [[self siteOutlineController] selectedObjects];
	NSEnumerator *pagesEnumerator = [pages objectEnumerator];
	KTPage *aPage;
	
	while (aPage = [pagesEnumerator nextObject])
	{
		id pageDelegate = [aPage delegate];
		if (pageDelegate && [pageDelegate respondsToSelector:@selector(pageShouldClearThumbnail:)])
		{
			if ([pageDelegate pageShouldClearThumbnail:aPage])
			{
				[aPage setThumbnail:nil];
			}
		}
		else
		{
			[aPage setThumbnail:nil];
		}
	}
}

#pragma mark image view delegate

- (void)imageView:(KTImageView *)anImageView setWithDataSourceDictionary:(NSDictionary *)aDataSourceDictionary
{
	if (anImageView == oThumbImageView)
	{
		KTMediaContainer *thumbnail = [[[self associatedDocument] mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
		[[[self siteOutlineController] selection] setValue:thumbnail forKey:@"thumbnail"];
	}
	else if (anImageView == oFaviconImageView)
	{
		KTMediaContainer *favicon = [[[self associatedDocument] mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
		[[[self selectedLevel] master] setFavicon:favicon];
	}
}

#pragma mark view management

- (void)putContentInWindow;
{
	[oInfoWindowController setContent:self];
	[[self window] makeFirstResponder:nil];	// possible bug avoidance, see http://www.cocoabuilder.com/archive/message/cocoa/2005/5/22/136648
	[[self window] setContentView:oStackView];
	[oStackView reloadSubviews];
	[self adjustWindow];
}

#pragma mark Google



#pragma mark accessors

/*
- (NSMutableSet *)currentlyBoundControllers
{
    return myCurrentlyBoundControllers; 
}

- (void)setCurrentlyBoundControllers:(NSMutableSet *)aCurrentlyBoundControllers
{
	// Unbind any and all controllers that are bound to something
	if (nil != myCurrentlyBoundControllers)
	{
		NSEnumerator *theEnum = [myCurrentlyBoundControllers objectEnumerator];
		NSObjectController *controller;
		
		while (nil != (controller = [theEnum nextObject]) )
		{
			[controller setContent:nil];
		}
	}
	// Now we can replace the usual way
    [aCurrentlyBoundControllers retain];
    [myCurrentlyBoundControllers release];
    myCurrentlyBoundControllers = aCurrentlyBoundControllers;
}
*/

- (BOOL)preventWindowAnimation
{
    return myPreventWindowAnimation;
}

- (void)setPreventWindowAnimation:(BOOL)flag
{
    myPreventWindowAnimation = flag;
}

- (BOOL)disclosedPreset
{
    return myDisclosedPreset;
}

- (void)setDisclosedPreset:(BOOL)flag
{
    myDisclosedPreset = flag;
	[oStackView reloadSubviews];
	[self adjustWindow];
}

/*!	use this, not document, to get the document we are talking about
*/
- (KTDocument *)associatedDocument
{
    return myAssociatedDocument;
}

- (void)setAssociatedDocument:(KTDocument *)aDocument
{
//    [aDocument retain];
//    [myAssociatedDocument release];
    myAssociatedDocument = aDocument;
}

- (NSManagedObjectContext *)currentManagedObjectContext
{
	NSManagedObjectContext *result = nil;
	
	if ( (nil != myCurrentSelection) && [myCurrentSelection respondsToSelector:@selector(managedObjectContext)] )
	{
		result = [myCurrentSelection managedObjectContext];
	}
	
	if ( (nil == result) && (nil != myAssociatedDocument) )
	{
		result = [myAssociatedDocument managedObjectContext];
	}
	
	if ( nil == result )
	{
		NSLog(@"error: infoWindowController's managedObjectContext is nil!");
	}
	
	return result;
}

- (id)currentSelection
{
    return myCurrentSelection; 
}

- (void)setCurrentSelection:(id)aCurrentSelection
{
    [aCurrentSelection retain];
    [myCurrentSelection release];
    myCurrentSelection = aCurrentSelection;
}

- (int)customFileExtension
{
    return myCustomFileExtension;
}

- (BOOL)quartzExtremeCapable
{
	return CGDisplayUsesOpenGLAcceleration(kCGDirectMainDisplay);
}

- (void)setCustomFileExtension:(int)aCustomFileExtension
{
    myCustomFileExtension = aCustomFileExtension;
}

- (KTPage *)selectedLevel
{
    return mySelectedLevel; 
}

- (void)setSelectedLevel:(KTPage *)aSelectedLevel
{
    [aSelectedLevel retain];
    [mySelectedLevel release];
    mySelectedLevel = aSelectedLevel;
}

- (KTPagelet *)selectedPagelet
{
    return mySelectedPagelet; 
}

- (void)setSelectedPagelet:(KTPagelet *)aSelectedPagelet
{
    [aSelectedPagelet retain];
    [mySelectedPagelet release];
    mySelectedPagelet = aSelectedPagelet;
//	LOG((@"selectedPagelet set to %@", [mySelectedPagelet managedObjectDescription]));
}

- (int)pageletPositionNumber
{
    return myPageletPositionNumber;
}

- (void)setPageletPositionNumber:(int)aPageletPositionNumber
{
    myPageletPositionNumber = aPageletPositionNumber;
	LOG((@"setPageletPositionNumber:%d", aPageletPositionNumber));
}

- (int)selectedSegmentIndex
{
    return mySelectedSegmentIndex;
}

- (void)setSelectedSegmentIndex:(int)aSelectedSegmentIndex
{
	mySelectedSegmentIndex = aSelectedSegmentIndex;
	[oTabSegmentedControl setSelectedSegment:aSelectedSegmentIndex];	// we use bindings, but we need to have this set explicitly so that loadSubViews gets the right value?

#ifdef DEBUG
	if (SEGMENT_SITE == aSelectedSegmentIndex)
	{
		// DEVELOPMENT ONLY AT THIS POINT, NOT MAKING LIVE
		if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
		{
			[oTabSegmentedControl setLabel:NSLocalizedString(@"Level",@"Segment Label, indicating that we are inspecting the current level, not the whole site") forSegment:SEGMENT_SITE];
			//// NOOO ... co-recursion!  [self setupViewStackFor:myCurrentSelection selectLevel:YES];
		}
		else	// regular
		{
			[oTabSegmentedControl setLabel:NSLocalizedString(@"Site",@"Segment Label, indicating that we are inspecting the whole site") forSegment:SEGMENT_SITE];
			//// NOOO ... co-recursion!  [self setupViewStackFor:myCurrentSelection selectLevel:NO];
		}
	}
	else
	{
		[oTabSegmentedControl setLabel:NSLocalizedString(@"Site",@"Segment Label, indicating that we are inspecting the whole site") forSegment:SEGMENT_SITE];
		//// NOOO ... co-recursion!  [self setupViewStackFor:myCurrentSelection selectLevel:NO];		// go back to site if switching to another
	}
#endif
	//	NSLog(@"setSelectedSegmentIndex:%d", aSelectedSegmentIndex);
	[oStackView reloadSubviews];
	[self adjustWindow];
}

/*!	Inspector for selection -- pagelet, inline image, etc.
*/
- (NSView *)selectionInspectorView
{
    return mySelectionInspectorView; 
}

- (void)setSelectionInspectorView:(NSView *)aSelectionInspectorView
{
    [aSelectionInspectorView retain];
    [mySelectionInspectorView release];
    mySelectionInspectorView = aSelectionInspectorView;
}


- (NSView *)pageInspectorView
{
    return myPageInspectorView; 
}

- (void)setPageInspectorView:(NSView *)aPageInspectorView
{
    [aPageInspectorView retain];
    [myPageInspectorView release];
    myPageInspectorView = aPageInspectorView;
}

#pragma mark -
#pragma mark Delegate

- (void)windowDidMove:(NSNotification *)aNotification
{
	id obj = [aNotification object];

	NSRect frame = [obj frame];
	NSPoint topLeft = NSMakePoint(frame.origin.x, frame.origin.y+frame.size.height);
	NSString *topLeftAsString = NSStringFromPoint(topLeft);
	[[NSUserDefaults standardUserDefaults] setObject:topLeftAsString forKey:gInfoWindowAutoSaveName];
}


#pragma mark -
#pragma mark KVO

- (void)updateCollectionStylePopup;
{
	NSMenuItem *menuItem = nil;
	
	// Note: dictionary equality is really picky about whether it's a CFNumber or CFBoolean so this tries to match them.
	KTPage *page = [[self siteOutlineController] selectedPage];
	NSDictionary *dictToMatch = [NSDictionary dictionaryWithObjectsAndKeys: 
		[NSNumber numberWithBool:[page boolForKey:@"collectionShowNavigationArrows"]], @"collectionShowNavigationArrows",
		[page valueForKey:@"collectionMaxIndexItems"], @"collectionMaxIndexItems",
		[page valueForKey:@"collectionSortOrder"], @"collectionSortOrder",
		[NSNumber numberWithBool:[page boolForKey:@"collectionSyndicate"]], @"collectionSyndicate",
		[NSNumber numberWithBool:[page boolForKey:@"collectionShowPermanentLink"]], @"collectionShowPermanentLink",
		[NSNumber numberWithBool:[page boolForKey:@"collectionHyperlinkPageTitles"]], @"collectionHyperlinkPageTitles",
		[page valueForKey:@"collectionSummaryType"], @"collectionSummaryType",
		nil];


	NSString *indexIdentifier = [page valueForKey:@"collectionIndexBundleIdentifier"];
	if (indexIdentifier)
	{
		NSEnumerator *menuEnumerator = [[oCollectionStylePopup itemArray] objectEnumerator];
		NSMenuItem *aMenuItem;
		while (aMenuItem = [menuEnumerator nextObject])
		{
			NSDictionary *aPreset = [aMenuItem representedObject];
			if (!aPreset) continue;		// Ignore non-preset menu items
			
			
			NSString *anIndexIdentifier = [aPreset objectForKey:@"KTPresetIndexBundleIdentifier"];
			if ([anIndexIdentifier isEqualToString:indexIdentifier])	// They have the same index. Possible match
			{
				NSDictionary *pageSettings = [aPreset objectForKey:@"KTPageSettings"];
				if ([dictToMatch isEqualToDictionary:pageSettings])
				{
					menuItem = aMenuItem;
					break;
				}
			}
		}
	}
	else
	{
		// Special case, the user selected "No Index"
		menuItem = [oCollectionStylePopup itemAtIndex:0];
	}
	
	// Select the right menu item
	if (menuItem)
	{
		[oCollectionStylePopup selectItem:menuItem];
	}
	else
	{
		[oCollectionStylePopup selectItemWithTag:CUSTOM_TAG];
	}
}


- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
    if ( !myIgnoreCollectionStyleChanges
		 && ![[self siteOutlineController] selectedPage]
		 && [aKeyPath isEqualToString:@"selection.indexPresetDictionary"] )
    {
		[self updateCollectionStylePopup];
    }
}

#pragma mark undo

/*! returns undoManaged of associatedDocument */
- (NSUndoManager *)undoManager
{
    return [[self associatedDocument] undoManager];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	if (window == [self window])
	{
		return [self undoManager];
	}
	else
	{
		return [window undoManager];
	}
}

#pragma mark -
#pragma mark Help

// TODO: -- replace with actual state and selection
- (IBAction) windowHelp:(id)sender
{
	NSString *pageName = @"The_Inspector";	// fallback		// HELPSTRING -- MANY BELOW
	
	switch ([oTabSegmentedControl selectedSegment])
	{
		case SEGMENT_SITE:
		{
			pageName = @"Site_Inspector";		// fallback 	// HELPSTRING
			id whichSiteTab = [[oSiteTabView selectedTabViewItem] identifier];
			if ([whichSiteTab isEqual:@"properties"])
			{
				pageName = @"Site_Properties";	// HELPSTRING
			}
			else if ([whichSiteTab isEqual:@"properties"])
			{
				pageName = @"Site_Media";				// HELPSTRING	
			}
			else if ([whichSiteTab isEqual:@"google"])
			{
				pageName = @"Google_Integration";	// HELPSTRING
			}
			break;
		}
		case SEGMENT_PAGE:
			pageName = @"General_Page_Attributes";	// HELPSTRING
			if ([[[self siteOutlineController] selectedPage] isCollection])
			{
				pageName = @"Collection";	// HELPSTRING
			}
			if (nil != myPageInspectorView)	// special inspector IF there is a specialized inspector below.
			{	
				NSString *helpAnchor = [[[[[self siteOutlineController] selectedPage] plugin] bundle] helpAnchor];
				if (nil != helpAnchor)
				{
					pageName = helpAnchor;
				}
			}
			break;
		case SEGMENT_SELECTION:
		{
			if ([myCurrentSelection isKindOfClass:[KTPagelet class]])
			{
				pageName = @"General_Pagelet_Attributes";	// fallback 	// HELPSTRING
				NSString *helpAnchor = [[[(KTPagelet *)myCurrentSelection plugin] bundle] helpAnchor];
				if (nil != helpAnchor)
				{
					pageName = helpAnchor;
				}
			}
			else	// page or pseudo element
			{
				if ([myCurrentSelection isKindOfClass:[KTPseudoElement class]])
				{
					pageName = @"Embedded_Image";	// HELPSTRING
				}
				else if (nil != myPageInspectorView && [[[self siteOutlineController] selectedPage] separateInspectorSegment])
				{
					if (oProRequiredView == myPageInspectorView)
					{
						pageName = @"Sandvox_Pro";	// HELPSTRING
					}
					else
					{
						NSString *identifier = [myCurrentSelection wrappedValueForKey:@"pluginIdentifier"];
						if ([identifier isEqualToString:@"sandvox.ImageElement"])
						{
							pageName = @"Photo";	// HELPSTRING
						}
					}
				}
				else
				{
					;
				}
			}
			break;
		}
	}
	[[NSApp delegate] showHelpPage:pageName];	
}

#pragma mark -
#pragma mark Support

/*	Convenience method to get to the inspected site outline controller quickly.
 */
- (KTDocSiteOutlineController *)siteOutlineController
{
	return [[[self associatedDocument] windowController] siteOutlineController];
}

@end
