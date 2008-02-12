//
//  KTDesignManager.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	UI for selecting a design for a page or site.

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	x

 */

#import "KTDesignManager.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "PrivateComponents.h"

static NSImage *sUnknownThumbnail;

@implementation KTDesignManager

+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	sUnknownThumbnail = [[NSImage imageNamed:@"qmark"] retain];
	[pool release];
}

- (id)init
{
    self = [super init];
    if (self) {

		NSDictionary *designPlugins = [KTUtilities pluginsWithExtension:kKTDesignExtension sisterDirectory:@"Designs"];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];

		NSEnumerator *enumerator = [designPlugins keyEnumerator];
		NSString *key;

		while (key = [enumerator nextObject])
		{
			KTDesign *designPlugin = [designPlugins objectForKey:key];
			NSString *path = [[designPlugin bundle] pathForResource:@"main" ofType:@"css"];
			if (nil == path)
			{
				NSLog(@"Couldn't find main.css for %@, not enabling design", [[designPlugin bundle] bundlePath]);
			}
			else
			{
				[dict setObject:designPlugin forKey:key];
			}
		}
		[self setDesigns:dict];
		
		NSArray *sortedNames = 	[[dict allValues] sortedArrayUsingSelector:@selector(compareTitles:)];

		[self setSortedDesigns:sortedNames];

	}
    return self;
}

- (void)dealloc
{
	[self setDesigns:nil];
	[self setSortedDesigns:nil];
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors


- (NSDictionary *)designs
{
    return myDesigns; 
}

- (void)setDesigns:(NSDictionary *)aDesigns
{
    [aDesigns retain];
    [myDesigns release];
    myDesigns = aDesigns;
}

- (NSArray *)sortedDesigns
{
    return mySortedDesigns; 
}

- (void)setSortedDesigns:(NSArray *)aSortedDesigns
{
    [aSortedDesigns retain];
    [mySortedDesigns release];
    mySortedDesigns = aSortedDesigns;
}

#pragma mark -
#pragma mark Design Bundle Management

- (KTDesign *)designForIdentifier:(NSString *)anIdentifier
{
	return [myDesigns objectForKey:anIdentifier];
}

- (NSString *)designReportShowingAll:(BOOL)aShowAll	// if false, just shows third-party ones
{
	NSMutableString *string = [NSMutableString string];
	NSString *builtInPath = [[NSBundle mainBundle] bundlePath];
	NSEnumerator *theEnum = [myDesigns objectEnumerator];
	KTDesign *design;
	
	while (nil != (design = [theEnum nextObject]) )
	{
		NSBundle *bundle = [design bundle];
		NSString *bundlePath = [bundle bundlePath];
		if ([bundlePath hasPrefix:builtInPath] && !aShowAll)
		{
			continue;
		}
		[string appendFormat:@"%@\t%@", [bundle bundleIdentifier], [bundle version]];
		if (nil != [bundle buildVersion])
		{
			[string appendFormat:@" (%@)", [bundle buildVersion]];
		}
		[string appendString:@"\n"];
	}
	return string;
}


@end
