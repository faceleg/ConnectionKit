

//
//  CroppingImageView.m
//  Cropped Image
//
//  Created by jcr on Tue Jul 16 2002.
//  Copyright (c) 2002 Apple Computer, Inc.  All rights reserved.
//
#import "CroppingImageView.h"
#import "CropMarker.h"
#import "CIImage+KTExtensions.h"
#import "NSImage+KTExtensions.h"
#import <QuartzCore/QuartzCore.h>
#import "assertions.h"


NSString *selectionChangedNotification = @"ImageSelectionChanged";

@implementation NSImageCell (CroppingImageView)

- (NSRect) rectCoveredByImageInBounds:(NSRect) bounds
	// This is a work-around to deal with the fact that NSImageCell won't tell me the rectangle *actually* covered by its image, but NSCell will.
{
	return [super imageRectForBounds:bounds];
}

@end

@implementation CroppingImageView

- (void)dealloc
{
	[self setSelectionMarker:nil];
	[super dealloc];
}

- (void)awakeFromNib
{
	[self setFocusRingType:NSFocusRingTypeNone];
	[self setContinuous:YES];
	[self setSelectionMarker:[CropMarker cropMarkerForView:self]];
	shouldAntiAlias = YES;
}

- (void)drawRect:(NSRect)rect 
{
	NSSize viewSize = [self bounds].size;
	float w = viewSize.width;
	float h = viewSize.height;
	CGSize originalSize = [myFullsizeCIImage extent].size;

	if (originalSize.width / originalSize.height > w/h)
	{
		// wider original than will fit: "letterbox", make height automatic
		h = roundf(w * (originalSize.height / originalSize.width));
	}
	else
	{
		// taller original than wil fit: "pillarbox" so make width automatic
		w = roundf(h * (originalSize.width / originalSize.height));
	}
	
	w += (originalSize.width  - w) * myZoom;
	h += (originalSize.height - h) * myZoom;

	CIImage *scaled = [myFullsizeCIImage scaleToWidth:w
											   height:h
											 behavior:kFitWithinRect
											alignment:NSImageAlignCenter
										  opaqueEdges:YES];
	

	CGRect  cg = CGRectMake(NSMinX(rect), NSMinY(rect),
							NSWidth(rect), NSHeight(rect));

	OBASSERT([NSGraphicsContext currentContext]);
	CIContext* context = [[NSGraphicsContext currentContext] CIContext];
	if (context != nil)
	{
		[context drawImage:scaled
				   atPoint:cg.origin
				  fromRect:cg];
	}
	
	[selectionMarker drawCropMarker];
}

// NSResponder methods.  For the most part, the events are just punted to the CropMarker.
- (void) mouseDown:(NSEvent *) theEvent {
	[selectionMarker mouseDown:theEvent];
}

- (void) mouseUp:(NSEvent *) theEvent 
{ 
	[selectionMarker mouseUp:theEvent]; 
	[self selectionChanged];
	[self postSelectionChangedNotification];  // This is how the controller knows to redraw the second NSImageView.
}

- (void) mouseDragged:(NSEvent *) theEvent 
{ 
	[selectionMarker mouseDragged:theEvent]; 
	if ([self isContinuous])
		[self postSelectionChangedNotification];
	[self selectionChanged];	
}

- (void) selectionChanged 	{ [self setNeedsDisplay:YES]; }

- (void) postSelectionChangedNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:selectionChangedNotification object:self];
}

- (NSImage *) croppedImage 
	// Returns an autoreleased NSImage, consisting of the selected portion of the reciever's image.  
	// If there's no selection, this method will return the original image.
{
	NSRect 
	sourceImageRect = [[self cell] rectCoveredByImageInBounds:[self bounds]], 
	newImageBounds = NSIntersectionRect([selectionMarker selectedRect], sourceImageRect);
	
	if (!NSIsEmptyRect(newImageBounds))
	{
		NSImage 
		*newImage = [[NSImage alloc] initWithSize:sourceImageRect.size];
		
		NSAffineTransform 
			*pathAdjustment = [NSAffineTransform transform];
		
		NSBezierPath 
			*croppingPath = [selectionMarker selectedPath];	
		
		[pathAdjustment translateXBy: -NSMinX(sourceImageRect) yBy: -NSMinY(sourceImageRect)];
		croppingPath = [pathAdjustment transformBezierPath:[selectionMarker selectedPath]];
		
		[newImage lockFocus];
		if (!shouldAntiAlias) 
		{
			OBASSERT([NSGraphicsContext currentContext]);
			[[NSGraphicsContext currentContext] setShouldAntialias:NO];
		}
		[[NSColor blackColor] set];
		[croppingPath fill];
		[[self image] compositeToPoint:NSZeroPoint operation:NSCompositeSourceIn];
		[newImage unlockFocus];
		
		return [newImage autorelease];
	}		
	return [self image];
}

- (void) setSelectionMarker:(CropMarker *)marker
{
	[marker retain];
	[selectionMarker release];
	selectionMarker = marker;
}

- (CropMarker *)selectionMarker
{
	return selectionMarker;
}

/*!	Accept D&D from outside
*/

// We're going to assume that the nsimageview handles most of the dragging
//- (BOOL)acceptsDrag
//{
//	BOOL result = NO;
//
//	NSPasteboard *pboard = [draggingInfo draggingPasteboard];
//	[pboard types];
//	
//	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
//	{
//		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
//		NSString *fileName = [fileNames objectAtIndex:anIndex];
//		if ( nil != fileName )
//		{
//			// check to see if it's an image file
//			NSString *aUTI = [KTUtilities UTIForFileAtPath:fileName];	// takes account as much as possible
//			result = [KTUtilities UTI:aUTI conformsToUTI:(NSString *)kUTTypeImage]
//		}
//	}
//	else if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
//	{
//		result = YES;
//	}
//	
//	return result;
//}




- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	
// TODO:  This can be rewritten to use utility method in KTImageView
	
	
	
	
    NSPasteboard *pboard = [sender draggingPasteboard];
    (void)[pboard types]; // we always have to call types
	
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if ([fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:0];
			if ( nil != fileName )
			{
				NSImage *im = [[[NSImage alloc] initWithContentsOfFile:fileName] autorelease];
				if (nil != im)
				{
	// TODO: pass filename back to enclosing controller
					[self setImage:im];
				}
			}
		}
	}
	else if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
	{
		NSData *pboardData = [pboard dataForType:NSTIFFPboardType];
		NSImage *im = [[[NSImage alloc] initWithData:pboardData] autorelease];
		if (nil != im)
		{
// TODO: pass EMPTY filename back to enclosing controller
			[self setImage:im];
		}
	}
// TODO: handle drag from web archive, where we have original image data	

    [super concludeDragOperation:sender];
}

- (float)zoom
{
    return myZoom;
}

- (void)setZoom:(float)aZoom
{
    myZoom = aZoom;
	NSLog(@"set CroppingImageView zoom to %f", aZoom);
	[self setNeedsDisplay:YES];
}

- (void)setImage:(NSImage *)anImage
{
	CIImage *im = [anImage toCIImage];
	[im retain];
	[myFullsizeCIImage release];
	myFullsizeCIImage = im;
}

/*!	Actually this should probably crop it and scale it
*/

- (NSImage *)image
{
	return [myFullsizeCIImage toNSImage];
	
}
@end
