//
//  KTReleaseNotesController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
#import <Cocoa/Cocoa.h>
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
	NSArray *feedParams = [[NSApp delegate] feedParametersForUpdater:nil sendingSystemProfile:NO];
		// above is an array of dictionaries with keys of "key" and "value"
		// we want to convert this into a simple dicationary.
	
	NSMutableDictionary *simpleParameters = [NSMutableDictionary dictionary];
	NSDictionary *oneParamDict;
	for (oneParamDict in feedParams)
	{
		[simpleParameters setObject:[oneParamDict objectForKey:@"value"] forKey:[oneParamDict objectForKey:@"key"]];
	}	
	// Add our key  that makes this into release notes
	[simpleParameters setObject:@"1" forKey:@"rn"];

	NSURL *baseURL = [NSURL URLWithString:@"changelog.php" relativeToURL:[[NSApp delegate] homeBaseURL]];
	NSURL *result = [NSURL URLWithBaseURL:baseURL parameters:simpleParameters];
	
	DJW((@"release notes URL = %@", result));
	return result;
}

- (void)windowDidLoad
{
	[[oWebView mainFrame] loadRequest:
	 [NSURLRequest requestWithURL:[self URLToLoad]
					  cachePolicy:NSURLRequestReloadIgnoringCacheData
				  timeoutInterval:20.0]];
    
	[[self window] setTitle:NSLocalizedString(@"Sandvox Release Notes", "Release Notes Window Title")];
    [[self window] setFrameAutosaveName:@"ReleaseNotesWindow"];    
}

@end
