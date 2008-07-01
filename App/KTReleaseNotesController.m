//
//  KTReleaseNotesController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTReleaseNotesController.h"
#import <Sparkle/Sparkle.h>
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSBundle+Karelia.h"
#import "Debug.h"
#import "KSAppDelegate.h"

@implementation KTReleaseNotesController

- (NSURL *)URLToLoad;
{
	NSArray *feedParams = [[NSApp delegate] feedParametersForHostBundle:[NSBundle mainBundle] sendingSystemProfile:NO];
	NSMutableArray *rnParams = [NSMutableArray arrayWithArray:feedParams];
	[rnParams addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"rn", @"key", @"1", @"value", nil]];
	
	NSURL *newURL = [NSURL URLWithString:@"changelog.php" relativeToURL:[[NSBundle mainBundle] homeBaseURL]];
	NSURL *feedURL = [newURL URLWithParameters:rnParams];
	DJW((@"release notes URL = %@", feedURL));
	return feedURL;
}

- (void)windowDidLoad
{
	[[oWebView mainFrame] loadRequest:
	 [NSURLRequest requestWithURL:[self URLToLoad]
					  cachePolicy:NSURLRequestReloadIgnoringCacheData
				  timeoutInterval:10.0]];
    
	[[self window] setTitle:NSLocalizedString(@"Sandvox Release Notes", "Release Notes Window Title")];
    [[self window] setFrameAutosaveName:@"ReleaseNotesWindow"];    
}

@end
