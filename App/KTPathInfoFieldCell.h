//
//  KTPathInfoFieldCell.h
//  File Picker prototype
//
//  Created by Mike on 08/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTPathInfoFieldCell : NSTextFieldCell
{
	NSTextFieldCell	*myFileNameCell;
	NSImage			*myFileIcon;
}

// Layout
- (NSRect)fileIconRectForBounds:(NSRect)bounds;
- (NSRect)filenameRectForBounds:(NSRect)bounds;


@end
