//
//  KTPageDetailsController.m
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "KTPageDetailsController.h"

#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "SVDownloadSiteItem.h"
#import "SVMediaRecord.h"
#import "SVMediaProtocol.h"
#import "SVPagesController.h"
#import "SVSiteOutlineViewController.h"
#import "SVURLPreviewViewController.h"

#import "KSFocusingTextField.h"
#import "KSPopUpButton.h"
#import "KSShadowedRectView.h"
#import "KSURLFormatter.h"
#import "KSValidateCharFormatter.h"

#import "BDAlias.h"
#import "MAAttachedWindow.h"
#import "NTBoxView.h"

#import "NSCharacterSet+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import <QuartzCore/QuartzCore.h>


static NSString *sMetaDescriptionObservationContext = @"-metaDescription observation context";
static NSString *sWindowTitleObservationContext = @"-windowTitle observation context";
static NSString *sFileNameObservationContext = @"-fileName observation context";
static NSString *sBaseExampleURLStringObservationContext = @"-baseExampleURLString observation context";
static NSString *sSelectedObjectsObservationContext = @"-selectedObjects observation context";
static NSString *sSelectedViewControllerObservationContext = @"-selectedViewController observation context";
static NSString *sCharacterDescription0Count = nil;
static NSString *sCharacterDescription1Count = nil;
static NSString *sCharacterDescriptionPluralCountFormat = nil;

#define ATTACHED_WINDOW_TRANSP 0.6

enum { kUnknownPageDetailsContext, kFileNamePageDetailsContext, kWindowTitlePageDetailsContext, kMetaDescriptionPageDetailsContext
};

@interface KTPageDetailsController ()
- (void)metaDescriptionDidChangeToValue:(id)value;
- (void)windowTitleDidChangeToValue:(id)value;
- (void)fileNameDidChangeToValue:(id)value;
- (void) resetDescriptionPlaceholder:(NSString *)metaDescriptionText;
- (void) layoutPageURLComponents;
- (NSColor *)metaDescriptionCharCountColor;
- (NSColor *)windowTitleCharCountColor;
- (NSColor *)fileNameCharCountColor;
- (void) updateFieldsBasedOnSelectedSiteOutlineObjects:(NSArray *)selObjects;
- (void)updateWidthForActiveTextField:(NSTextField *)textField;
- (void) rebindWindowTitleAndMetaDescriptionFields;
@end


#pragma mark -


@implementation KTPageDetailsController

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	sCharacterDescription0Count = NSLocalizedString(@"0 characters", @"format string for showing that ZERO characters have been typed");
	sCharacterDescription1Count = NSLocalizedString(@"1 character", @"format string for showing that ONE character has been typed");
	sCharacterDescriptionPluralCountFormat = NSLocalizedString(@"%d characters", @"format string for showing how many characters have been typed");

	[pool release];
}

@synthesize activeTextField = _activeTextField;
@synthesize attachedWindow = _attachedWindow;
@synthesize whatKindOfItemsAreSelected = _whatKindOfItemsAreSelected;
@synthesize initialWindowTitleBindingOptions = _initialWindowTitleBindingOptions;
@synthesize initialMetaDescriptionBindingOptions = _initialMetaDescriptionBindingOptions;

@synthesize windowTitleTrackingArea		= _windowTitleTrackingArea;
@synthesize metaDescriptionTrackingArea = _metaDescriptionTrackingArea;
@synthesize externalURLTrackingArea		= _externalURLTrackingArea;
@synthesize fileNameTrackingArea		= _fileNameTrackingArea;
@synthesize mediaFilenameTrackingArea	= _mediaFilenameTrackingArea;

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSViewBoundsDidChangeNotification
												  object:[self view]];
    
    self.view = nil;		// stop observing early.
    self.webContentAreaController = nil;
	
	self.activeTextField = nil;
	[_metaDescriptionCount release];
	[_windowTitleCount release];
	[_fileNameCount release];
	self.initialWindowTitleBindingOptions = nil;
	self.initialMetaDescriptionBindingOptions = nil;
	
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
		[oPagesController removeObserver:self forKeyPath:@"selection.fileName"];
        [oPagesController removeObserver:self forKeyPath:@"selection.filename"];    // 101628
		[oPagesController removeObserver:self forKeyPath:@"selection.baseExampleURLString"];
		//[oPagesController removeObserver:self forKeyPath:@"selection.title"];
		[oPagesController removeObserver:self forKeyPath:@"selectedObjects"];

	}
	
	[super setView:aView];
}

@synthesize webContentAreaController = _contentArea;
- (void)setWebContentAreaController:(SVWebContentAreaController *)controller;
{
    [_contentArea removeObserver:self forKeyPath:@"selectedViewController"];
    
    [controller retain];
    [_contentArea release]; _contentArea = controller;
    
    [controller addObserver:self
                 forKeyPath:@"selectedViewController"
                    options:NSKeyValueObservingOptionNew
                    context:sSelectedViewControllerObservationContext];
}

#pragma mark -
#pragma mark Appearance

- (void)awakeFromNib
{
	if (!_awokenFromNib)
	{
		// Save these so we can restore them quickly when we are re-binding
		self.initialWindowTitleBindingOptions = [[oWindowTitleField infoForBinding:NSValueBinding] valueForKey:NSOptionsKey];
		self.initialMetaDescriptionBindingOptions = [[oMetaDescriptionField infoForBinding:NSValueBinding] valueForKey:NSOptionsKey];
		
		[oExternalURLField setFormatter:[[[KSURLFormatter alloc] init] autorelease]];
		
		// Detail panel needs the right appearance
		
		[[self view] setPostsFrameChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(backgroundFrameChanged:)
													 name:NSViewFrameDidChangeNotification
												   object:[self view]];

		[self layoutPageURLComponents];
		
		// Observe changes to the meta description and fake an initial observation
		[oPagesController addObserver:self
						   forKeyPath:@"selection.metaDescription"
							  options:NSKeyValueObservingOptionNew
							  context:sMetaDescriptionObservationContext];
		[self metaDescriptionDidChangeToValue:[oPagesController valueForKeyPath:@"selection.metaDescription"]];
		[self resetDescriptionPlaceholder:[oPagesController valueForKeyPath:@"selection.metaDescription"]];
		
		[oPagesController addObserver:self
						   forKeyPath:@"selection.windowTitle"
							  options:NSKeyValueObservingOptionNew
							  context:sWindowTitleObservationContext];
		[self windowTitleDidChangeToValue:[oPagesController valueForKeyPath:@"selection.windowTitle"]];
		[oPagesController addObserver:self
						   forKeyPath:@"selection.fileName"
							  options:NSKeyValueObservingOptionNew
							  context:sFileNameObservationContext];
		[oPagesController addObserver:self
						   forKeyPath:@"selection.filename"
							  options:NSKeyValueObservingOptionNew
							  context:sFileNameObservationContext];
		[self fileNameDidChangeToValue:[oPagesController valueForKeyPath:@"selection.fileName"]];	// pre-launch with which?
		
		[oPagesController addObserver:self
						   forKeyPath:@"selection.baseExampleURLString"
							  options:NSKeyValueObservingOptionNew
							  context:sBaseExampleURLStringObservationContext];

		[oPagesController addObserver:self
						   forKeyPath:@"selectedObjects"
							  options:NSKeyValueObservingOptionNew
							  context:sSelectedObjectsObservationContext];
		[self updateFieldsBasedOnSelectedSiteOutlineObjects:[oPagesController selectedObjects]];
		
		[self rebindWindowTitleAndMetaDescriptionFields];
		
		
		/// turn off undo within the cell to avoid exception
		/// -[NSBigMutableString substringWithRange:] called with out-of-bounds range
		/// this still leaves the setting of keywords for the page undo'able, it's
		/// just now that typing inside the field is now not undoable
		//[[oKeywordsField cell] setAllowsUndo:NO];
		
		
		// Limit entry in file name fields
		NSCharacterSet *illegalCharSetForPageTitles = [[NSCharacterSet legalPageTitleCharacterSet] invertedSet];
		NSFormatter *formatter = [[[KSValidateCharFormatter alloc]
								   initWithIllegalCharacterSet:illegalCharSetForPageTitles] autorelease];
		[oFileNameField setFormatter:formatter];
		[oMediaFilenameField setFormatter:formatter];

		[oExtensionPopup bind:@"defaultValue"
					 toObject:oPagesController
				  withKeyPath:@"selection.defaultFileExtension"
					  options:nil];
		// popup is bound to availablePathExtensions, selection is bound to customPathExtension.
        
		[oIndexAndExtensionPopup bind:@"defaultValue"
					 toObject:oPagesController
				  withKeyPath:@"selection.defaultIndexAndPathExtension"
					  options:nil];
		// popup is bound to availableIndexFilenames, selection is bound to customIndexAndPathExtension.
		
        
        _awokenFromNib = YES;
	}
}

#pragma mark -
#pragma mark Count fields

/*  This code manages the meta description field in the Page Details panel. It's a tad complicated,
 *  so here's how it works:
 *
 *  For the really simple stuff, you can bind directly to the object controller responsible for the
 *  Site Outline selection. i.e. The meta description field is bound this way. Its contents are
 *  saved back to the model ater the user ends editing
 *
 *  To complicate matters, we have a count label. This is derived from whatever is currently
 *  entered into the description field. It does NOT map directly to what is in the model. The
 *  count label is bound directly to the -metaDescriptionCount property of
 *  KTPageDetailsController. To update the GUI, you need to call -setMetaDescriptionCount:
 *  This property is an NSNumber as it needs to return NSMultipleValuesMarker sometimes. We update
 *  the count in response to either:
 *
 *      A)  The selection/model changing. This is detected by observing the Site Outline controller's
 *          selection.metaDescription property
 *      B)  The user editing the meta description field. This is detected through NSControl's
 *          delegate methods. We do NOT store these changes into the model immediately as this would
 *          conflict with the user's expectations of how undo/redo should work.
 *
 * This count behavior is reflected similarly with the windowTitle property.
 */

- (NSNumber *)metaDescriptionCount { return _metaDescriptionCount; }

- (void)setMetaDescriptionCount:(NSNumber *)count
{
	[count retain];
	[_metaDescriptionCount release];
	_metaDescriptionCount = count;
}

- (NSNumber *)windowTitleCount { return _windowTitleCount; }

- (void)setWindowTitleCount:(NSNumber *)count
{
	[count retain];
	[_windowTitleCount release];
	_windowTitleCount = count;
}

- (NSNumber *)fileNameCount { return _fileNameCount; }

- (void)setFileNameCount:(NSNumber *)count
{
	[count retain];
	[_fileNameCount release];
	_fileNameCount = count;
}

// Properly pluralizing character count strings

- (NSString *)metaDescriptionCountString
{
	int intValue = [self.metaDescriptionCount intValue];
	switch(intValue)
	{
		case 0:
			return sCharacterDescription0Count;
		case 1:
			return sCharacterDescription1Count;
		default:
			return [NSString stringWithFormat:sCharacterDescriptionPluralCountFormat, intValue];
	}
}

- (NSString *)fileNameCountString
{
	int intValue = [self.fileNameCount intValue];
	switch(intValue)
	{
		case 0:
			return sCharacterDescription0Count;
		case 1:
			return sCharacterDescription1Count;
		default:
			return [NSString stringWithFormat:sCharacterDescriptionPluralCountFormat, intValue];
	}
}

- (NSString *)windowTitleCountString
{
	int intValue = [self.windowTitleCount intValue];
	switch(intValue)
	{
		case 0:
			return sCharacterDescription0Count;
		case 1:
			return sCharacterDescription1Count;
		default:
			return [NSString stringWithFormat:sCharacterDescriptionPluralCountFormat, intValue];
	}
}

+ (NSSet *)keyPathsForValuesAffectingMetaDescriptionCountString
{
    return [NSSet setWithObject:@"metaDescriptionCount"];
}

+ (NSSet *)keyPathsForValuesAffectingFileNameCountString
{
    return [NSSet setWithObject:@"fileNameCount"];
}

+ (NSSet *)keyPathsForValuesAffectingWindowTitleCountString
{
    return [NSSet setWithObject:@"windowTitleCount"];
}


/*	Called in response to a change of selection.metaDescription or the user typing
 *	We update our own count property in response
 */
- (void)metaDescriptionDidChangeToValue:(id)value
{
	if (value)
	{
		if (NSIsControllerMarker(value))
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

	[self setMetaDescriptionCount:value];

	NSColor *windowColor = [self metaDescriptionCharCountColor];
	[self.attachedWindow setBackgroundColor:windowColor];

}

/*	Called in response to a change of selection.windowTitle or the user typing
 *	We update our own count property in response
 */
- (void)windowTitleDidChangeToValue:(id)value
{
	if (value)
	{
		if (NSIsControllerMarker(value))
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
	
	[self setWindowTitleCount:value];

	NSColor *windowColor = [self windowTitleCharCountColor];
	[self.attachedWindow setBackgroundColor:windowColor];
}

- (void)fileNameDidChangeToValue:(id)value
{
	if (value)
	{
		if (NSIsControllerMarker(value))
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
	
	[self setFileNameCount:value];

	NSColor *windowColor = [self fileNameCharCountColor];
	[self.attachedWindow setBackgroundColor:windowColor];
}


- (void) resetDescriptionPlaceholder:(NSString *)metaDescriptionText;
{
	NSDictionary *infoForBinding;
	NSDictionary *bindingOptions;
	NSString *bindingKeyPath;
	id observedObject;
	
	// The Meta description field ... re-bind the null placeholder.
	
	infoForBinding	= [oMetaDescriptionField infoForBinding:NSValueBinding];
	bindingOptions	= [[[infoForBinding valueForKey:NSOptionsKey] retain] autorelease];
	bindingKeyPath	= [[[infoForBinding valueForKey:NSObservedKeyPathKey] retain] autorelease];
	observedObject	= [[[infoForBinding valueForKey:NSObservedObjectKey] retain] autorelease];
	
	if ([observedObject respondsToSelector:@selector(selectedObjects)] && [[observedObject selectedObjects] count] > 1)
	{
		NSMutableDictionary *newBindingOptions = [NSMutableDictionary dictionaryWithDictionary:bindingOptions];
		
		// Move the multiple values placeholder to the null value, so that we see that when the values are empty
		[newBindingOptions setObject:[bindingOptions objectForKey:NSMultipleValuesPlaceholderBindingOption] forKey:NSNullPlaceholderBindingOption];
		
		[oMetaDescriptionField unbind:NSValueBinding];
		[oMetaDescriptionField bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
	}
}	

- (void) updateFieldsBasedOnSelectedSiteOutlineObjects:(NSArray *)selObjects;
{
	if (NSIsControllerMarker(selObjects))
	{
		NSLog(@"Controller marker:  %@", selObjects);
	}
	else
	{
		// Start with unknown, break and set to mixed if we find different types
		
		int combinedType = kUnknownSiteItemType;
		for (SVSiteItem *item in selObjects)
		{
			SVMediaRecord *media = nil;
			int type = kUnknownSiteItemType;
			if (nil != [item externalLinkRepresentation]) { type = kLinkSiteItemType; }
			else if (nil != (media =[item mediaRepresentation]))
			{
				type = kFileSiteItemType;
				// But now see if it's actually editable text
				if ([media isEditableText])
				{
					type = kTextSiteItemType;
				}
			}
			else if (nil != [item pageRepresentation]) type = kPageSiteItemType;
			
			if (kUnknownSiteItemType != combinedType && type != combinedType)
			{
				combinedType = kMixedSiteItemType;
				break;	// stop looking -- this is a combination of types
			}
			else
			{
				combinedType = type;	// keep looking, so far collecting a single type.
			}
		}
		char *typestrings[] =  { "kMixedSiteItemType", "kUnknownSiteItemType", "kLinkSiteItemType", "kTextSiteItemType", "kFileSiteItemType", "kPageSiteItemType" };
#pragma unused (typestrings)

		OFF((@"whatKindOfItemsAreSelected => %s", typestrings[combinedType+1]));
		self.whatKindOfItemsAreSelected = combinedType;
		
		[self layoutPageURLComponents];
	}
}


#pragma mark -
#pragma mark Count colors

#define META_DESCRIPTION_WARNING_ZONE 10
#define MAX_META_DESCRIPTION_LENGTH 156

- (NSColor *)metaDescriptionCharCountColor;
{
	int charCount = [[self metaDescriptionCount] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP];
	int remaining = MAX_META_DESCRIPTION_LENGTH - charCount;
	
	if (remaining > META_DESCRIPTION_WARNING_ZONE )		// out of warning zone: a nice HUD color
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / META_DESCRIPTION_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default black
	}
	else		// overflow: pure red.
	{
		result = [NSColor redColor];
	}	
	return result;
}


#define MAX_WINDOW_TITLE_LENGTH 65
#define WINDOW_TITLE_WARNING_ZONE 8
- (NSColor *)windowTitleCharCountColor
{
	int charCount = [[self windowTitleCount] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP];
	int remaining = MAX_WINDOW_TITLE_LENGTH - charCount;
	
	if (remaining > WINDOW_TITLE_WARNING_ZONE )		// out of warning zone: a nice light gray
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
#define FILE_NAME_WARNING_ZONE 5
- (NSColor *)fileNameCharCountColor
{
	int charCount = [[self fileNameCount] intValue];
	NSColor *result = [NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP];
	int remaining = _maxFileCharacters - charCount;
	
	if (remaining > FILE_NAME_WARNING_ZONE )		// out of warning zone: a nice light gray
	{
		;
	}
	else if (remaining >= 0 )							// get closer to black-red
	{
		float howRed = (float) remaining / WINDOW_TITLE_WARNING_ZONE;
		result = [[NSColor colorWithCalibratedRed:0.4 green:0.0 blue:0.0 alpha:1.0] blendedColorWithFraction:howRed ofColor:result];		// blend with default gray
	}
	else		// overflow: pure red.  Not actually possible here (theoretically)
	{
		result = [NSColor redColor];
	}	
	return result;
}


+ (NSSet *)keyPathsForValuesAffectingWindowTitleCharCountColor
{
    return [NSSet setWithObject:@"windowTitleCount"];
}

+ (NSSet *)keyPathsForValuesAffectingFileNameCharCountColor
{
    return [NSSet setWithObject:@"fileNameCount"];
}

+ (NSSet *)keyPathsForValuesAffectingMetaDescriptionCharCountColor
{
    return [NSSet setWithObject:@"metaDescriptionCount"];
}


#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
//	NSLog(@"object = %@", object);
	
	[self layoutPageURLComponents];

	if (context == sMetaDescriptionObservationContext)
	{
		[self metaDescriptionDidChangeToValue:[object valueForKeyPath:keyPath]];
		[self resetDescriptionPlaceholder:[object valueForKeyPath:@"selection.metaDescription"]];
	}
	else if (context == sWindowTitleObservationContext)
	{
		[self windowTitleDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else if (context == sFileNameObservationContext)
	{
		[self fileNameDidChangeToValue:[object valueForKeyPath:keyPath]];
	}
	else if (context == sBaseExampleURLStringObservationContext)
	{
		; // base URL changed, so re-layout
	}
	else if (context == sSelectedViewControllerObservationContext)
	{
		[self rebindWindowTitleAndMetaDescriptionFields];
	}
	else if (context == sSelectedObjectsObservationContext)
	{
		[self updateFieldsBasedOnSelectedSiteOutlineObjects:[object selectedObjects]];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark -
#pragma mark URL view layout

- (void) rebindWindowTitleAndMetaDescriptionFields;
{
	// Kind of hackish.  Re-bind the window title and meta description to the model object if it's a real page, or the controller if it's an external link.
	
	id selViewController = [[self webContentAreaController] selectedViewController];
	if ([selViewController isKindOfClass:[SVWebEditorViewController class]])
	{
		[oWindowTitleField unbind:NSValueBinding];
		[oWindowTitleField bind:NSValueBinding
					   toObject:oPagesController
					withKeyPath:@"selection.windowTitle"
						options:self.initialWindowTitleBindingOptions];
		
		[oMetaDescriptionField unbind:NSValueBinding];
		[oMetaDescriptionField bind:NSValueBinding
						   toObject:oPagesController
						withKeyPath:@"selection.metaDescription"
							options:self.initialMetaDescriptionBindingOptions];
		
		/*
		 NSObservedKeyPath = "selection.windowTitle";
		 NSObservedObject = <SVPagesController: 0x1c90cf0>[entity: Page, number of selected objects: 1];
		 NSOptions =     {
		 NSAllowsEditingMultipleValuesSelection = 1;
		 NSAlwaysPresentsApplicationModalAlerts = 0;
		 NSConditionallySetsEditable = 1;
		 NSConditionallySetsEnabled = 0;
		 NSConditionallySetsHidden = 0;
		 NSContinuouslyUpdatesValue = 0;
		 NSMultipleValuesPlaceholder = "Multiple pages selected. Titles should be unique.";
		 NSNoSelectionPlaceholder = "";
		 NSNotApplicablePlaceholder = "Not Applicable";
		 NSNullPlaceholder = "Home Page | Karelia Software";
		 NSRaisesForNotApplicableKeys = 0;
		 NSValidatesImmediately = 0;
		 NSValueTransformer = <null>;
		 NSValueTransformerName = <null>;
		 };
		 }
		 NSObservedKeyPath = "selection.metaDescription";
		 NSObservedObject = <SVPagesController: 0x1c90cf0>[entity: Page, number of selected objects: 1];
		 NSOptions =     {
		 NSAllowsEditingMultipleValuesSelection = 1;
		 NSAlwaysPresentsApplicationModalAlerts = 0;
		 NSConditionallySetsEditable = 1;
		 NSConditionallySetsEnabled = 0;
		 NSConditionallySetsHidden = 0;
		 NSContinuouslyUpdatesValue = 0;
		 NSMultipleValuesPlaceholder = "Multiple pages selected. Descriptions should be unique.";
		 NSNoSelectionPlaceholder = "";
		 NSNotApplicablePlaceholder = "Not Applicable";
		 NSNullPlaceholder = "Summary of this page as it will appear in Google listings.";
		 NSRaisesForNotApplicableKeys = 0;
		 NSValidatesImmediately = 0;
		 NSValueTransformer = <null>;
		 NSValueTransformerName = <null>;
		 };
		 */		 
	}
	else if ([selViewController isKindOfClass:[SVURLPreviewViewController class]])
	{
		[oWindowTitleField unbind:NSValueBinding];
		[oWindowTitleField bind:NSValueBinding
					   toObject:selViewController
					withKeyPath:@"title"
						options:nil];
		
		[oMetaDescriptionField unbind:NSValueBinding];
		[oMetaDescriptionField bind:NSValueBinding
						   toObject:selViewController
						withKeyPath:@"metaDescription"
							options:nil];
	}
}
	
/*
 Algorithm 
 Calculate how much each of the variable fields oBaseURLField and oPageFileNameField *want* to be
 Don't truncate oPageFileNameField - this is limited by character count and we want to see the whole thing
 So we will truncate oBaseURLField as much as we need.
 
 We also need to call this when the observed page changes.
 
 */

- (void) layoutPageURLComponents;
{
#define IS_ROOT_STATE -99
	// Only visible for page types
	// TODO: deal with downloads, where we keep the base URL but have a special field for the whole filename
	
	BOOL arePagesSelected = (kPageSiteItemType == self.whatKindOfItemsAreSelected); 
	BOOL areLinksSelected = (kLinkSiteItemType == self.whatKindOfItemsAreSelected);
	BOOL areFilesSelected = (kFileSiteItemType == self.whatKindOfItemsAreSelected);
	BOOL areTextsSelected = (kTextSiteItemType == self.whatKindOfItemsAreSelected);
	BOOL areMultiSelected = (kMixedSiteItemType == self.whatKindOfItemsAreSelected);

	int selectedObjectsCount = [[oPagesController selectedObjects] count];
	NSInteger pageIsCollectionState = NSMixedState;
	if (arePagesSelected)
	{
		pageIsCollectionState = [oPagesController selectedItemsAreCollections];

		// And also check if it's a root
		if (NSOnState == pageIsCollectionState)
		{
			id isRootMarker = [oPagesController valueForKeyPath:@"selection.isRoot"];
			if ([isRootMarker respondsToSelector:@selector(boolValue)] && [isRootMarker boolValue])
			{
				pageIsCollectionState =  IS_ROOT_STATE;		// special marker indicating root, and only root, is selected.
			}
		}
		
		BOOL anyArePublished = [oPagesController selectedItemsHaveBeenPublished];
				
		NSMenuItem *collMenuItem = [[oPublishAsCollectionPopup menu] itemWithTag:1];
		NSMenuItem *pageMenuItem = [[oPublishAsCollectionPopup menu] itemWithTag:0];

		NSString *pageTitle = nil;
		NSString *collTitle = nil;
		
		if (NSOnState == pageIsCollectionState || IS_ROOT_STATE == pageIsCollectionState)
		{
			collTitle = NSLocalizedString(@"Collection", "menu title");
			pageTitle = anyArePublished	? NSLocalizedString(@"Single Page…", "menu title with ellipses")
										 : NSLocalizedString(@"Single Page", "menu title, NO ellipses");
		}
		else if (NSOffState == pageIsCollectionState)
		{
			pageTitle = NSLocalizedString(@"Single Page", "menu title");
			collTitle = anyArePublished	? NSLocalizedString(@"Collection…", "menu title with ellipses")
										 : NSLocalizedString(@"Collection", "menu title, NO ellipses");
		}
		else	// mixed state, perhaps both or neither will get ellipses
		{
			pageTitle = anyArePublished	? NSLocalizedString(@"Single Page…", "menu title with ellipses")
										 : NSLocalizedString(@"Single Page", "menu title, NO ellipses");
			collTitle = anyArePublished	? NSLocalizedString(@"Collection…", "menu title with ellipses")
											   : NSLocalizedString(@"Collection", "menu title, NO ellipses");
		}
		[collMenuItem setTitle:collTitle];
		[pageMenuItem setTitle:pageTitle];
	}
	
	
	// Prompts
	[oWindowTitlePrompt		setHidden:!arePagesSelected && !areLinksSelected];
	[oMetaDescriptionPrompt	setHidden:!arePagesSelected && !areLinksSelected];
	[oFilePrompt setHidden:(!areFilesSelected && !areTextsSelected)];
	
	if (arePagesSelected || areLinksSelected)
	{
		if (!_metaDescriptionTrackingArea)
		{
			_metaDescriptionTrackingArea = [[NSTrackingArea alloc] initWithRect:[oMetaDescriptionField bounds]
															 options:
								 NSTrackingActiveInKeyWindow
								 | NSTrackingActiveInActiveApp
								 | NSTrackingInVisibleRect
								 | NSTrackingMouseEnteredAndExited
															   owner:self
															userInfo:nil];
			[oMetaDescriptionField addTrackingArea:_metaDescriptionTrackingArea];
		}
	}
	else if (_metaDescriptionTrackingArea)
	{
		[oMetaDescriptionField removeTrackingArea:_metaDescriptionTrackingArea];
		[_metaDescriptionTrackingArea release];
		_metaDescriptionTrackingArea = nil;

	}
	
	

	// Additional Lines
	[oWindowTitleField		setHidden:!arePagesSelected];
	[oMetaDescriptionField	setHidden:!arePagesSelected];
	[oWindowTitleField		setHidden:!arePagesSelected && !areLinksSelected];
	[oMetaDescriptionField	setHidden:!arePagesSelected && !areLinksSelected];
	[oWindowTitleField		setEditable:arePagesSelected];
	[oMetaDescriptionField	setEditable:arePagesSelected];
	[oChooseFileButton		setHidden:(!areFilesSelected && !areTextsSelected)];
	[oEditTextButton		setHidden:!areTextsSelected];

	// First line, external URL field
	[oExternalURLField setHidden:!areLinksSelected];

	// First line, complex pieces that make up the URL components
	BOOL hasLocalPath = (	arePagesSelected
						||	areTextsSelected
						||	areFilesSelected);
	
	[oBaseURLField setHidden:!hasLocalPath || selectedObjectsCount > 1];
	[oFileNameField setHidden:!arePagesSelected
							   || (arePagesSelected && IS_ROOT_STATE == pageIsCollectionState)
								|| selectedObjectsCount > 1];
	[oMediaFilenameField setHidden:(!areFilesSelected && !areTextsSelected) || selectedObjectsCount > 1];

	[oDotSeparator setHidden:(!arePagesSelected  || NSOffState != pageIsCollectionState || selectedObjectsCount > 1 || areMultiSelected)];
	[oSlashSeparator setHidden:!arePagesSelected || NSOnState != pageIsCollectionState || selectedObjectsCount > 1];

	[oMultiplePagesField setHidden: selectedObjectsCount == 1];
	
	[oExtensionPopup setHidden:!arePagesSelected  || NSOffState != pageIsCollectionState];
	[oIndexAndExtensionPopup setHidden:!arePagesSelected || (NSOnState != pageIsCollectionState && IS_ROOT_STATE != pageIsCollectionState)];
	
	[oPublishAsCollectionPopup setHidden: !arePagesSelected || NSMixedState == pageIsCollectionState];

	
	// Follow button only enabled when there is one item ?
	[oFollowButton setHidden: selectedObjectsCount != 1];
	
	if (areLinksSelected)
	{
		int newLeft = [oBaseURLField frame].origin.x;		// starting point for left of next item
		const int rightMargin = 20;
		int availableForAll = [[self view] bounds].size.width - rightMargin - newLeft - [oFollowButton frame].size.width - 8;
		NSRect frame = [oExternalURLField frame];
		frame.origin.x = newLeft;
		
		NSSize extURLSize = NSZeroSize;
		if (oExternalURLField == self.activeTextField)
		{
			NSTextView *fieldEditor = (NSTextView *)[self.activeTextField currentEditor];
			if (fieldEditor)
			{
				OBASSERT([fieldEditor isKindOfClass:[NSTextView class]]);
				extURLSize = [[fieldEditor textStorage] size];
			}
		}
		else
		{
			extURLSize = [[oExternalURLField attributedStringValue] size];
		}
        
		int width = ceilf(extURLSize.width)  + 3;
		if (width > availableForAll) width = availableForAll;	// make sure a really long URL will fit
		frame.size.width = width;
        
		[oExternalURLField setFrame:frame];

		// Move the follow button over
		frame = [oFollowButton frame];
		frame.origin.x = NSMaxX([oExternalURLField frame])+8;
		[oFollowButton setFrame:frame];
//		NSLog(@"set oFollowButton to %@", NSStringFromRect(frame));
	}
	else if (hasLocalPath || areMultiSelected)
	{
		NSArray *itemsToLayOut = nil;
		int *theExtraX = nil;
		int *theMarginsAfter = nil;
		
		NSArray *pageItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oFileNameField,oDotSeparator,oExtensionPopup,oFollowButton,oPublishAsCollectionPopup,nil];
		int pageExtraX [] = {4,5,6,8,0,0};
		int pageMarginsAfter[] = {0,-1,0,8,12,0};
		
		NSArray *collectionItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oFileNameField,oSlashSeparator,oIndexAndExtensionPopup,oFollowButton,oPublishAsCollectionPopup,nil];
		int collectionExtraX [] = {4,5,1,0,0,0};
		int collectionMarginsAfter[] = {0,-1,2,8,12,0};
		
		NSArray *markerItemsToLayOut = [NSArray arrayWithObjects:oMultiplePagesField,oDotSeparator,oExtensionPopup,oPublishAsCollectionPopup,nil];
		int markerExtraX [] = {4,6,8,0,0};
		int markerMarginsAfter[] = {0,0,8,12,0};
			
		NSArray *rootItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oIndexAndExtensionPopup,oFollowButton,oPublishAsCollectionPopup,nil];
		int rootExtraX [] = {0,8,0,0};
		int rootMarginsAfter[] = {4,8,12,0};
		
		NSArray *mediaItemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oMediaFilenameField,oFollowButton,nil];
		int mediaExtraX [] = {4,0,0};
		int mediaMarginsAfter[] = {0,4,12};

		NSArray *multipleTypesToLayOut = [NSArray arrayWithObjects:oMultiplePagesField,nil];
		int multiTypeExtraX [] = {2};
		int multiTypeMarginsAfter[] = {0};
		
		if (arePagesSelected)
		{
			if (selectedObjectsCount > 1)
			{
				itemsToLayOut = markerItemsToLayOut;
				theExtraX = markerExtraX;
				theMarginsAfter = markerMarginsAfter;
			}
			else
			{
				switch (pageIsCollectionState)
				{
					case IS_ROOT_STATE:
						itemsToLayOut = rootItemsToLayOut;
						theExtraX = rootExtraX;
						theMarginsAfter = rootMarginsAfter;
						break;
					case NSMixedState:
						itemsToLayOut = markerItemsToLayOut;
						theExtraX = markerExtraX;
						theMarginsAfter = markerMarginsAfter;
						break;
					case NSOnState:
						itemsToLayOut = collectionItemsToLayOut;
						theExtraX = collectionExtraX;
						theMarginsAfter = collectionMarginsAfter;
						break;
					case NSOffState:
						itemsToLayOut = pageItemsToLayOut;
						theExtraX = pageExtraX;
						theMarginsAfter = pageMarginsAfter;
						break;
				}
			}
		}
		else if (selectedObjectsCount > 1)
		{
			itemsToLayOut = multipleTypesToLayOut;
			theExtraX = multiTypeExtraX;
			theMarginsAfter = multiTypeMarginsAfter;
		}
		else
		{
			// kTextSiteItemType or kFileSiteItemType
			itemsToLayOut = mediaItemsToLayOut;
			theExtraX = mediaExtraX;
			theMarginsAfter = mediaMarginsAfter;
			
			// bindings: baseExampleURLString, fileName.  Are these coming through on media?
		}
			
		int widths[6] = { 0 }; // filled in below. Make sure we have enough items for array above
		int i = 0;
		// Collect up the widths that these items *want* to be
		for (NSView *fld in itemsToLayOut)
		{
			// Editable File Name
			NSRect frame = [fld frame];
			
			if ([fld isKindOfClass:[NSTextField class]])
			{
				NSTextField *txtFld = (NSTextField *)fld;
				NSSize fldSize = NSZeroSize;
				if (fld == self.activeTextField)
				{
					NSTextView *fieldEditor = (NSTextView *)[self.activeTextField currentEditor];
					OBASSERT([fieldEditor isKindOfClass:[NSTextView class]]);
					fldSize = [[fieldEditor textStorage] size];
				}
				else
				{
					fldSize = [[txtFld attributedStringValue] size];
				}

				
				int width = ceilf(fldSize.width);
				width += theExtraX[i];
				width += theMarginsAfter[i];
				frame.size.width = width;
			}
			widths[i++] = frame.size.width;
		}
		
		int newLeft = [oBaseURLField frame].origin.x;		// starting point for left of next item
		const int rightMargin = 20;
		int availableForAll = [[self view] bounds].size.width - rightMargin - newLeft;
		
		// Calculate a new width for base URL
		int availableForBaseURL = availableForAll -
			(theExtraX[0]
			 + widths[1]
			 + widths[2]
			 + widths[3]
			 + widths[4]
			 + widths[5]);
#define MINIMUM_BASE_URL 60
		if (availableForBaseURL < MINIMUM_BASE_URL)	// is file name field getting way long?
		{
			widths[0] = MINIMUM_BASE_URL;		// give base URL field a minimum size to show something there
			int fileNameFieldAdjustment = availableForBaseURL - MINIMUM_BASE_URL;
			widths[1] += fileNameFieldAdjustment;	// take away from the file name field
		}
		else if (widths[0] > availableForBaseURL)	// is base URL field allotment greater than what's available?
		{
			widths[0] = availableForBaseURL;	// truncate base URL
		}
		// Now set the new frames
		i = 0;
		for (NSView *fld2 in itemsToLayOut)
		{
			// Editable File Name
			NSRect frame = [fld2 frame];
			frame.origin.x = newLeft;
			frame.size.width = widths[i];
			[fld2 setFrame:frame];
			// NSLog(@"set %@ to %@", [fld2 class], NSStringFromRect(frame));

			newLeft = NSMaxX(frame);
			if (fld2 == oBaseURLField)	// special case -- move file name over to left to adjoin previous field
			{							// (which we left wide enough so it wouldn't get clipped)
				newLeft -= 4;
			}
			if (fld2 == oFileNameField || fld2 == oMediaFilenameField)	// special case -- move file name over to left to adjoin previous field
			{							// (which we left wide enough so it wouldn't get clipped)
				newLeft -= 1;
			}
			newLeft += theMarginsAfter[i];
			i++;
		}
	}
	// Now that widths have been recalculated, update the width for the active field, for the shadow background
	[self updateWidthForActiveTextField:self.activeTextField];

}

// -------------------------------------------------------------------------------
//  mouseEntered:event
// -------------------------------------------------------------------------------
//  Because we installed NSTrackingArea with "NSTrackingMouseEnteredAndExited"
//  as an option, this method will be called.
// -------------------------------------------------------------------------------
- (void)mouseEntered:(NSEvent*)event
{	
	KSShadowedRectView *view = (KSShadowedRectView *)[oMetaDescriptionField superview];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	
	NSRect fieldRect = [oMetaDescriptionField frame];
	[view setHiliteRect:fieldRect];
}

// -------------------------------------------------------------------------------
//  mouseExited:event
// -------------------------------------------------------------------------------
//  Because we installed NSTrackingArea with "NSTrackingMouseEnteredAndExited",
//  as an option, this method will be called.
// -------------------------------------------------------------------------------
- (void)mouseExited:(NSEvent*)event
{
	KSShadowedRectView *view = (KSShadowedRectView *)[oMetaDescriptionField superview];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	[view setHiliteRect:NSZeroRect];
}





- (void)updateWidthForActiveTextField:(NSTextField *)textField;
{
	if (!textField) return;	// we may have no active text field
	
	KSShadowedRectView *view = (KSShadowedRectView *)[textField superview];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	
	NSTextView *fieldEditor = (NSTextView *)[textField currentEditor];
	if (fieldEditor)
	{
		OBASSERT([fieldEditor isKindOfClass:[NSTextView class]]);
		
		
		NSRect textRect = [[fieldEditor layoutManager]
						   usedRectForTextContainer:[fieldEditor textContainer]];
		
		NSRect fieldRect = [textField frame];
		float textWidth = textRect.size.width;
		float fieldWidth = fieldRect.size.width;
		int width = ceilf(MIN(textWidth, fieldWidth));
		width = MAX(width, 7);		// make sure it's at least 7 pixels wide
		// NSLog(@"'%@' widths: text = %.2f, field = %.2f => %d", [textField stringValue], textWidth, fieldWidth, width);
		fieldRect.size.width = width;
		[view setFocusRect:fieldRect];
	}
}

- (void) backgroundFrameChanged:(NSNotification *)notification
{
	[self layoutPageURLComponents];
}

#pragma mark Publish as Collection

- (IBAction)popupSetPageOrCollection:(NSPopUpButton *)sender;
{
	NSUInteger tag = [[sender selectedItem] tag];
    [oSiteOutlineController
     setToCollection:(1 == tag) withDelegate:self
     didToggleSelector:@selector(siteOutlineController:didToggleIsCollection:)];
}

- (void)siteOutlineController:(SVSiteOutlineViewController *)controller didToggleIsCollection:(BOOL)success;
{
    // If user cancelled, repair binding value
    if (!success)
    {
		NSCellStateValue isCollection = [oPagesController selectedItemsAreCollections];
        [oPublishAsCollectionPopup selectItemWithTag:(NSOnState == isCollection?1:0)];
	}
}

#pragma mark -
#pragma mark Text editing notifications

/*	Sent when the user is typing in the meta description box.
 */

- (void)controlTextDidChange:(NSNotification *)notification
{
	// For some stupid reason, this is getting called twice, all within the text system.
	// So I set a flag so we don't do anything in the second invocation.
	if (!_alreadyHandlingControlTextDidChange)
	{
		_alreadyHandlingControlTextDidChange = YES;

		NSTextField *textField = (NSTextField *) [notification object];
		// This VERY important: Do NOT ask a cell for its -stringValue unless you actually need it. If the cell has a formatter, calling -stringValue will invoke that, and format the entered text, even though the user probably wasn't ready for it.
		NSTextView *fieldEditor = [[notification userInfo] objectForKey: @"NSFieldEditor"];
		NSAttributedString *newAttrString = [fieldEditor textStorage];
		NSString *newString = [newAttrString string];
		
		if (textField == oWindowTitleField)
		{
			[self windowTitleDidChangeToValue:newString];
		}
		else if (textField == oMetaDescriptionField)
		{
			[self metaDescriptionDidChangeToValue:newString];
		}
		else if (textField == oFileNameField || textField == oMediaFilenameField)
		{
			[self fileNameDidChangeToValue:newString];
		}
		[self layoutPageURLComponents];		
		_alreadyHandlingControlTextDidChange = NO;
	}
}

// Special responders to the subclass of the text field

- (void)controlTextDidBecomeFirstResponder:(NSNotification *)notification;
{
	KSShadowedRectView *view = (KSShadowedRectView *)[[notification object] superview];
	NSTextField *field = [notification object];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);

	self.activeTextField = field;
	[self updateWidthForActiveTextField:field];

	// Can't think of a better way to do this...
	
	NSString *bindingName = nil;
	NSString *explanation = @"";
	int tagForHelp = kUnknownPageDetailsContext;
	if (field == oFileNameField || field == oMediaFilenameField)
	{
		_maxFileCharacters = field == oFileNameField ? 27 : 32;
		tagForHelp = kFileNamePageDetailsContext;
		bindingName = @"fileNameCountString";
		explanation = [NSString stringWithFormat:NSLocalizedString(@"Maximum %d characters",@"brief indication of maximum length of file name"), _maxFileCharacters];
	}
	else if (field == oMetaDescriptionField)
	{	
		tagForHelp = kMetaDescriptionPageDetailsContext;
		bindingName = @"metaDescriptionCountString";
		explanation = NSLocalizedString(@"More than 156 characters will be truncated",@"brief indication of maximum length of text");
	}
	else if (field == oWindowTitleField)
	{
		tagForHelp = kWindowTitlePageDetailsContext;
		bindingName = @"windowTitleCountString";
		explanation = NSLocalizedString(@"More than 65 characters will be truncated",@"brief indication of maximum length of text");
	}
	

	if (bindingName)
	{
		[oAttachedWindowHelpButton setTag:tagForHelp];
		
		if (!self.attachedWindow)
		{
			// We are cheating here .. there is only ONE active text field, help button, etc. ... 
			// We fade out the window when we leave the field, but we immediately put these fields
			// into a new attached window.  I think nobody is going to notice that though.
			[oAttachedWindowTextField unbind:NSValueBinding];
			
			[oAttachedWindowTextField setStringValue:sCharacterDescriptionPluralCountFormat];
			const int widthExtra = 25;	// Fudge a little bit for longer numbers bigger than the width of the placeholder string
			float rightSide = ceilf([[oAttachedWindowTextField attributedStringValue] size].width) + widthExtra;

			[oAttachedWindowTextField bind:NSValueBinding toObject:self withKeyPath:bindingName options:nil];
            
			[oAttachedWindowExplanation setStringValue:explanation];
			
			int height = [oAttachedWindowView frame].size.height;	// also size of question mark
			const int buttonSize = 14;
			const int textHeight = 14;
			const int secondLineY = 15;
			int windowWidth = MAX(rightSide+8+height,
				ceilf([[oAttachedWindowExplanation attributedStringValue] size].width) + widthExtra );
			
			[oAttachedWindowView setFrame:NSMakeRect(0,0,windowWidth,height)];	// set view first, then subviews		
			[oAttachedWindowTextField setFrame:NSMakeRect(0,secondLineY,rightSide, textHeight)];
			[oAttachedWindowHelpButton setFrame:NSMakeRect(windowWidth-buttonSize,secondLineY,buttonSize,buttonSize)];
			[oAttachedWindowExplanation setFrame:NSMakeRect(0,0,windowWidth,textHeight)];
			NSPoint arrowTip = NSMakePoint([field frame].origin.x + 10, NSMidY([field frame]) );
			arrowTip = [view convertPoint:arrowTip toView:nil];
			
			self.attachedWindow = [[MAAttachedWindow alloc] initWithView:oAttachedWindowView 
													attachedToPoint:arrowTip 
														   inWindow:[view window] 
															 onSide:MAPositionLeft 
														 atDistance:10.0];
			self.attachedWindow.delegate = self;
			self.attachedWindow.alphaValue = 0.0;
			[self.attachedWindow setReleasedWhenClosed:YES];

			[self.attachedWindow setBorderColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.8]];
			[oAttachedWindowTextField setTextColor:[NSColor whiteColor]];
			[oAttachedWindowExplanation setTextColor:[NSColor whiteColor]];
			[[oAttachedWindowHelpButton image] setTemplate:YES];
			
			static NSImage *sTintedHelpButtonImage = nil;
			if (!sTintedHelpButtonImage)
			{
				sTintedHelpButtonImage = [[[oAttachedWindowHelpButton image] tintedImageWithColor:[NSColor lightGrayColor]] retain];
			}
			[oAttachedWindowHelpButton setAlternateImage:sTintedHelpButtonImage];

			[self.attachedWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:ATTACHED_WINDOW_TRANSP]];
			[self.attachedWindow setViewMargin:6];
			[self.attachedWindow setCornerRadius:6];	// set after arrow base width?  before?
			[self.attachedWindow setBorderWidth:0];
			[self.attachedWindow setHasArrow:YES];
			[self.attachedWindow setDrawsRoundCornerBesideArrow:NO];
			[self.attachedWindow setArrowBaseWidth:15];
			[self.attachedWindow setArrowHeight:8];
			[self.attachedWindow setCornerRadius:6];	// set after arrow base width?  before?

			[[view window] addChildWindow:self.attachedWindow ordered:NSWindowAbove];

			// Set up the animation for this window so we will get delegate methods
			CAAnimation *anim = [CABasicAnimation animation];
			// [anim setDuration:3.0];
			[anim setValue:self.attachedWindow forKey:@"myOwnerWindow"];
			[anim setDelegate:self];
			[self.attachedWindow setAnimations:[NSDictionary dictionaryWithObject:anim forKey:@"alphaValue"]];

			[self.attachedWindow.animator setAlphaValue:1.0];	// animate open
		}
	}
}

- (void)controlTextDidResignFirstResponder:(NSNotification *)notification;
{
	KSShadowedRectView *view = (KSShadowedRectView *)[[notification object] superview];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	[view setFocusRect:NSZeroRect];
	self.activeTextField = nil;
	
	if (self.attachedWindow)
	{
		[self.attachedWindow.animator setAlphaValue:0.0];
		[[[self view] window] removeChildWindow:self.attachedWindow];
		self.attachedWindow = nil;
	}
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag 
{
	NSWindow *animationWindow = [animation valueForKey:@"myOwnerWindow"];
	if(animationWindow.alphaValue <= 0.01)
	{
		[animationWindow orderOut:nil];
		[animationWindow close];
	}
}


// If you tab out of last text field to something else, we don't lose first responder?
// Unfortunately this doesn't do what we want if you hit *return* in the field.  We want this to
// happen when it ends editing with tab, but not when you use return.  Oh well.
- (void)controlTextDidEndEditing:(NSNotification *)notification;
{
	[self controlTextDidResignFirstResponder:notification];
}


#pragma mark -
#pragma mark Actions

// We will need to open up the appropriate help topic based on the tag

- (IBAction) pageDetailsHelp:(id)sender;
{
	NSLog(@"%s -- help variant = %d",__FUNCTION__, [sender tag]);
}

- (IBAction) preview:(id)sender;
{
	NSArray *selectedObjects = [oPagesController selectedObjects];
	id item = [selectedObjects lastObject];
	if (item)
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[item URL]];
	}
}

- (IBAction) chooseFile:(id)sender;
{
	
	NSArray *selectedObjects = [oPagesController selectedObjects];
	id item = [selectedObjects lastObject];
	KTSite *site = [item site];

	NSOpenPanel *panel = [[site document] makeChooseDialog];
    
    NSString *path = [[[item mediaRepresentation] alias] lastKnownPath];
    
	[panel beginSheetForDirectory:[path stringByDeletingLastPathComponent]
                             file:[path lastPathComponent]
                            types:[panel allowedFileTypes]
                   modalForWindow:[[self view] window]
                    modalDelegate:self
                   didEndSelector:@selector(chooseFilePanelDidEnd:returnCode:contextInfo:)
                      contextInfo:NULL];
}

- (void)chooseFilePanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)context;
{
    if (returnCode == NSOKButton && [[panel URLs] count])
	{
		SVDownloadSiteItem *downloadPage = [[oPagesController selectedObjects] lastObject];
		NSManagedObjectContext *context = [downloadPage managedObjectContext];
		NSURL *url = [[panel URLs] lastObject];		// we have just one
		NSError *error = nil;
		SVMediaRecord *record = [SVMediaRecord mediaByReferencingURL:url
                                                          entityName:@"FileMedia"
                                      insertIntoManagedObjectContext:context				/// where to we get our MOC?
                                                               error:&error];
		if (error)
		{
			[[NSApplication sharedApplication] presentError:error];
		}
		else
		{
			// Success: delete old media, store new:
			[downloadPage replaceMedia:record forKeyPath:@"media"];
		}
	}
}

@end
