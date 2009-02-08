//
//  KTPageDetailsController.m
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTPageDetailsController.h"

#import "KSPopUpButton.h"
#import "KSValidateCharFormatter.h"

#import "NTBoxView.h"

#import "NSCharacterSet+Karelia.h"
#import "NSObject+Karelia.h"

#import "KTPageDetailsBoxView.h"
#import <iMediaBrowser/RBSplitView.h>

static NSString *sMetaDescriptionObservationContext = @"-metaDescription observation context";


@interface KTPageDetailsController (Private)
- (void)metaDescriptionDidChangeToValue:(id)value;
@end


#pragma mark -


@implementation KTPageDetailsController

#pragma mark -
#pragma mark Init & Dealloc

+ (void)initialize
{
	[self setKey:@"metaDescriptionCountdown" triggersChangeNotificationsForDependentKey:@"metaDescriptionCharCountColor"];
}
	
- (void)dealloc
{
	[_metaDescriptionCountdown release];
	[super dealloc];
}

#pragma mark -
#pragma mark View

- (void)setView:(NSView *)aView
{
	if (aView) OBPRECONDITION([aView isKindOfClass:[NTBoxView class]]);
	
	// Remove observers
	if (!aView)
	{
		[oPagesController removeObserver:self forKeyPath:@"selection.metaDescription"];
	}
	
	[super setView:aView];
}

- (NTBoxView *)pageDetailsPanel
{
	return (NTBoxView *)[self view];
}

#pragma mark -
#pragma mark Appearance

- (void)awakeFromNib
{
	// Detail panel needs the right appearance
	[[self pageDetailsPanel] setDrawsFrame:YES];
	[[self pageDetailsPanel] setBorderMask:(NTBoxRight | NTBoxBottom)];
	
	
	// Observe changes to the meta description and fake an initial observation
	[oPagesController addObserver:self
					   forKeyPath:@"selection.metaDescription"
						  options:NSKeyValueObservingOptionNew
						  context:sMetaDescriptionObservationContext];
	[self metaDescriptionDidChangeToValue:[oPagesController valueForKeyPath:@"selection.metaDescription"]];
	
	
	/// turn off undo within the cell to avoid exception
	/// -[NSBigMutableString substringWithRange:] called with out-of-bounds range
	/// this still leaves the setting of keywords for the page undo'able, it's
	/// just now that typing inside the field is now not undoable
	[[oKeywordsField cell] setAllowsUndo:NO];
	
	
	// Limit entry in file name fields
	NSCharacterSet *illegalCharSetForPageTitles = [[NSCharacterSet legalPageTitleCharacterSet] invertedSet];
	NSFormatter *formatter = [[[KSValidateCharFormatter alloc]
							   initWithIllegalCharacterSet:illegalCharSetForPageTitles] autorelease];
	[oPageFileNameField setFormatter:formatter];
	[oCollectionFileNameField setFormatter:formatter];
	
	
	// Prepare the collection index.html popup
	[oCollectionIndexExtensionButton bind:@"defaultValue"
								 toObject:oPagesController
							  withKeyPath:@"selection.defaultIndexFileName"
								  options:nil];
	
	[oCollectionIndexExtensionButton setMenuTitle:NSLocalizedString(@"Index file name",
																	"Popup menu title for setting the index.html file's extensions")];
	
	[oFileExtensionPopup bind:@"defaultValue"
					 toObject:oPagesController
				  withKeyPath:@"selection.defaultFileExtension"
					  options:nil];
}

#pragma mark -
#pragma mark Meta Description

/*  This code manages the meta description field in the Page Details panel. It's a tad complicated,
 *  so here's how it works:
 *
 *  For the really simple stuff, you can bind directly to the object controller responsible for the
 *  Site Outline selection. i.e. The meta description field is bound this way. Its contents are
 *  saved back to the model ater the user ends editing
 *
 *  To complicate matters, we have a countdown label. This is derived from whatever is currently
 *  entered into the description field. It does NOT map directly to what is in the model. The
 *  countdown label is bound directly to the -metaDescriptionCountdown property of
 *  KTPageDetailsController. To update the GUI, you need to call -setMetaDescriptionCountdown:
 *  This property is an NSNumber as it needs to return NSMultipleValuesMarker sometimes. We update
 *  the countdown in response to either:
 *
 *      A)  The selection/model changing. This is detected by observing the Site Outline controller's
 *          selection.metaDescription property
 *      B)  The user editing the meta description field. This is detected through NSControl's
 *          delegate methods. We do NOT store these changes into the model immediately as this would
 *          conflict with the user's expectations of how undo/redo should work.
 */

- (NSNumber *)metaDescriptionCountdown { return _metaDescriptionCountdown; }

- (void)setMetaDescriptionCountdown:(NSNumber *)countdown
{
	[countdown retain];
	[_metaDescriptionCountdown release];
	_metaDescriptionCountdown = countdown;
}

#define MAX_META_DESCRIPTION_LENGTH 156

/*	Called in response to a change of selection.metaDescription or the user typing
 *	We update our own countdown property in response
 */
- (void)metaDescriptionDidChangeToValue:(id)value
{
	if (value)
	{
		if ([value isSelectionMarker])
		{
			value = nil;
		}
		else
		{
			OBASSERT([value isKindOfClass:[NSString class]]);
			value = [NSNumber numberWithInt:(MAX_META_DESCRIPTION_LENGTH - [value length])];
		}
	}
	else
	{
		value = [NSNumber numberWithInt:MAX_META_DESCRIPTION_LENGTH];
	}
	
	[self setMetaDescriptionCountdown:value];
}

#define META_DESCRIPTION_WARNING_ZONE 10
- (NSColor *)metaDescriptionCharCountColor
{
	NSColor *result = nil;
	
	int remaining = [[self metaDescriptionCountdown] intValue];

	if (remaining > META_DESCRIPTION_WARNING_ZONE * 3 )
	{
		result = [NSColor clearColor];
	}
	else if (remaining > META_DESCRIPTION_WARNING_ZONE * 2 )
	{
		float howGray = (float) ( remaining - (META_DESCRIPTION_WARNING_ZONE * 2) ) / META_DESCRIPTION_WARNING_ZONE;
		result = [[NSColor grayColor] blendedColorWithFraction:howGray ofColor:[NSColor clearColor]];
	}
	else
	{
		// black under MAX_META_DESCRIPTION_LENGTH - META_DESCRIPTION_WARNING_ZONE,
		// then progressively more red until MAX_META_DESCRIPTION_LENGTH and beyond
		int howBad = META_DESCRIPTION_WARNING_ZONE - remaining;
		howBad = MAX(howBad, 0);
		howBad = MIN(howBad, META_DESCRIPTION_WARNING_ZONE);
		float howRed = 0.1 * howBad;
		
		//	NSLog(@"%d make it %.2f red", len, howRed);
		
		result = [[NSColor grayColor] blendedColorWithFraction:howRed ofColor:[NSColor redColor]];
	}
	
	return result;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == sMetaDescriptionObservationContext)
	{
		[self metaDescriptionDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

/*	Sent when the user is typing in the meta description box.
 */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSString *newMetaDescription = [(NSTextField *)[aNotification object] stringValue]; // Do NOT try to modify this string!
	[self metaDescriptionDidChangeToValue:newMetaDescription];
}

#pragma mark -
#pragma mark RBSplitView delegate methods

- (void)didAdjustSubviews:(RBSplitView*)sender;
{
	[oBoxView rebindSubviewPlaceholdersAccordingToSize];
}

- (BOOL)splitView:(RBSplitView*)sender shouldHandleEvent:(NSEvent*)theEvent inDivider:(unsigned int)divider betweenView:(RBSplitSubview*)leading andView:(RBSplitSubview*)trailing;
{
	[RBSplitView setCursor:RBSVDragCursor toCursor:[NSCursor resizeUpDownCursor]];
	return YES;
}

@end
