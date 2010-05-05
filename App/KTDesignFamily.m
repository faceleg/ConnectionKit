//
//  KTDesignFamily.m
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "KTDesignFamily.h"
#import "KTDesign.h"
#import "NSArray+Karelia.h"

@implementation KTDesignFamily

@synthesize designs = _designs;
@synthesize thumbnails = _thumbnails;
@synthesize imageVersion = _imageVersion;
@synthesize colors = _colors;
@synthesize widths = _widths;
@synthesize familyPrototype = _familyPrototype;

- (KTDesign *)familyPrototype
{
	KTDesign *result = _familyPrototype;
	if (nil == result)
	{
		for (KTDesign *design in self.designs)
		{
			if ([design isFamilyPrototype])
			{
				result = self.familyPrototype = design;
				break;
			}
		}
		if (!result)	// none set?  Just choose the first one.
		{
			result = self.familyPrototype = [[self designs] firstObjectKS];
		}
		
	}
	return result;
}

- (void) cacheColorsAndWidths
{
	NSMutableArray *collectingColors = [NSMutableArray array];
	NSMutableArray *collectingWidths = [NSMutableArray array];
	for (KTDesign *design in self.designs)
	{
		NSColor *aColor = [design mainColor];
		NSString *aWidth = [design width];
		if (!aColor) aColor = [NSColor whiteColor];
		if (!aWidth) aWidth = @"standard";
		[collectingColors addObject:aColor];
		[collectingWidths addObject:aWidth];
	}
	self.colors = [NSArray arrayWithArray:collectingColors];
	self.widths = [NSArray arrayWithArray:collectingWidths];
	
}
- (NSArray *)colors
{
	if (!_colors)
	{
		[self cacheColorsAndWidths];
	}
	return _colors;
}

- (NSArray *)widths
{
	if (!_widths)
	{
		[self cacheColorsAndWidths];
	}
	return _widths;
}


- (id) init
{
	self = [super init];
	if ( self != nil )
	{
		_thumbnails = [[NSMutableDictionary alloc] init];
		_designs = [[NSMutableArray alloc] init];
		_imageVersion = NSNotFound;		// NSNotFound means not scrubbed yet, so use generic "parent" title
	}
	return self;
}

- (void) dealloc
{
	self.thumbnails = nil;
	self.designs = nil;
	self.colors = nil;
	self.widths = nil;
	self.familyPrototype = nil;
	[super dealloc];
}

- (void) addDesign:(KTDesign *)aDesign;
{
	[self.designs addObject:aDesign];
}

#pragma mark -
#pragma mark IKImageBrowserViewItem

- (NSString *)  imageUID;  /* required */
{
	return [[[[self designs] firstObjectKS] bundle] bundlePath];
}

/*! 
 @method imageRepresentationType
 @abstract Returns the representation of the image to display (required).
 @discussion Keys for imageRepresentationType are defined below.
 */
- (NSString *) imageRepresentationType; /* required */
{
	return IKImageBrowserCGImageRepresentationType;
}


/*! 
 @method imageRepresentation
 @abstract Returns the image to display (required). Can return nil if the item has no image to display.
 @discussion This methods is called frequently, so the receiver should cache the returned instance.
 */


- (id) imageRepresentation; /* required */
{
	int viewWidth = kDesignThumbWidth;
	int yOffset = 16;
	int swatchHeight = 10;
	int viewHeight = kDesignThumbHeight + yOffset;
	int between = 2;
	CGImageRef result = nil;
	
	NSNumber *indexNumber = [NSNumber numberWithInt:self.imageVersion];
	result = (CGImageRef) [self.thumbnails objectForKey:indexNumber];
	if (!result)		// see if we have a cached image....
	{
		int safeIndex = self.imageVersion;
		if ( (safeIndex != NSNotFound) && (safeIndex >= [[self designs] count]) )
		{
			safeIndex = 0;	// make sure we don't overflow number of design variations.  Allow for NSNotFound
		}
		
		// SET UP
		
		CGColorSpaceRef genericRGB = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		CGContextRef context = CGBitmapContextCreate(NULL, viewWidth, viewHeight, 8, 0, genericRGB, kCGImageAlphaPremultipliedFirst);
		NSGraphicsContext *graphicsContext = [NSGraphicsContext
												graphicsContextWithGraphicsPort:context flipped:NO];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:graphicsContext];
		
		// DRAW
		
		NSRect boundsOfThumb = NSMakeRect(0, 0, kDesignThumbWidth, kDesignThumbHeight);
		
		KTDesign *whichDesign = (safeIndex == NSNotFound) ? [self familyPrototype] : [[self designs] objectAtIndex:safeIndex];
		CGImageRef startImage = [whichDesign thumbnailCG];

		CGContextDrawImage([[NSGraphicsContext currentContext]
							graphicsPort], *(CGRect*)&boundsOfThumb, startImage);
		
		// Now for the stripes that show there are variations
		int nColors = [self.colors count];
		float colorWidth = ((float)(viewWidth+between)/nColors);
		float currentX = 0.0;						// starting Y coordinate
		int i = 0;
		for ( NSColor *color in self.colors )		// NOTE: I COULD PROBABLY OPTIMIZE THE DRAWING OF SWATCHES, ONCE...
		{
			NSString *thisColorsWidth = [self.widths objectAtIndex:i];
			[color set];
			if ([thisColorsWidth isEqualToString:@"wide"])
			{
				NSRect theRect  = NSMakeRect(currentX, viewHeight-swatchHeight, colorWidth-between, swatchHeight);
				[NSBezierPath fillRect:theRect];
			}
			else if ([thisColorsWidth isEqualToString:@"flexible"])	// make a trapezoid to indicate flexible
			{
#define OFFSET 3
				NSBezierPath *path = [[NSBezierPath alloc] init];
				[path moveToPoint:NSMakePoint(currentX, viewHeight-swatchHeight)];
				[path lineToPoint:NSMakePoint(currentX+OFFSET, viewHeight)];
				[path lineToPoint:NSMakePoint(currentX+colorWidth-between, viewHeight)];
				[path lineToPoint:NSMakePoint(currentX+colorWidth-between-OFFSET, viewHeight-swatchHeight)];
				[path closePath];
				[path fill];
			}
			else // standard -- inset the sides a bit so it's not so wide.
			{
#define INSET 3
				NSRect theRect  = NSMakeRect(currentX+INSET, viewHeight-swatchHeight, colorWidth-between-INSET-INSET, swatchHeight);
				[NSBezierPath fillRect:theRect];
			}
						
			if (i == self.imageVersion)		// show a highlight
			{
				NSRect hiliteRect = NSMakeRect(currentX, viewHeight-swatchHeight-3, colorWidth-between, 2);
				[[NSColor blackColor] set];
				[NSBezierPath fillRect:hiliteRect];
			}
			currentX += colorWidth;
			i++;
		}
		
		// BUILD AND CACHE IMAGE
		result = CGBitmapContextCreateImage(context);
		CFRelease(context);

		
//		NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:result] autorelease];
//		NSData *data = [bitmap TIFFRepresentation];
//		[data writeToFile:[NSString stringWithFormat:@"/Volumes/dwood/Desktop/foo_%d.tiff", self.imageVersion] atomically:NO];
		
		
		
		
		
		[self.thumbnails setObject:(id)result forKey:indexNumber];
	}
	return (id) result;
}

- (void) scrub:(float)howFar;
{
	int designCount = [[self designs] count];
	int whichIndex = howFar * designCount;
	whichIndex = MIN(whichIndex, designCount-1);
	self.imageVersion = whichIndex;
}

/*! 
 @method imageTitle
 @abstract Returns the title to display as a NSString. Use setValue:forKey: with IKImageBrowserCellTitleAttribute to set text attributes.
 */
- (NSString *) imageTitle;
{
	NSString *result = nil;
	int safeIndex = self.imageVersion;
	if ( (safeIndex != NSNotFound) && (safeIndex >= [[self designs] count]) )
	{
		safeIndex = 0;	// make sure we don't overflow number of design variations
	}
	if (safeIndex == NSNotFound)
	{
		result = [[self familyPrototype] titleOrParentTitle];
	}
	else
	{
		result = [[[self designs] objectAtIndex:safeIndex] title];
	}
	return result;
}
/*! 
 @method imageSubtitle
 @abstract Returns the subtitle to display as a NSString. Use setValue:forKey: with IKImageBrowserCellSubtitleAttribute to set text attributes.  Assume it's the same contributor for the whole family.
 */
- (NSString *) imageSubtitle;
{
	return [[[self designs] firstObjectKS] contributor];
}

- (BOOL) isSelectable;
{
	return YES;
}

// Genre, color properties so that we can filter  ... assume a whole family is the same

- (NSString *) genre;
{
	return [[[self designs] firstObjectKS] genre];
}
- (NSColor *) color;
{
	return [[[self designs] firstObjectKS] color];
}
- (NSString *) width;
{
	KTDesign *design = [[self designs] firstObjectKS];
	return [design width];
}



@end
