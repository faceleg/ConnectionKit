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
#import "Debug.h"

@implementation KTReleaseNotesController

- (NSURL *)URLToLoad;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *feedURLString = [defaults objectForKey:SUFeedURLKey];
	NSURL *feedURL = [NSURL URLWithString:[feedURLString encodeLegally]];
	NSDictionary *params = [feedURL queryDictionary];
	
	// this gives us appname and version, but not product, which we need!
	// We need the service to look up the product from the appname.
	
	NSMutableDictionary *newParams = [NSMutableDictionary dictionaryWithDictionary:params];
	[newParams setObject:@"1" forKey:@"rn"];
	
	NSURL *newURL = [NSURL URLWithBaseURL:
					 [NSURL URLWithString:
					  [NSString stringWithFormat:@"%@changelog.php",
					   [[NSUserDefaults standardUserDefaults] objectForKey:@"HomeBaseURL"]
					   ]]
							   parameters:newParams];
	DJW((@"release notes URL = %@", newURL));
	return newURL;
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
