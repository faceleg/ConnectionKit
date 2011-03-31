//
//  SVColorBoxIndexPlugIn.m
//  Sandvox
//
//  Created by Dan Wood on 3/25/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVColorBoxIndexPlugIn.h"

#import "SVPageProtocol.h"
#import "SVPagesController.h"
#import "SVHTMLContext.h"
#import "NSBundle+Karelia.h"
#import "NSColor+Karelia.h"
#import "KTPage.h"

// Uses Colorbox 1.3.16, from http://colorpowered.com/colorbox/

@implementation SVColorBoxIndexPlugIn

@synthesize useColorBox			= _useColorBox;

@synthesize transitionType		= _transitionType;
@synthesize loop				= _loop;
@synthesize enableSlideshow		= _enableSlideshow;
@synthesize autoStartSlideshow	= _autoStartSlideshow;
@synthesize slideshowSpeed		= _slideshowSpeed;
@synthesize backgroundColor		= _backgroundColor;

@synthesize slideshowType		= _slideshowType;

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
						   @"useColorBox",
						   @"transitionType",
                           @"loop",
						   @"enableSlideshow",
                           @"autoStartSlideshow",
						   @"slideshowSpeed",
						   @"backgroundColor",
						   
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}

- (void)awakeFromNew
{
	self.useColorBox				= NO;
	self.transitionType				= kOverlayTransitionElastic;
	self.loop						= NO;
	self.enableSlideshow			= YES;
	self.autoStartSlideshow			= NO;
	self.slideshowSpeed				= 0.75;
	self.backgroundColor			= [NSColor colorWithCalibratedWhite:0.0 alpha:0.5];
	
    [super awakeFromNew];
}

+ (NSSet *) keyPathsForValuesAffectingSlideshowType;
{
    return [NSSet setWithObjects:@"enableSlideshow", @"autoStartSlideshow", nil];
}
- (int)slideshowType;
{
	if (!self.enableSlideshow)		return kSlideshowNone;
	if (!self.autoStartSlideshow)	return kSlideshowManual;
	return kSlideshowAutomatic;
}
- (void)setSlideshowType:(int)slideshowType;
{
	self.enableSlideshow = (kSlideshowNone != slideshowType);
	self.autoStartSlideshow = (kSlideshowAutomatic == slideshowType);
}

- (NSString *)parameterLineForPreviewOnly:(id <SVPlugInContext>)context;
{
	NSString *result = [context isForEditing]
	?
	@"			onLoad: function(){ WEKWebEditorView.deselectDOMRange(); },\n"
	:	@"";
	return result;
	
}
// Called by subclass when building up script

- (NSString *)colorBoxParametersWithGroupID:(NSString *)idName;
{
	// Hidden defaults to specify the width.  If we specify zero, then false (no scaling!) is passed in. 
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	int widthPercent = [defaults integerForKey:@"GalleryPercentWidth"];
	int heightPercent = [defaults integerForKey:@"GalleryPercentHeight"];
	NSString *widthPercentString  = widthPercent  ? [NSString stringWithFormat:@"%d", widthPercent]  : @"false";
	NSString *heightPercentString = heightPercent ? [NSString stringWithFormat:@"%d", heightPercent] : @"false";

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
	NSString *startString	= [bundle localizedStringForString:@"Slideshow" language:language fallback:NSLocalizedString(@"Slideshow", @"Button Text/Tooltip")];
	NSString *stopString	= [bundle localizedStringForString:@"Stop" language:language fallback:NSLocalizedString(@"Stop", @"Button Text/Tooltip")];
	NSString *currentFormat	= [bundle localizedStringForString:@"{current} of {total}" language:language fallback:NSLocalizedString(@"{current} of {total}", @"Button Text/Tooltip - WITH PLACEHOLDERS IN BRACKETS")];
	NSString *previousString= [bundle localizedStringForString:@"Previous" language:language fallback:NSLocalizedString(@"Previous", @"Button Text/Tooltip")];
	NSString *nextString	= [bundle localizedStringForString:@"Next" language:language fallback:NSLocalizedString(@"Next", @"Button Text/Tooltip")];
	NSString *closeString	= [bundle localizedStringForString:@"Close" language:language fallback:NSLocalizedString(@"Close", @"Button Text/Tooltip")];
	
	NSColor *backgroundAsRGB = [self.backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat alphaComponent = [backgroundAsRGB alphaComponent];
	NSString *opacityString = [NSString stringWithFormat:@"%.2f", alphaComponent];
	
	NSString *result = [NSString stringWithFormat:
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
						@"			maxWidth: '%@%%',\n"
						@"			maxHeight: '%@%%',\n"
						//					// ^^ Watch out for the percent signs
						, idName,
						opacityString, transitionString, loopString, slideshowString, slideshowAutoString, slideshowSpeedString,
						startString, stopString, currentFormat, previousString, nextString, closeString,
						widthPercentString, heightPercentString
						];
	return result;
	
}

- (void)writeJavaScriptLoader:(SVHTMLContext *)context;
{
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
		NSURL *URL = [context addResourceAtURL:[NSURL fileURLWithPath:path] destination:SVDestinationResourcesDirectory options:0];
		NSString *srcPath = [context relativeStringFromURL:URL];
		NSString *script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", srcPath];
		[context addMarkupToEndOfBody:script];
	}
}

- (void)writeCSS:(SVHTMLContext *)context;
{
	NSString *path = [[NSBundle mainBundle] pathForResource:@"colorbox" ofType:@"css"];
	if (path && ![path isEqualToString:@""]) 
	{
		NSURL *cssURL = [NSURL fileURLWithPath:path];
		[context addResourceAtURL:cssURL destination:SVDestinationMainCSS options:0];
	}
	//
	// Put the background color into a style; it's not something you can initialize from the JavaScript.
	//
	// WARNING: If we have multiple ColorBox objects on a single page, we can't give each a unique color.
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
		CGFloat red, green, blue = 0.0;
		NSColor *backgroundAsRGB = [self.backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
		[backgroundAsRGB getRed:&red green:&green blue:&blue alpha:nil];
		NSColor *alphaLessColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
		NSString *colorString = [alphaLessColor htmlString];
		NSString *colorCSS = [NSString stringWithFormat:@"#cboxOverlay{background:%@;}", colorString];
		
		[[context extraHeaderMarkup] appendFormat:@"\n<style type='text/css'>%@</style>", colorCSS];
	}
}

- (void)writeHTML:(SVHTMLContext *)context;
{
	[super writeHTML:context];
	[context addDependencyForKeyPath:@"useColorBox"				ofObject:self];
	[context addDependencyForKeyPath:@"transitionType"			ofObject:self];
	[context addDependencyForKeyPath:@"loop"					ofObject:self];
	[context addDependencyForKeyPath:@"enableSlideshow"			ofObject:self];
	[context addDependencyForKeyPath:@"autoStartSlideshow"		ofObject:self];
	[context addDependencyForKeyPath:@"slideshowSpeed"			ofObject:self];
	[context addDependencyForKeyPath:@"backgroundColor"			ofObject:self];

	if (self.useColorBox)	// Photo grid might not have any color box, so only add markup if needed.
	{
		NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"colorbox"];
		if (path)
		{
			(void) [context addResourceAtURL:[NSURL fileURLWithPath:path isDirectory:YES]
                               destination:SVDestinationDesignDirectory
                                     options:0];
		}
		
		[self writeCSS:context];
		[self writeJavaScriptLoader:context];
	}
}

@end
