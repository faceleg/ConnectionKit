//
//  OverlayIndexPlugIn.m
//  OverlayIndex
//
//  Copyright 2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

// Uses Colorbox 1.3.16, from http://colorpowered.com/colorbox/

#import "OverlayIndexPlugIn.h"


@implementation OverlayIndexPlugIn

@synthesize transitionType		= _transitionType;
@synthesize backgroundColor		= _backgroundColor;
@synthesize enableSlideshow		= _enableSlideshow;
@synthesize autoStartSlideshow	= _autoStartSlideshow;
@synthesize loop				= _loop;
@synthesize slideshowSpeed		= _slideshowSpeed;
@synthesize connectPhotoGrids	= _connectPhotoGrids;
@synthesize showCollectionTitle	= _showCollectionTitle;
@synthesize showCollectionThumbnail = _showCollectionThumbnail;

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
						   @"transitionType",
						   @"backgroundColor",
						   @"enableSlideshow",
                           @"autoStartSlideshow",
                           @"loop",
						   @"slideshowSpeed",
                           @"connectPhotoGrids",
						   @"showCollectionTitle",
						   @"showCollectionThumbnail",
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


- (void)awakeFromNew
{
	self.transitionType				= kOverlayTransitionElastic;
	self.slideshowSpeed				= 0.75;
	self.connectPhotoGrids			= YES;
	self.showCollectionTitle		= YES;
	self.showCollectionThumbnail	= YES;
	self.enableSlideshow			= YES;
	self.backgroundColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.5];
    [super awakeFromNew];
}


#pragma mark HTML Generation


- (void)writePlaceholderHTML:(id <SVPlugInContext>)context;
{
	// Only show the placeholder (indicating that it's necessary to connect a grid) if we are NOT using this just to activate a photo grid.
	// If we ARE using this to connect to photo grid, not showing otherwise, we DON'T WANT to see placeholder, but instead the "invisible" badge
	if (!self.connectPhotoGrids)
	{
		[super writePlaceholderHTML:context];
	}
}

- (void)writeHTML:(id <SVPlugInContext>)context
{
	[super writeHTML:context];	// super will deal with index stuff. However we don't have a template, so do it all below.
	
	
	
	// add dependencies
	
	[context addDependencyForKeyPath:@"transitionType"			ofObject:self];
	[context addDependencyForKeyPath:@"backgroundColor"			ofObject:self];
	[context addDependencyForKeyPath:@"enableSlideshow"			ofObject:self];
	[context addDependencyForKeyPath:@"autoStartSlideshow"		ofObject:self];
	[context addDependencyForKeyPath:@"loop"					ofObject:self];
	[context addDependencyForKeyPath:@"slideshowSpeed"			ofObject:self];
	[context addDependencyForKeyPath:@"connectPhotoGrids"		ofObject:self];
	[context addDependencyForKeyPath:@"showCollectionTitle"		ofObject:self];
	[context addDependencyForKeyPath:@"showCollectionThumbnail"	ofObject:self];
	
	
	
	
	
	// Load ColorBox at end of file
	
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *minimizationSuffix = @"-min";
	if ([defaults boolForKey:@"jQueryDevelopment"])
	{
		minimizationSuffix = @"";		// Use the development version instead, not the minimized. Same user default for jquery.
	}
		
	NSString *baseFileName = [NSString stringWithFormat:@"jquery.colorbox%@", minimizationSuffix];
	NSString *path = [[NSBundle mainBundle] pathForResource:baseFileName ofType:@"js"];
	if (path)
	{
		NSURL *URL = [context addResourceWithURL:[NSURL fileURLWithPath:path]];
		NSString *srcPath = [context relativeStringFromURL:URL];
		NSString *script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", srcPath];
		[context addMarkupToEndOfBody:script];
	}
	
	
	
	

	
	
	
	// Prepare Parameters
	
	NSString *transitionString = nil;
	switch (self.transitionType)
	{
		case kOverlayTransitionElastic:		transitionString = @"elastic"; break;
		case kOverlayTransitionFade:		transitionString = @"fade"; break;
		default:							transitionString = @"none";	break;
	}
	NSString *slideshowString = self.enableSlideshow ? @"true" : @"false";
	NSString *slideshowAutoString = self.autoStartSlideshow ? @"true" : @"false";
	NSString *loopString = self.loop ? @"true" : @"false";
	// Convert number, inclusive from 0.0 (slow) to 1.0 (fast) to long delay (10 seconds) to short delay (2.0 sec)
	NSString *slideshowSpeedString = [NSString stringWithFormat:@"%d",
									  (int)(2000 + (1.0 - self.slideshowSpeed) * 8000)];
	

	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *language = [[self indexedCollection] language];
	NSString *startString	= [bundle localizedStringForString:@"Slideshow" language:language fallback:SVLocalizedString(@"Slideshow", @"Button Text/Tooltip")];
	NSString *stopString	= [bundle localizedStringForString:@"Stop" language:language fallback:SVLocalizedString(@"Stop", @"Button Text/Tooltip")];
	NSString *currentFormat	= [bundle localizedStringForString:@"{current} of {total}" language:language fallback:SVLocalizedString(@"{current} of {total}", @"Button Text/Tooltip - WITH PLACEHOLDERS IN BRACKETS")];
	NSString *previousString= [bundle localizedStringForString:@"Previous" language:language fallback:SVLocalizedString(@"Previous", @"Button Text/Tooltip")];
	NSString *nextString	= [bundle localizedStringForString:@"Next" language:language fallback:SVLocalizedString(@"Next", @"Button Text/Tooltip")];
	NSString *closeString	= [bundle localizedStringForString:@"Close" language:language fallback:SVLocalizedString(@"Close", @"Button Text/Tooltip")];
	
	CGFloat red, green, blue, alpha = 0.0;
	NSColor *backgroundAsRGB = [self.backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	[backgroundAsRGB getRed:&red green:&green blue:&blue alpha:&alpha];
	NSColor *alphaLessColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
	NSString *colorString = [alphaLessColor htmlString];
	NSString *colorCSS = [NSString stringWithFormat:@"#cboxOverlay{background:%@;}", colorString];
	NSString *opacityString = [NSString stringWithFormat:@"%.2f", alpha];
	
	
	
	// Prepare CSS
	
	path = [[NSBundle mainBundle] pathForResource:@"colorbox" ofType:@"css"];
	if (path && ![path isEqualToString:@""]) 
	{
		NSURL *cssURL = [NSURL fileURLWithPath:path];
		[context addCSSWithURL:cssURL];
	}
	//
	// Put the background color into a style; it's not something you can initialize from the JavaScript.
	//
	// FIXME: If we have multiple ColorBox objects on a single page, we can't give each a unique color.
	// I don't really see this as something we can handle with the current version of ColorBox.
	// I could ask on the list, and request a way to pass a background color like we do Opacity, so each colorbox instance can have
	// a unique background style.  Maybe even pass a background image too to be flexible?
	// Or some other way to override the normal CSS with some custom CSS specific to that colorbox?
	//
	// PARTIAL WORK-AROUND: Add the style to this PAGE, not the global CSS. FLAW: Can only add one colorbox's color.
	//
	NSRange cboxOverlayInHeader = [[context extraHeaderMarkup] rangeOfString:@"#cboxOverlay"];
	if (NSNotFound == cboxOverlayInHeader.location)
	{
		[[context extraHeaderMarkup] appendFormat:@"\n<style type='text/css'>%@</style>", colorCSS];
		
		if ([context isForEditing])
		{
			[[context extraHeaderMarkup] appendFormat:@"\n<style type='text/css'>\n"
			 @"#cboxWrapper { -webkit-transform: rotateY(0deg); }"
			 @"\n</style>", colorCSS];
		}
//#colorbox, #cboxOverlay, #cboxWrapper{position:absolute; top:0; left:0; z-index:9999; overflow:hidden;}
		
		
		
	}
	
		
	// Link (if showing) for the indexed photos
	
	if ([self.indexedPages count])
	{
		BOOL showingSomething = NO;
		
		// Build up HTML to show the slideshow, based on the indexed pages
		NSString *idName = [context startElement:@"div"
								 preferredIdName:@"gallery"
									   className:nil
									  attributes:nil];
		
		if (self.showCollectionThumbnail)
		{
			showingSomething = YES;
			
			NSString *title = nil;
			if (self.autoStartSlideshow)
			{
				title = [bundle localizedStringForString:@"Click to start slideshow."	language:language fallback:SVLocalizedString(@"Click to start slideshow.", @"Tooltip")];
			}
			else
			{
				title	= [bundle localizedStringForString:@"Click to view gallery."	language:language fallback:SVLocalizedString(@"Click to view gallery.", @"Tooltip")];
			}
			[context pushAttribute:@"title" value:title];
			
			[context pushClassName:@"imageLink"];
			[context startAnchorElementWithPage:[self indexedCollection]];
						
			[context writeImageRepresentationOfPage:[self indexedCollection]
									width:128
								   height:128
							   attributes:nil
								  options:(SVImageScaleAspectFit | SVPageImageRepresentationLink)];
			[context endElement];
		}
		
		if (self.showCollectionTitle)
		{
			showingSomething = YES;
						
			[context startElement:@"div"];
			[context startAnchorElementWithPage:[self indexedCollection]];
			[context writeCharacters:[self.indexedCollection title]];
			[context endElement];
			[context endElement];
		}
		
		// We need an "invisible" badge if we didn't have a link to show
		
		if (!showingSomething && [context isForEditing])
		{
			[context writePlaceholderWithText:SVLocalizedString(@"Gallery", "placeholder for invisible gallery index") options:SVPlaceholderInvisible];
		}
		
		// If we have something to show, hook up gallery (or slideshow) to start when item is clicked.
		
		if (showingSomething)
		{			
			NSString *clickScript = [NSString stringWithFormat:
									 @"<script type=\"text/javascript\">\n"
									 @"/* Start colorbox when clicking on '#%@' */\n"
									 @"$(document).ready(function () {\n"
									 @"	$('#%@').click(function(event) {\n"
									 @"		event.preventDefault()\n"
									 @"		$(this).find(\"a[rel='enclosure']\").colorbox({\n"
									 @"			open: true,\n"
									 @"			rel: '%@',\n"
									 @"			opacity: '%@',\n"
									 @"			transition: '%@',\n"
									 @"			loop: %@,\n"
									 @"			slideshow: %@,\n"
									 @"			slideshowAuto: %@,\n"
									 @"			slideshowSpeed: %@,\n"
									 @"			slideshowStart: '%@',\n"
									 @"			slideshowStop: '%@',\n"
									 @"			current: '%@',\n"
									 @"			previous: '%@',\n"
									 @"			next: '%@',\n"
									 @"			close: '%@',\n"
									 @"			scale: true,\n"
									 @"			maxWidth: '90%%',\n"
									 @"			maxHeight: '90%%',\n"
									 @"		});\n"
									 @"	});\n"
									 @"});\n"
									 @"</script>\n", idName, idName, idName,
									 opacityString, transitionString, loopString, slideshowString, slideshowAutoString, slideshowSpeedString,
									 startString, stopString, currentFormat, previousString, nextString, closeString
									 ];
			[context addMarkupToEndOfBody:clickScript];			
		}
		else if (!self.connectPhotoGrids)
		{
			// This is kind of hidden, but I don't want to advertise it since it is not worth showing the extra complexity.
			// When no controls, not hooked up to photo grid too: Write markup so gallery (or slideshow) automatically starts when page loads.
			
			NSString *autostartScript = [NSString stringWithFormat:
										 @"<script type=\"text/javascript\">\n"
										 @"/* Automatically open colorbox in '#%@' */\n"
										 @"$(document).ready(function () {\n"
										 @"		$('#%@').find(\"a[rel='enclosure']\").colorbox({\n"
										 @"			open: true,\n"
										 @"			rel: '%@',\n"
										 @"			opacity: '%@',\n"
										 @"			transition: '%@',\n"
										 @"			loop: %@,\n"
										 @"			slideshow: %@,\n"
										 @"			slideshowAuto: %@,\n"
										 @"			slideshowSpeed: %@,\n"
										 @"			slideshowStart: '%@',\n"
										 @"			slideshowStop: '%@',\n"
										 @"			current: '%@',\n"
										 @"			previous: '%@',\n"
										 @"			next: '%@',\n"
										 @"			close: '%@',\n"
										 @"			scale: true,\n"
										 @"			maxWidth: '90%%',\n"
										 @"			maxHeight: '90%%',\n"
										 @"	});\n"
										 @"});\n"
										 @"</script>\n", idName, idName, idName,
										 opacityString, transitionString, loopString, slideshowString, slideshowAutoString, slideshowSpeedString,
										 startString, stopString, currentFormat, previousString, nextString, closeString
										 ];
			[context addMarkupToEndOfBody:autostartScript];			
		}
		
		// Write out the invisible links
		
		for (id <SVPage> aPage in self.indexedPages)
		{
			if ([aPage respondsToSelector:@selector(thumbnailSourceGraphic)])
			{
				id source = [aPage thumbnailSourceGraphic];
				
				if ([source respondsToSelector:@selector(media)])
				{
					id mediaRecord = [source media];		// SVMediaRecord
					id media = [mediaRecord media];
					NSURL *URL = [context addMedia:media];
					if (URL)
					{
						NSString *href = [context relativeStringFromURL:URL];
						[context startAnchorElementWithHref:href title:[aPage title] target:nil rel:@"enclosure"];
						[context endElement];
					}
				}
			}
		}
		
		// Done - end the DIV.

		[context endElement]; // </div>
		
	}
	else if (self.connectPhotoGrids)		// Show our invisible badge for case where just using this to hook up to a photo grid.
	{
		if ([context isForEditing])
		{
			[context writePlaceholderWithText:SVLocalizedString(@"Gallery", "placeholder for invisible gallery") options:SVPlaceholderInvisible];
		}
	}
	// If no indexed pages, and we are not connecting to the photo grids, superclass will handle to show conventional placeholder.
	
	
	
	
	
	
	
	
	// Connect ColorBox to any Photo Grids
	
	// FIXME: If we had more than one on a single page, both would try to hook up.
	// Maybe only output this if endBodyMarkup doesn't already contain a similar block.
	
	if (self.connectPhotoGrids)
	{		
		// FIXME: Really, to group multiple photo grids together, we need a function for rel to return a unique ID of the enclosing photogrid-index
		// FIXME: Instead of '.gridItem' could we search for all .gridItem with a sub-node of an a[rel='enclosure'] ? (To skip non-photo entries)

		NSString *feed = [NSString stringWithFormat:
						  @"<script type=\"text/javascript\">\n"
						  @"/* Connect Colorbox to Photo Grids */\n"
						  @"$(document).ready(function () {\n"
						  @"	$('.gridItem').colorbox({\n"
						  @"		href: function(){ return $(this).find(\"a[rel='enclosure']\").attr('href'); },\n"
						  @"		rel: 'gridItem',\n"
						  @"		title: function(){ return $(this).text(); },\n"
						  @"		opacity: '%@',\n"
						  @"		transition: '%@',\n"
						  @"		loop: %@,\n"
						  @"		slideshow: %@,\n"
						  @"		slideshowAuto: %@,\n"
						  @"		slideshowSpeed: %@,\n"
						  @"		slideshowStart: '%@',\n"
						  @"		slideshowStop: '%@',\n"
						  @"		current: '%@',\n"
						  @"		previous: '%@',\n"
						  @"		next: '%@',\n"
						  @"		close: '%@',\n"
						  @"		scale: true,\n"
						  @"		maxWidth: '90%%',\n"
						  @"		maxHeight: '90%%',\n"
						  @"	});\n"
						  @"});\n"
						  @"</script>\n",		// ^^ Watch out for the percent signs
						  
						  opacityString, transitionString, loopString, slideshowString, slideshowAutoString, slideshowSpeedString,
						  startString, stopString, currentFormat, previousString, nextString, closeString
						  ];
		[context addMarkupToEndOfBody:feed];
	}
	
}





@end
