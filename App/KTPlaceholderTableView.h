//
//  PlaceholderTableView.h
//  Amazon List
//
//  Created by Mike on 04/01/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//
// An NSTableView subclss which when empty displays the placeholder
// text in grey in the centre of the table.

#import <Cocoa/Cocoa.h>


@class KSVerticallyAlignedTextCell;


@interface KTPlaceholderTableView : NSTableView
{
	NSString	*myPlaceholder;
	BOOL		myLoadingData;
	
	KSVerticallyAlignedTextCell	*myPlaceholderCell;
	NSProgressIndicator			*myDataLoadingProgressIndicator;
}

- (NSString *)placeholderString;
- (void)setPlaceholderString:(NSString *)placeholder;
- (NSColor *)placeholderStringColor;	// Default is 50% grey
- (void)setPlaceholderStringColor:(NSColor *)color;

- (BOOL)isLoadingData;
- (void)setLoadingData:(BOOL)loadingData;
- (NSProgressIndicator *)dataLoadingProgressIndicator;

@end
