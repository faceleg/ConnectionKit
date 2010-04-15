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

- (id) init
{
	self = [super init];
	if ( self != nil )
	{
		_thumbnails = [[NSMutableDictionary alloc] init];
		_designs = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	self.thumbnails = nil;
	self.designs = nil;
	self.colors = nil;
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
	int viewWidth = kDesignThumbWidth + 12;
	
	NSNumber *indexNumber = [NSNumber numberWithInt:self.imageVersion];
	CGImageRef result = (CGImageRef) [self.thumbnails objectForKey:indexNumber];	// cached?
	if (!result)
	{
		int safeIndex = self.imageVersion;
		if (safeIndex >= [[self designs] count])
		{
			safeIndex = 0;	// make sure we don't overflow number of design variations
		}
		
		// SET UP
		
		CGColorSpaceRef genericRGB = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		CGContextRef context = CGBitmapContextCreate(NULL, viewWidth, kDesignThumbHeight, 8, 0, genericRGB, kCGImageAlphaPremultipliedFirst);
		NSGraphicsContext *graphicsContext = [NSGraphicsContext
												graphicsContextWithGraphicsPort:context flipped:NO];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:graphicsContext];
		
		// DRAW
		
		NSRect boundsOfThumb = NSMakeRect(6.0, 0.0, kDesignThumbWidth, kDesignThumbHeight);
		CGImageRef startImage = [[[self designs] objectAtIndex:safeIndex] thumbnailCG];

		CGContextDrawImage([[NSGraphicsContext currentContext]
							graphicsPort], *(CGRect*)&boundsOfThumb, startImage);

		if (!self.colors)
		{
			NSMutableArray *collectingColors = [NSMutableArray array];
			for (KTDesign *design in self.designs)
			{
				NSColor *aColor = [design mainColor];
				if (!aColor) aColor = [NSColor whiteColor];
				[collectingColors addObject:aColor];
			}
			self.colors = [NSArray arrayWithArray:collectingColors];
		}
		// Now for the stripes that show there are variations
		int nColors = [self.colors count];
		float colorHeight = ((float)(kDesignThumbHeight+1)/nColors);
		float currentY = 0.0;						// starting Y coordinate
		
		for ( NSColor *color in self.colors )
		{
			[color set];
			NSRect leftRect  = NSMakeRect(0,				currentY, 4, colorHeight-1);
			NSRect rightRect = NSMakeRect(viewWidth-4,		currentY, 4, colorHeight-1);
			[NSBezierPath fillRect:leftRect];
			[NSBezierPath fillRect:rightRect];
			currentY += colorHeight;
		}
		
		
		// BUILD AND CACHE IMAGE
		result = CGBitmapContextCreateImage(context);
		CFRelease(context);
		[self.thumbnails setObject:(id)result forKey:indexNumber];
	}
	NSLog(@"Image for version:%d", self.imageVersion);
	return (id) result;
}

- (void) scrub:(float)howFar;
{
	int designCount = [[self designs] count];
	int whichIndex = howFar * designCount;
	whichIndex = MIN(whichIndex, designCount-1);
	self.imageVersion = whichIndex;
	NSLog(@"Using index %d", self.imageVersion);
}

/*! 
 @method imageTitle
 @abstract Returns the title to display as a NSString. Use setValue:forKey: with IKImageBrowserCellTitleAttribute to set text attributes.
 */
- (NSString *) imageTitle;
{
	return [[[[self designs] firstObjectKS] title] uppercaseString];
}
/*! 
 @method imageSubtitle
 @abstract Returns the subtitle to display as a NSString. Use setValue:forKey: with IKImageBrowserCellSubtitleAttribute to set text attributes.
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



@end
