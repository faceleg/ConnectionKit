//
//  SVDesignChooserImageBrowserCell.m
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserImageBrowserCell.h"





@interface SVDesignChooserImageBrowserCell ()

- (void) setDataSource:(id)inDataSource;
- (void) drawShadow;
- (void) drawImageOutline;
- (NSRect) usedRectInCellFrame:(NSRect)inFrame;
- (NSRect) imageContainerFrame;
- (IKImageBrowserView*) imageBrowserView;	// To shut up the compiler when using 10.5.sdk

@end

@implementation SVDesignChooserImageBrowserCell





//----------------------------------------------------------------------------------------------------------------------

/*
 - (NSRect) frame
 {
 NSRect frame = [super frame];
 NSLog(@"frame = %@",NSStringFromRect(frame));
 
 CGFloat top = NSMinY(frame);
 frame.size.height = 0.5 * frame.size.width;
 frame.origin.y = top - frame.size.height;
 
 return frame;
 }
 
 
 //- (NSRect) imageBorderFrame
 //{
 //	NSRect frame = [super imageBorderFrame];
 //	return frame;
 //}
 //
 //
 //- (NSRect) imageFrame
 //{
 //	NSRect frame = [super imageFrame];
 //	return frame;
 //}
 
 
 - (NSRect) imageContainerFrame
 {
 NSRect frame = [super frame];
 //	CGFloat top = NSMinY(frame);
 //	frame.size.height = 0.75 * frame.size.width;
 //	frame.origin.y = top - frame.size.height;
 
 //	//make the image container 15 pixels up
 //	container.origin.y += 15;
 //	container.size.height -= 15;
 
 NSLog(@"imageContainerFrame = %@",NSStringFromRect(frame));
 return frame;
 }
 
 //- (NSRect) imageContainerFrame
 //{
 //	NSRect frame = [super imageContainerFrame];
 //	NSLog(@"imageContainerFrame = %@",NSStringFromRect(frame));
 //	return frame;
 //}
 
 
 - (NSRect) titleFrame
 {
 NSRect frame = [super imageBorderFrame];
 frame.origin.y = NSMinY(frame) - 17.0;
 frame.size.height = 17.0;
 return frame;
 }
 
 
 //- (NSRect) imageFrameForCellFrame:(NSRect)inFrame
 //{
 //	NSRect frame = [super imageFrameForCellFrame:inFrame];
 //	return frame;
 //}
 
 
 //- (NSRect) imageFrameForImageContainerFrame:(NSRect)inFrame
 //{
 ////	NSRect frame = [super imageFrameForCellFrame:inFrame];
 //	return inFrame;
 //}
 
 
 //- (NSRect) usedRectInCellFrame:(NSRect)inFrame
 //{
 //	NSRect rect = [super usedRectInCellFrame:inFrame];
 //	return rect;
 //}
 //
 //- (NSRect) selectionFrame
 //{
 //	return [self frame];
 //	NSRect frame = [super selectionFrame];
 //	return frame;
 ////	NSRect frame = [self frame];
 ////	return NSInsetRect(frame,-0.0,-0.0);
 //}
 
 
 //- (NSRect) titleFrame
 //{
 //	NSRect frame = [self frame];
 //	frame.size.height = 16.0;
 //	return frame;
 //}
 */

//----------------------------------------------------------------------------------------------------------------------


//- (void) drawSelection
//{
//	[[NSColor yellowColor] set];
//	NSRectFillUsingOperation([self selectionFrame],NSCompositeSourceOver);
////	[super drawSelection];	
//}


//- (void) drawSelectionOnTitle
//{
//	[super drawTitle];	
//}
//
//
//- (void) drawTitle
//{
//	[super drawTitle];	
//}


//----------------------------------------------------------------------------------------------------------------------




// Draw the image itself. In the case of an IMBNodeObject (which is represented as a large folder icon)
// we should draw a small badge icon on top of the large folder icon. This si used to distinguish various 
// kinds of subnodes visually (e.g. iPhoto events, albums, etc)...

//- (void) drawImage:(id)inImage
//{
//	[super drawImage:inImage];
//	
//	id datasource = self.dataSource;
//	
//	if ([datasource isKindOfClass:[IMBNodeObject class]])
//	{
//		IMBNode* node = (IMBNode*) datasource;
//		NSImage* icon = node.icon;
//		NSRect frame = [self imageFrame];
//		CGFloat x0 = 20; //NSMidX(frame);
//		CGFloat y0 = 20; //NSMidY(frame);
//		CGFloat dx = 16.0;
//		CGFloat dy = 16.0;
//		frame = NSMakeRect(x0-0.5*dx,y0-0.5*dy,dx,dy);
//		[icon drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
//	}
//}


//----------------------------------------------------------------------------------------------------------------------



//----------------------------------------------------------------------------------------------------------------------


//- (BOOL) wantsRollover
//{
//	return [super wantsRollover];
//}
//
//
//- (void) mouseEntered:(NSEvent*)inEvent
//{
//	[super mouseEntered:(NSEvent*)inEvent];
//}
//
//
//- (void) mouseExited:(NSEvent*)inEvent
//{
//	[super mouseExited:(NSEvent*)inEvent];
//}


//----------------------------------------------------------------------------------------------------------------------


@end

