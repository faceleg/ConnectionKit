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


@implementation KTPageDetailsController

#pragma mark -
#pragma mark View

- (void)setView:(NSView *)aView
{
	if (aView) OBPRECONDITION([aView isKindOfClass:[NTBoxView class]]);
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
	[oMetaDescriptionField setPlaceholderString:NSLocalizedString(@"Optional summary of page. Used by search engines.",
																  "Page <meta> description placeholder text. [THIS SHOULD BE A SHORT STRING!]")];
	
	
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

@end
