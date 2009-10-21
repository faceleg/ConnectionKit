//
//  KTPageDetailsController.m
//  Marvel
//
//  Created by Mike on 04/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>
#import "KTPageDetailsController.h"
#import "KSShadowedRectView.h"
#import "KSPopUpButton.h"
#import "KSValidateCharFormatter.h"
#import "KSFocusingTextField.h"
#import "MAAttachedWindow.h"
#import "NSImage+Karelia.h"

#import "NTBoxView.h"

#import "NSCharacterSet+Karelia.h"
#import "NSObject+Karelia.h"

static NSString *sMetaDescriptionObservationContext = @"-metaDescription observation context";
static NSString *sWindowTitleObservationContext = @"-windowTitle observation context";
static NSString *sFileNameObservationContext = @"-fileName observation context";
static NSString *sTitleTextObservationContext = @"-titleText observation context";

enum { kUnknownPageDetailsContext, kFileNamePageDetailsContext, kWindowTitlePageDetailsContext, kMetaDescriptionPageDetailsContext
};

@interface KTPageDetailsController ()
- (void)metaDescriptionDidChangeToValue:(id)value;
- (void)windowTitleDidChangeToValue:(id)value;
- (void)fileNameDidChangeToValue:(id)value;
- (void) resetPlaceholderToComboTitleText:(NSString *)comboTitleText;
- (void) layoutPageURLComponents;
@end


#pragma mark -


@implementation KTPageDetailsController

@synthesize activeTextField = _activeTextField;
@synthesize attachedWindow = _attachedWindow;

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSViewBoundsDidChangeNotification
												  object:[self view]];
	
	self.activeTextField = nil;
	[_metaDescriptionCountdown release];
	[_windowTitleCountdown release];
	[_fileNameCountdown release];
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
	[oPagesController addObserver:self
					   forKeyPath:@"selection.windowTitle"
						  options:NSKeyValueObservingOptionNew
						  context:sWindowTitleObservationContext];
	[self windowTitleDidChangeToValue:[oPagesController valueForKeyPath:@"selection.windowTitle"]];
	[oPagesController addObserver:self
					   forKeyPath:@"selection.fileName"
						  options:NSKeyValueObservingOptionNew
						  context:sFileNameObservationContext];
	[self fileNameDidChangeToValue:[oPagesController valueForKeyPath:@"selection.fileName"]];
	
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

- (NSNumber *)fileNameCountdown { return _fileNameCountdown; }

- (void)setFileNameCountdown:(NSNumber *)countdown
{
	[countdown retain];
	[_fileNameCountdown release];
	_fileNameCountdown = countdown;
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
		
		[newBindingOptions setObject:comboTitleText forKey:NSNullPlaceholderBindingOption];
		
		[oWindowTitleField unbind:NSValueBinding];

		[oWindowTitleField bind:NSValueBinding toObject:observedObject withKeyPath:bindingKeyPath options:newBindingOptions];
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

- (void)fileNameDidChangeToValue:(id)value
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
	
	[self setFileNameCountdown:value];
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

+ (NSSet *)keyPathsForValuesAffectingFileNameCharCountColor
{
    return [NSSet setWithObject:@"fileNameCountdown"];
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
	else if (context == sFileNameObservationContext)
	{
		[self fileNameDidChangeToValue:[object valueForKeyPath:keyPath]];
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

/*
 Algorithm 
 Calculate how much each of the variable fields oBaseURLField and oPageFileNameField *want* to be
 Don't truncate oPageFileNameField - this is limited by character count and we want to see the whole thing
 So we will truncate oBaseURLField as much as we need.
 
 
 */

- (void) layoutPageURLComponents;
{
	NSArray *itemsToLayOut = [NSArray arrayWithObjects:oBaseURLField,oPageFileNameField,oDotSeparator,oFileExtensionPopup,nil];
	int extraX [] = {4,4,6,0};
	int widths[4] = { -1 };
	int i = 0;
	// Collect up the widths that these items *want* to be
	for (NSView *fld in itemsToLayOut)
	{
		// Editable File Name
		NSRect frame = [fld frame];
		
		if ([fld isKindOfClass:[NSTextField class]])
		{
			NSAttributedString *text = [((NSTextField *)fld) attributedStringValue];
			int width = ceilf([text size].width);
			width += extraX[i];
			frame.size.width = width;
		}
		widths[i++] = frame.size.width;
	}
	
	int newLeft = [oBaseURLField frame].origin.x;		// starting point for left of next item
	const int rightMargin = 20;
	int availableForAll = [[self view] bounds].size.width - rightMargin - newLeft;
	
	// Calculate a new width for base URL
	int availableForBaseURL = availableForAll -
		(extraX[0]
		 + widths[1]
		 + widths[2]
		 + widths[3] );
	if (widths[0] > availableForBaseURL)
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
		newLeft = NSMaxX(frame);
		if (fld2 == oBaseURLField)	// special case -- move file name over to left to adjoin previous field
		{							// (which we left wide enough so it wouldn't get clipped)
			newLeft -= 4;
		}
		i++;
	}
}



- (void)updateWidthForActiveTextField:(NSTextField *)textField
{
	KSShadowedRectView *view = (KSShadowedRectView *)[self view];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	
	NSTextView *fieldEditor = (NSTextView *)[textField currentEditor];
	
	NSRect textRect = [[fieldEditor layoutManager]
					   usedRectForTextContainer:[fieldEditor textContainer]];
	
	NSRect fieldRect = [textField frame];
	CGFloat textWidth = textRect.size.width;
	textWidth = MAX(textWidth, 7.0);
	if (textWidth < fieldRect.size.width) fieldRect.size.width = textWidth;
	[view setShadowRect:fieldRect];
	
}

- (void) backgroundFrameChanged:(NSNotification *)notification
{
	[self layoutPageURLComponents];
	if (self.activeTextField)
	{
		[self updateWidthForActiveTextField:self.activeTextField];
	}
}
/*	Sent when the user is typing in the meta description box.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	NSTextField *textField = (NSTextField *) [notification object];
	NSString *newValue = [textField stringValue]; // Do NOT try to modify this string!
	if (textField == oWindowTitleField)
	{
		[self windowTitleDidChangeToValue:newValue];
	}
	else if (textField == oMetaDescriptionField)
	{
		[self metaDescriptionDidChangeToValue:newValue];
	}
	[self layoutPageURLComponents];
	[self updateWidthForActiveTextField:textField];
}

- (IBAction) pageDetailsHelp:(id)sender;
{
	NSLog(@"%s -- help variant = %d",__FUNCTION__, [sender tag]);
}

// Special responders to the subclass of the text field

- (void)controlTextDidBecomeFirstResponder:(NSNotification *)notification;
{
	KSShadowedRectView *view = (KSShadowedRectView *)[self view];
	NSTextField *field = [notification object];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	
	// Can't think of a better way to do this...
	
	NSString *bindingName = @"";
	int tagForHelp = kUnknownPageDetailsContext;
	if (field == oPageFileNameField)
	{
		tagForHelp = kFileNamePageDetailsContext;
		bindingName = @"fileNameCountdown";
	}
	else if (field == oMetaDescriptionField)
	{	
		tagForHelp = kMetaDescriptionPageDetailsContext;
		bindingName = @"metaDescriptionCountdown";
	}
	else if (field == oWindowTitleField)
	{
		tagForHelp = kWindowTitlePageDetailsContext;
		bindingName = @"windowTitleCountdown";
	}
	[oAttachedWindowHelpButton setTag:tagForHelp];
		
	[self updateWidthForActiveTextField:field];
	self.activeTextField = field;
	
	if (!self.attachedWindow)
	{
		// We are cheating here .. there is only ONE active text field, help button, etc. ... 
		// We fade out the window when we leave the field, but we immediately put these fields
		// into a new attached window.  I think nobody is going to notice that though.
		[oAttachedWindowTextField unbind:NSValueBinding];
		NSDictionary *bindingOptions = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"%{value1}@ characters", @"pattern for showing characters used"), NSDisplayPatternBindingOption, nil];
		[oAttachedWindowTextField bind:@"displayPatternValue1" toObject:self withKeyPath:bindingName options:bindingOptions];

		NSString *note = @"fjdsklfjdlskjflkdsajflkdsS";

		[oAttachedWindowTextField setStringValue:note];
		NSAttributedString *noteAttr = [oAttachedWindowTextField attributedStringValue];
		NSSize noteSize = [noteAttr size];
		
		const int widthExtra = 4;	// NSTextField uses a few more pixels than the string width
		float rightSide = ceilf(noteSize.width) + widthExtra;
		int height = noteSize.height;	// also size of question mark

		[oAttachedWindowView setFrame:NSMakeRect(0,0,rightSide+8+height,height)];	// set view first, then subviews		
		[oAttachedWindowTextField setFrame:NSMakeRect(0,0,rightSide, height)];
		[oAttachedWindowHelpButton setFrame:NSMakeRect(rightSide+8,0,height,height)];
	
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
		[[oAttachedWindowHelpButton image] setTemplate:YES];
		
		static NSImage *sTintedHelpButtonImage = nil;
		if (!sTintedHelpButtonImage)
		{
			sTintedHelpButtonImage = [[[oAttachedWindowHelpButton image] tintedImageWithColor:[NSColor lightGrayColor]] retain];
		}
		[oAttachedWindowHelpButton setAlternateImage:sTintedHelpButtonImage];

        [self.attachedWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
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

- (void)controlTextDidResignFirstResponder:(NSNotification *)notification;
{
	KSShadowedRectView *view = (KSShadowedRectView *)[self view];
	OBASSERT([view isKindOfClass:[KSShadowedRectView class]]);
	[view setShadowRect:NSZeroRect];
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
- (void)controlTextDidEndEditing:(NSNotification *)notification;
{
	[self controlTextDidResignFirstResponder:notification];
}


@end
