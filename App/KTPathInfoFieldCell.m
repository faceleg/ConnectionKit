//
//  KTPathInfoFieldCell.m
//  File Picker prototype
//
//  Created by Mike on 08/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "KTPathInfoFieldCell.h"


@implementation KTPathInfoFieldCell

#pragma mark -
#pragma mark NSObject

- (id)copyWithZone:(NSZone *)zone
{
	KTPathInfoFieldCell *result = [super copyWithZone:zone];
	
	// Now handle the copy's file icon and text cell
	[result->myFileIcon retain];
	result->myFileNameCell = nil;
	
	return result;
}

- (void)dealloc
{
	[myFileNameCell release];
	[myFileIcon release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSImage *)fileIcon { return myFileIcon; }

- (void)setFileIcon:(NSImage *)fileIcon
{
	[fileIcon setSize:NSMakeSize(16.0, 16.0)];
	
	[fileIcon retain];
	[myFileIcon release];
	myFileIcon = fileIcon;
}

- (NSTextFieldCell *)filenameTextFieldCell
{
	if (!myFileNameCell)
	{
		myFileNameCell = [[NSTextFieldCell alloc] initTextCell:[self stringValue]];
		
		[myFileNameCell setFont:[NSFont boldSystemFontOfSize:
			[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
		
		[myFileNameCell setTextColor:[NSColor darkGrayColor]];
		[myFileNameCell setBezeled:YES];
		[myFileNameCell setScrollable:YES];
		
		[myFileNameCell setEnabled:YES];
		[myFileNameCell setEditable:NO];
		[myFileNameCell setSelectable:YES];
	}
	
	return myFileNameCell;
}

- (void)setObjectValue:(id <NSCopying>)object
{
	[super setObjectValue:object];
	
	// Update the filename cell and file icon
	NSString *filename = @"";
	NSImage *fileIcon = nil;
	
	if (object && [(id)object isKindOfClass:[NSString class]])
	{
		filename = [[NSFileManager defaultManager] displayNameAtPath:(NSString *)object];
		
		NSString *fileType = nil;
		[[NSWorkspace sharedWorkspace] getInfoForFile:(NSString *)object application:NULL type:&fileType];
		fileIcon = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];
	}
	
	[[self filenameTextFieldCell] setObjectValue:filename];
	[self setFileIcon:fileIcon];
}

#pragma mark -
#pragma mark Drawing & Layout

- (NSRect)fileIconRectForBounds:(NSRect)bounds
{
	NSRect result = NSMakeRect(3.0, 3.0, 16.0, 16.0);
	return result;
}

- (NSRect)filenameRectForBounds:(NSRect)bounds
{
	NSRect fileNameRect = NSMakeRect(bounds.origin.x + 18.0,
									 bounds.origin.y + 1.0,
									 bounds.size.width - 18.0,
									 bounds.size.height);
	
	return fileNameRect;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// Draw the file's icon
	NSImage *icon = [self fileIcon];
	[icon setFlipped:[controlView isFlipped]];
	
	[icon drawAtPoint:[self fileIconRectForBounds:cellFrame].origin
			 fromRect:NSZeroRect
			operation:NSCompositeSourceOver
			 fraction:1.0];
	
	// Draw the filename
	[[self filenameTextFieldCell]
		drawInteriorWithFrame:[self filenameRectForBounds:cellFrame] inView:controlView];
}

#pragma mark -
#pragma mark Text Selection

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
	[[self filenameTextFieldCell] selectWithFrame:[self filenameRectForBounds:aRect]
										   inView:controlView
										   editor:textObj
										 delegate:nil
											start:selStart
										   length:selLength];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
	[[self filenameTextFieldCell] editWithFrame:[self filenameRectForBounds:aRect]
										 inView:controlView
										 editor:textObj
									   delegate:nil
										  event:theEvent];
}

- (void)resetCursorRect:(NSRect)cellFrame inView:(NSView *)controlView
{
	[super resetCursorRect:[self filenameRectForBounds:cellFrame] inView:controlView];
}

@end
