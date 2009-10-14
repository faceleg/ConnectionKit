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
static NSString *sWindowTitleObservationContext = @"-windowTitle observation context";
static NSString *sTitleTextObservationContext = @"-titleText observation context";


@interface KTPageDetailsController ()
- (void)metaDescriptionDidChangeToValue:(id)value;
- (void)windowTitleDidChangeToValue:(id)value;
- (void) resetPlaceholderToComboTitleText:(NSString *)comboTitleText;
@end


#pragma mark -


@implementation KTPageDetailsController

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
	[_metaDescriptionCountdown release];
	[_windowTitleCountdown release];
	[super dealloc];
}

#pragma mark -
#pragma mark View

- (void)setView:(NSView *)aView
{	
	// Remove observers
	if (!aView)
	{
		[oPagesController removeObserver:self forKeyPath:@"selection.metaDescription"];
		[oPagesController removeObserver:self forKeyPath:@"selection.windowTitle"];
	}
	
	[super setView:aView];
}

#pragma mark -
#pragma mark Appearance

- (void)awakeFromNib
{
	// Detail panel needs the right appearance
	
	
	// Observe changes to the meta description and fake an initial observation
	[oPagesController addObserver:self
					   forKeyPath:@"selection.metaDescription"
						  options:NSKeyValueObservingOptionNew
						  context:sMetaDescriptionObservationContext];
	[self metaDescriptionDidChangeToValue:[oPagesController valueForKeyPath:@"selection.metaDescription"]];
	[oPagesController addObserver:self
					   forKeyPath:@"selection.windowTitle"
						  options:NSKeyValueObservingOptionNew
						  context:sWindowTitleObservationContext];
	[self windowTitleDidChangeToValue:[oPagesController valueForKeyPath:@"selection.windowTitle"]];

	[oPagesController addObserver:self
					   forKeyPath:@"selection.titleText"
						  options:NSKeyValueObservingOptionNew
						  context:sTitleTextObservationContext];
	[self resetPlaceholderToComboTitleText:[oPagesController valueForKeyPath:@"selection.comboTitleText"]];
	
	
	
	/// turn off undo within the cell to avoid exception
	/// -[NSBigMutableString substringWithRange:] called with out-of-bounds range
	/// this still leaves the setting of keywords for the page undo'able, it's
	/// just now that typing inside the field is now not undoable
	//[[oKeywordsField cell] setAllowsUndo:NO];
	
	
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
 *
 * This countdown behavior is reflected similarly with the windowTitle property.
 */

- (NSNumber *)metaDescriptionCountdown { return _metaDescriptionCountdown; }

- (void)setMetaDescriptionCountdown:(NSNumber *)countdown
{
	[countdown retain];
	[_metaDescriptionCountdown release];
	_metaDescriptionCountdown = countdown;
}

- (NSNumber *)windowTitleCountdown { return _windowTitleCountdown; }

- (void)setWindowTitleCountdown:(NSNumber *)countdown
{
	[countdown retain];
	[_windowTitleCountdown release];
	_windowTitleCountdown = countdown;
}


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
			value = [NSNumber numberWithInt:[value length]];
		}
	}
	else
	{
		value = [NSNumber numberWithInt:0];
	}
	
	[self setMetaDescriptionCountdown:value];
}

#define META_DESCRIPTION_WARNING_ZONE 10
#define MAX_META_DESCRIPTION_LENGTH 156

- (NSColor *)metaDescriptionCharCountColor
{
	int charCount = [[self metaDescriptionCountdown] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
	int remaining = MAX_META_DESCRIPTION_LENGTH - charCount;
	
	if (0 == charCount)
	{
		result = [NSColor clearColor];
	}
	else if (remaining > META_DESCRIPTION_WARNING_ZONE )		// out of warning zone: a nice light gray
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / META_DESCRIPTION_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default gray
	}
	else		// overflow: pure red.
	{
		result = [NSColor redColor];
	}	
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingMetaDescriptionCharCountColor
{
    return [NSSet setWithObject:@"metaDescriptionCountdown"];
}

- (void) resetPlaceholderToComboTitleText:(NSString *)comboTitleText
{
	NSDictionary *infoForBinding;
	NSDictionary *bindingOptions;
	NSString *bindingKeyPath;
	id observedObject;
			
	// The Window Title field ... re-bind the null placeholder.
		
	infoForBinding	= [oWindowTitleField infoForBinding:NSValueBinding];
	bindingOptions	= [[[infoForBinding valueForKey:NSOptionsKey] retain] autorelease];
	bindingKeyPath	= [[[infoForBinding valueForKey:NSObservedKeyPathKey] retain] autorelease];
	observedObject	= [[[infoForBinding valueForKey:NSObservedObjectKey] retain] autorelease];
	
	if (![[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] isEqualToString:comboTitleText])
	{
		NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
		
		// FIXME: BREAKING HERE
		// [newBindingOptions setObject:comboTitleText forKey:NSNullPlaceholderBindingOption];
		
		[oWindowTitleField unbind:NSValueBinding];

		// FIXME: BREAKING HERE
		// [oWindowTitleField bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
	}
}

/*	Called in response to a change of selection.windowTitle or the user typing
 *	We update our own countdown property in response
 */
- (void)windowTitleDidChangeToValue:(id)value
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
			value = [NSNumber numberWithInt:[value length]];
		}
	}
	else
	{
		value = [NSNumber numberWithInt:0];
	}
	
	[self setWindowTitleCountdown:value];
}

#define MAX_WINDOW_TITLE_LENGTH 65
#define WINDOW_TITLE_WARNING_ZONE 8
- (NSColor *)windowTitleCharCountColor
{
	int charCount = [[self windowTitleCountdown] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
	int remaining = MAX_WINDOW_TITLE_LENGTH - charCount;
	
	if (0 == charCount)
	{
		result = [NSColor clearColor];
	}
	else if (remaining > WINDOW_TITLE_WARNING_ZONE )		// out of warning zone: a nice light gray
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / WINDOW_TITLE_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default gray
	}
	else		// overflow: pure red.
	{
		result = [NSColor redColor];
	}	
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingWindowTitleCharCountColor
{
    return [NSSet setWithObject:@"windowTitleCountdown"];
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == sMetaDescriptionObservationContext)
	{
		[self metaDescriptionDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else if (context == sWindowTitleObservationContext)
	{
		[self windowTitleDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else if (context == sTitleTextObservationContext)
	{
		[self resetPlaceholderToComboTitleText:[object valueForKeyPath:@"selection.comboTitleText"]];	// go ahead and get the combo title
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
	NSTextField *textField = (NSTextField *) [aNotification object];
	NSString *newValue = [textField stringValue]; // Do NOT try to modify this string!
	if (textField == oWindowTitleField)
	{
		[self windowTitleDidChangeToValue:newValue];
	}
	else if (textField == oMetaDescriptionField)
	{
		[self metaDescriptionDidChangeToValue:newValue];
	}
}


@end
