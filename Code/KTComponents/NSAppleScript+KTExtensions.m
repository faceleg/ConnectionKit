//
//  NSAppleScript+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 1/30/06.
//  Copyright (c) 2006 Biophony LLC. All rights reserved.
//

#import "NSAppleScript+Karelia.h"
#import "KTAbstractPlugin.h"			// just a class known to be in KTComponents
#import "NSString+Karelia.h"


static NSAppleScript *sSafariFrontmostFeedScript = nil;


@interface NSAppleScript (KTExtensionsPrivate)
+ (void)_getWebBrowserURL:(NSURL **)URL title:(NSString **)title source:(NSString **)source;
+ (void)getWebBrowserURL:(NSURL **)URL title:(NSString **)title source:(NSString **)source withScriptNamed:(NSString *)scriptName;
@end


@implementation NSAppleScript ( KTExtensions )

/*	Fetches the requested information about the user's web browser, but only if it is enabled in the preferences
 */
+ (void)getWebBrowserURL:(NSURL **)URL title:(NSString **)title source:(NSString **)source
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GetURLsFromSafari"])
	{
		[self _getWebBrowserURL:URL title:title source:source];
	}
}

/*	Same as the above method, but does not check the user's preferences
 */
+ (void)_getWebBrowserURL:(NSURL **)URL title:(NSString **)title source:(NSString **)source
{
	NSString *browserIdentifier = nil;
	
	
	// Is the user's preferred web browser launched?
	NSBundle *preferredBrowserBundle =
		[NSBundle bundleWithPath:[[NSWorkspace sharedWorkspace] applicationForURL:[NSURL URLWithString:@"http://"]]];
	
	NSSet *supportedBrowsers = [NSSet setWithObjects:@"com.operasoftware.Opera",
													 @"com.apple.Safari",
													 @"org.mozilla.camino",
													 @"org.mozilla.firefox",
													 @"com.omnigroup.OmniWeb5", nil];
	
	NSString *preferredBrowserIdentifier = [preferredBrowserBundle bundleIdentifier];
	
	if ([supportedBrowsers containsObject:preferredBrowserIdentifier] &&
		[[NSWorkspace sharedWorkspace] applicationWithBundleIdentifierIsLaunched:preferredBrowserIdentifier])
	{
		browserIdentifier = preferredBrowserIdentifier;
	}
	
	
	// If the user's preferred app isn't launch find the next best
	if (!browserIdentifier)
	{
		if ([[NSWorkspace sharedWorkspace] applicationWithBundleIdentifierIsLaunched:@"com.apple.Safari"]) {
			browserIdentifier = @"com.apple.Safari";
		}
		else if ([[NSWorkspace sharedWorkspace] applicationWithBundleIdentifierIsLaunched:@"org.mozilla.firefox"]) {
			browserIdentifier = @"org.mozilla.firefox";
		}
		else if ([[NSWorkspace sharedWorkspace] applicationWithBundleIdentifierIsLaunched:@"org.mozilla.camino"]) {
			browserIdentifier = @"org.mozilla.camino";
		}
		else if ([[NSWorkspace sharedWorkspace] applicationWithBundleIdentifierIsLaunched:@"com.operasoftware.Opera"]) {
			browserIdentifier = @"com.operasoftware.Opera";
		}
		else if ([[NSWorkspace sharedWorkspace] applicationWithBundleIdentifierIsLaunched:@"com.omnigroup.OmniWeb5"]) {
			browserIdentifier = @"com.omnigroup.OmniWeb5";
		}
	}
	
	
	if (browserIdentifier)
	{
		// Convert the bundle identifier to the name of the script to run
		NSString *appName = nil;
		
		if ([browserIdentifier isEqualToString:@"com.apple.Safari"]) {
			appName = @"Safari";
		}
		else if ([browserIdentifier isEqualToString:@"org.mozilla.camino"]) {
			appName = @"Camino";
		}
		else if ([browserIdentifier isEqualToString:@"org.mozilla.firefox"]) {
			appName = @"Firefox";
		}
		else if ([browserIdentifier isEqualToString:@"com.operasoftware.Opera"]) {
			appName = @"Opera";
		}
		else if ([browserIdentifier isEqualToString:@"com.omnigroup.OmniWeb5"]) {
			appName = @"OmniWeb";
		}
		
		if (appName)
		{
			NSString *scriptName = [NSString stringWithFormat:@"get%@FrontmostPage", appName];
			OBASSERT (scriptName);
			
			
			// Run the script and retrieve the info
			[self getWebBrowserURL:URL title:title source:source withScriptNamed:scriptName];
		}
	}
}

/*	Private method that fetches the various browser properties using the chosen script
 */
+ (void)getWebBrowserURL:(NSURL **)outURL title:(NSString **)outTitle source:(NSString **)outSource withScriptNamed:(NSString *)scriptName;
{
	// Load the script
	NSString *scriptPath = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"scpt"];
	NSURL *scriptURL = [NSURL fileURLWithPath: scriptPath];
	
	NSDictionary *errorInfo = nil;	// God knows why NSAppleScript doesn't use NSError for errors
	NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&errorInfo];
	if (errorInfo) {
		NSLog(@"%@: %@", NSStringFromSelector(_cmd), errorInfo);
		return;
	}
	
	
	// Run the script
	NSAppleEventDescriptor *scriptResult = [script executeAndReturnError:&errorInfo];
	
	if (errorInfo) {
		NSLog(@"%@: %@", NSStringFromSelector(_cmd), errorInfo);
	}
	
	if (scriptResult && [scriptResult descriptorType] != typeNull && [scriptResult numberOfItems] == 3)
	{
		// Decode the script results and return them
		NSAppleEventDescriptor *urlDescriptor = [scriptResult descriptorAtIndex:1];
		NSAppleEventDescriptor *titleDescriptor = [scriptResult descriptorAtIndex:2];
		NSAppleEventDescriptor *sourceDescriptor = [scriptResult descriptorAtIndex:3];
		
		if (outURL)
		{
			NSString *URLString = [urlDescriptor stringValue];
			if (URLString && ![URLString isEqualToString:@""]) {
				*outURL = [NSURL URLWithString:[[urlDescriptor stringValue] encodeLegally]];
			}
		}
		
		if (outTitle)
		{
			NSString *title = [titleDescriptor stringValue];
			if (title && ![title isEqualToString:@""]) {
				*outTitle = title;
			}
		}
		
		if (outSource)
		{
			NSString *source = [sourceDescriptor stringValue];
			if (source && ![source isEqualToString:@""]) {
				*outSource = source;
			}
		}
	}
	
	
	// Tidy up
	[script release];
}

/*!	Returns path of running Safari, or nil if not running.
*/
+ (NSString *)getRunningSafariPath
{
	NSArray *apps = [[NSWorkspace sharedWorkspace] launchedApplications];
	NSEnumerator *theEnum = [apps objectEnumerator];
	id dict;
	
	while (nil != (dict = [theEnum nextObject]) )
	{
		if ([[dict objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:@"com.apple.Safari"])
		{
			return [dict objectForKey:@"NSApplicationPath"];
		}
	}
	return nil;
}

/*	Deprecated in favour of -getFrontmostWebBrowserURL:title:source:
 *	The method now just calls through to that
 */
+ (BOOL)safariFrontmostURL:(NSURL **)outURL title:(NSString **)outTitle source:(NSString **)outSource
{
	[self getWebBrowserURL:outURL title:outTitle source:outSource];
	return YES;
}

+ (BOOL)safariFrontmostFeedURL:(NSURL **)outURL title:(NSString **)outTitle
{
	BOOL result = NO;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"GetURLsFromSafari"])
	{
		if (nil != [self getRunningSafariPath])
		{
			if (nil == sSafariFrontmostFeedScript)
			{
				// Load the Safari script
				NSBundle *bundle = [NSBundle bundleForClass: [KTAbstractPlugin class]];
				NSString *scriptPath = [bundle pathForResource:@"getSafariFrontmostFeed" ofType:@"scpt"];
				NSURL *scriptURL = [NSURL fileURLWithPath: scriptPath];
				
				NSDictionary *error = nil;	// God knows why NSAppleScript doesn't use NSError for errors
				sSafariFrontmostFeedScript = [[NSAppleScript alloc] initWithContentsOfURL: scriptURL error: &error];
				if (error) {
					NSLog(@"%@: %@", NSStringFromSelector(_cmd), error);
				}
			}
			
			NSDictionary *errorDict = nil;
			NSAppleEventDescriptor *descr = [sSafariFrontmostFeedScript executeAndReturnError:&errorDict];
			
			if (nil != descr && typeNull != [descr descriptorType] && 3 == [descr numberOfItems])
			{
				NSAppleEventDescriptor *feedURLDescriptor = [descr descriptorAtIndex:1];
				NSAppleEventDescriptor *pageURLDescriptor = [descr descriptorAtIndex:2];
				NSAppleEventDescriptor *titleDescriptor = [descr descriptorAtIndex:3];
				if (nil != outURL)
				{
					NSString *urlString = [pageURLDescriptor stringValue];
					if ([urlString hasPrefix:@"feed://"])
					{
						if (nil != urlString)
						{
							*outURL = [NSURL URLWithString:[urlString encodeLegally]];
						}
					}
					else
					{
						urlString = [feedURLDescriptor stringValue];
						if ([urlString hasPrefix:@"http://"])
						{
							urlString= [NSString stringWithFormat:@"feed://%@", [urlString substringFromIndex:7]];
						}
						if (nil != urlString && ![urlString isEqualToString:@""])
						{
							*outURL = [NSURL URLWithString:[urlString encodeLegally]];
						}
					}
				}
				if (nil != outTitle && nil != [titleDescriptor stringValue] && ![[titleDescriptor stringValue] isEqualToString:@""])
				{
					*outTitle = [titleDescriptor stringValue];
				}
				result = YES;
			}
		}
	}
	return result;
}

@end
