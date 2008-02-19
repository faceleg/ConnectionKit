//
//  KTNewsController.m
//  Marvel
//
//  Created by Dan Wood on 9/26/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTNewsController.h"

#import "KT.h"
#import "KTApplication.h"
#import "KTAppDelegate.h"
#import <Sandvox.h>
#import "SandvoxPrivate.h"
#import "NTBoxView.h"

static KTNewsController *sSharedNewsController = nil;

/*!	Simple KV accessors on XML elements, assumes we know if there are going to be 1 or > 1 children.
	Returns an array if > 1 child; the object if only 1 child.
*/
@interface NSXMLElement ( KV )

- (id)valueForUndefinedKey:(NSString *)aKey;

@end

@implementation NSXMLElement ( KV )

- (id)valueForUndefinedKey:(NSString *)aKey;
{
	id result = nil;
	
	// remove "AsString" suffix
	NSRange whereString = [aKey rangeOfString:@"AsString" options:NSBackwardsSearch | NSAnchoredSearch];
	BOOL wantString = (NSNotFound != whereString.location);
	if (wantString)
	{
		aKey = [aKey substringWithRange:NSMakeRange(0,whereString.location)];
	}
	
	// remove "AsDate" suffix
	NSRange whereDate = [aKey rangeOfString:@"AsDate" options:NSBackwardsSearch | NSAnchoredSearch];
	BOOL wantDate = (NSNotFound != whereDate.location);
	if (wantDate)
	{
		aKey = [aKey substringWithRange:NSMakeRange(0,whereDate.location)];
	}
	
	NSArray *elements = [self elementsForName:aKey];
	if ([elements count] > 1)
	{
		result = elements;
	}
	else if ([elements count])
	{
		result = [elements objectAtIndex:0];
		if (wantString)
		{
			result = [result stringValue];
		}
		else if (wantDate)
		{
			NSString *dateString = [result stringValue];
			NSCalendarDate *date = [NSDate dateWithRFC822String:dateString];
			result = [date relativeFormatWithStyle:NSDateFormatterMediumStyle];
		}
	}
	return result;
}

@end



@interface KTNewsController ( Private )
- (NSMutableData *)RSSData;
- (void)setRSSData:(NSMutableData *)aRSSData;
- (NSURLConnection *)URLConnection;
- (void)setURLConnection:(NSURLConnection *)anURLConnection;
@end

@implementation KTNewsController

+ (KTNewsController *)sharedNewsController;
{
    if ( nil == sSharedNewsController ) {
        sSharedNewsController = [[self alloc] init];
    }
    return sSharedNewsController;
}

- (id)init
{
    self = [super initWithWindowNibName:@"News"];
    return self;
}

- (void)dealloc
{
	[self setRSSData:nil];
	[self setURLConnection:nil];
	[super dealloc];
}

- (void)windowDidLoad
{
	[oBox setDrawsFrame:YES];
	[oBox setBorderMask:NTBoxTop];
	[oWebView setPolicyDelegate:self];

	[super windowDidLoad];
}

- (IBAction) showWindow:(id)sender
{
	[super showWindow:sender];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
						   withObject:nil
						   afterDelay:0.0];
	
	[[oWebView mainFrame] loadHTMLString:
		[NSString stringWithFormat:@"<html><body style=\"font: 13px 'Lucida Grande',sans-serif;\">%@</body></html>", 
			NSLocalizedString(@"Loading...",@"Indication that text is loading into webview")]
								 baseURL:nil];
	[self loadRSSFeed];
}

- (void)loadRSSFeed;		 // loads Sandvox news into our window
{
	[self setRSSData:[NSMutableData data]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.karelia.com/news/index.xml"]
							 cachePolicy:NSURLRequestUseProtocolCachePolicy
						 timeoutInterval:10.0];
	NSURLConnection *theConnection=[[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
	if (theConnection)
	{
		[self setURLConnection:theConnection];
	}	
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
    [myRSSData setLength:0];
	
	if ([response respondsToSelector:@selector(statusCode)])
	{
		int statusCode = [((NSHTTPURLResponse *)response) statusCode]; 
		if (statusCode >= 400)
		{
			[connection cancel];
			[self connection:connection didFailWithError:[NSError errorWithHTTPStatusCode:statusCode URL:[response URL]]];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append the new data to the myRSSData
    [myRSSData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSError *error = nil;
	NSXMLDocument *xmlDoc = nil;
	if (nil != myRSSData && [myRSSData length])
	{
		xmlDoc = [[[NSXMLDocument alloc] initWithData:myRSSData options:0 error:&error] autorelease];
	}
	if (nil != xmlDoc)
	{
		NSString *path = [[NSBundle mainBundle] pathForResource:@"NewsTemplate" ofType:@"html"];
		if (nil != path)
		{
			NSData *data = [NSData dataWithContentsOfFile:path];
			NSString *htmlTemplate = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			
			NSString *parsedHTML = [KTHTMLParser HTMLStringWithTemplate:htmlTemplate component:[xmlDoc rootElement]];
			
			NSString *tempDir = NSTemporaryDirectory();
			NSString *tempPath = [tempDir stringByAppendingPathComponent:
								  [NSString stringWithFormat:@"Sandvox-News.html"]];
			NSError *err = nil;
			[parsedHTML writeToFile:tempPath atomically:NO encoding:NSUTF8StringEncoding error:&err];
			
			NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:tempPath]];
			
			[[oWebView mainFrame] loadRequest:request];

			/// OLD: [[oWebView mainFrame] loadHTMLString:parsedHTML baseURL:nil];

		}
	}
	else
	{
		NSString *desc = @"";
		if (error) {
			desc = [[error localizedDescription] escapedEntities];
		}
		
		[[oWebView mainFrame] loadHTMLString:
			[NSString stringWithFormat:@"<html><body style=\"font: 13px 'Lucida Grande',sans-serif;\"><b>%@</b><br /><br />%@</body></html>", 
				NSLocalizedString(@"Unable to load news feed.",@""),
				desc]
									 baseURL:nil];
	}
	// release the connection, and the data object
    [self setURLConnection:nil];
    [self setRSSData:nil];

	// Now that we have loaded the news, mark it as not needing to be seen
	[[NSApp delegate] setNewsHasChanged:NO];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSDate date] forKey:@"lastSawFeedDate"];
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTBadgeUpdateNotification
														object:nil]; 
	
}

- (void)connection:(NSURLConnection *)connection
		didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [self setURLConnection:nil];
    [self setRSSData:nil];
	[[oWebView mainFrame] loadHTMLString:
		[NSString stringWithFormat:@"<html><body style=\"font: 13px 'Lucida Grande',sans-serif;\"><b>%@</b><br /><br />%@</body></html>", 
			NSLocalizedString(@"Unable to load news feed.",@""),
			[[error localizedDescription] escapedEntities]]
								 baseURL:nil];
}


- (NSMutableData *)RSSData
{
    return myRSSData; 
}

- (void)setRSSData:(NSMutableData *)aRSSData
{
    [aRSSData retain];
    [myRSSData release];
    myRSSData = aRSSData;
}


- (NSURLConnection *)URLConnection
{
    return myURLConnection; 
}

- (void)setURLConnection:(NSURLConnection *)anURLConnection
{
    [anURLConnection retain];
    [myURLConnection release];
    myURLConnection = anURLConnection;
}

- (IBAction) windowHelp:(id)sender
{
	[NSApp showHelpPage:@"Sandvox_News"];	// HELPSTRING
}

#pragma mark -
#pragma mark Web View delegate

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSURL *url = [actionInformation objectForKey:@"WebActionOriginalURLKey"];
	NSString *scheme = [url scheme];
	
	// We allow loading of an HTML string, but any other URLs must be opened in the user's browser
	if ([scheme isEqualToString:@"applewebdata"] || [scheme isEqualToString:@"file"])
	{
		[listener use];
	}
	else
	{
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

@end
