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
	
	
	// Meta description field needs the right font
	NSFont *font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
	[oMetaDescriptionField setFont:font];
	
	
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

/*	The countdown is typed as NSNumber, but since this is for bindings, it could also be a placeholder
 *  such as NSMultipleValuesMarker.
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
	
	// black under MAX_META_DESCRIPTION_LENGTH - META_DESCRIPTION_WARNING_ZONE,
	// then progressively more red until MAX_META_DESCRIPTION_LENGTH and beyond
	int howBad = META_DESCRIPTION_WARNING_ZONE - [[self metaDescriptionCountdown] intValue];
	howBad = MAX(howBad, 0);
	howBad = MIN(howBad, META_DESCRIPTION_WARNING_ZONE);
	float howRed = 0.1 * howBad;
	
	//	NSLog(@"%d make it %.2f red", len, howRed);
	
	result = [[NSColor grayColor] blendedColorWithFraction:howRed ofColor:[NSColor redColor]];
	
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
- (void)textDidChange:(NSNotification *)aNotification
{
	NSText *text = [aNotification object];	OBASSERT(text);
	NSString *newMetaDescription = [text string]; // Do NOT try to modify this string!
	[self metaDescriptionDidChangeToValue:newMetaDescription];
}
 
@end
