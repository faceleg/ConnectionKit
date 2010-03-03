//
//  IMStatusPlugin.m
//  IMStatusElement
//
//  Created by Dan Wood on 3/3/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "IMStatusPlugin.h"
#import "IMStatusInspector.h"
#import "IMStatusService.h"
#import "ABPerson+IMStatus.h"
#import <AddressBook/AddressBook.h>

NSString *IMServiceKey = @"service";
NSString *IMHTMLKey = @"html"; 
NSString *IMOnlineImageKey = @"online";
NSString *IMOfflineImageKey = @"offline";
NSString *IMWantBorderKey = @"wantBorder";


@interface IMStatusPlugin ()
- (NSString *)onlineImagePath;
- (NSString *)offlineImagePath;
@end


@implementation IMStatusPlugin

@synthesize headlineText = _headlineText;
@synthesize onlineText = _onlineText;
@synthesize offlineText = _offlineText;
@synthesize username = _username;
@synthesize selectedIMService = _selectedIMService;


+ (Class)inspectorViewControllerClass { return [IMStatusInspector class]; }
+ (NSSet *)plugInKeys
{
	return [NSSet setWithObjects:@"headlineText", @"onlineText", @"offlineText", 
			@"username", @"selectedIMService", nil];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (isNewObject)
	{
		self.headlineText = LocalizedStringInThisBundle(@"Chat with me", @"Short headline for badge inviting website viewer to iChat/Skype chat with the owner of the website");
		self.offlineText = LocalizedStringInThisBundle(@"offline", @"status indicator of chat; offline or unavailable");
		self.onlineText = LocalizedStringInThisBundle(@"online", @"status indicator of chat; online or available");
		
		// Try to set the username and service from the user's address book
		ABPerson *card = [[ABAddressBook sharedAddressBook] me];
		
		int service = IMServiceSkype;
		NSString *username = nil;
		
		username = [card firstAIMUsername];
		if (username) {
			service = IMServiceIChat;
		}
		else
		{
			username = [card firstYahooUsername];
			if (username) {
				service = IMServiceYahoo;
			}
		}
		
		self.selectedIMService = service;
		self.username = username;
	}
	
	// LocalizedStringInThisBundle(@"(Please set your ID using the Pagelet Inspector)", @"Used in template");
	
}


#pragma mark -
#pragma mark Initialization


+ (NSImage *)baseOnlineIChatImage
{
	static NSImage *sOnlineBaseImage;
	
	if (!sOnlineBaseImage)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"online"];
		sOnlineBaseImage = [[NSImage alloc] initWithContentsOfFile:path];
		[sOnlineBaseImage normalizeSize];
	}
	
	return sOnlineBaseImage;
}

+ (NSImage *)baseOfflineIChatImage
{
	static NSImage *sOfflineBaseImage;
	
	if (!sOfflineBaseImage)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"offline"];
		sOfflineBaseImage = [[NSImage alloc] initWithContentsOfFile:path];
		[sOfflineBaseImage normalizeSize];
	}
	
	return sOfflineBaseImage;
}

- (id)init	// Note: [self bundle] not yet defined!
{
	if ((self = [super init]))
	{
		myConfigs = [[NSMutableArray alloc] initWithCapacity:4];
		
		NSMutableDictionary *ichat = [NSMutableDictionary dictionary];
		[ichat setObject:@"iChat" forKey:IMServiceKey];
		[ichat setObject:@"<a class=\"imageLink\" href=\"aim:goim?screenname=#USER#\"><img src=\"http://big.oscar.aol.com/#USER#?on_url=#ONLINE#&amp;off_url=#OFFLINE#\" alt=\"#HEADLINE#\" width=\"175\" height=\"75\" border=\"0\" /></a>" forKey:IMHTMLKey];
		[ichat setObject:@"online.png" forKey:IMOnlineImageKey];
		[ichat setObject:@"offline.png" forKey:IMOfflineImageKey];
		[myConfigs addObject:ichat];
		
		
		NSMutableDictionary *skype = [NSMutableDictionary dictionary];
		[skype setObject:@"Skype" forKey:IMServiceKey];
		[skype setObject:@"<script type=\"text/javascript\" src=\"http://download.skype.com/share/skypebuttons/js/skypeCheck.js\"></script><a class=\"imageLink\" href=\"skype:#USER#?call\"><img src=\"http://mystatus.skype.com/bigclassic/#USER#\" style=\"border: none;\" width=\"182\" height=\"44\" alt=\"#HEADLINE#\" /></a>" forKey:IMHTMLKey];
		[skype setObject:[NSNumber numberWithBool:YES] forKey:IMWantBorderKey];
		NSString *pathForSkype = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"online_skype"];
		if (pathForSkype) {
			[skype setObject:pathForSkype forKey:IMOnlineImageKey];
		}
		[myConfigs addObject:skype];
		
		
		NSMutableDictionary *yahoo = [NSMutableDictionary dictionary];
		[yahoo setObject:@"Yahoo! Messenger" forKey:IMServiceKey];
		[yahoo setObject:@"<a class=\"imageLink\" href=\"<a href=\"http://edit.yahoo.com/config/send_webmesg?.target=#USER#&src=pg\"><img border=\"0\" src=\"http://opi.yahoo.com/online?u=#USER#&m=g&t=1\" /></a>" forKey:IMHTMLKey];
		[yahoo setObject:@"online.png" forKey:IMOnlineImageKey];
		[yahoo setObject:@"offline.png" forKey:IMOfflineImageKey];
		[myConfigs addObject:yahoo];
		
		
		// Add any from user defaults
		NSArray *ud = [[NSUserDefaults standardUserDefaults] objectForKey:@"IMServices"];
		if (ud)
		{ 
			[myConfigs addObjectsFromArray:ud];
		}	
	}
	return self;
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[myConfigs release];
	[super dealloc];
}

#pragma mark -
#pragma mark Services

/*	Convenient shortcut to the equivalent class method so it can be bound to
 */
- (NSArray *)services
{
	return [IMStatusService services];
}

- (IMStatusService *)selectedService
{
	return [[IMStatusService services] objectAtIndex:self.selectedIMService];
}

#pragma mark -
#pragma mark HTML

- (NSString *)generateHTMLPublishing:(BOOL)isPublishing livePreview:(BOOL)isLivePreview
{
	//return nil;
	
	/*
	 return [[self selectedService] badgeHTMLWithUsername:self.username
	 headline:self.headlineText
	 onlineLabel:self.onlineText
	 offlineLabel:self.offlineText
	 isPublishing:publishing
	 livePreview:livePreview];
	 */
	
	IMStatusService *service = [self selectedService];
	
	// Get the appropriate code for the publishing mode
	NSString *HTMLCode = nil;
	if (isPublishing) {
		HTMLCode = [service publishingHTMLCode];
	}
	else if (isLivePreview) {
		HTMLCode = [service livePreviewHTMLCode];
	}
	else {
		HTMLCode = [service nonLivePreviewHTMLCode];
	}
	
	NSMutableString *result = [NSMutableString stringWithString:HTMLCode];
	
	// Parse the code to get the finished HTML
	[result replaceOccurrencesOfString:@"#USER#" 
						    withString:[self.username stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]
							   options:NSLiteralSearch 
							     range:NSMakeRange(0, [result length])];
	
	NSString *onlineImagePath = [self onlineImagePath];
	if (onlineImagePath)
	{
		// How we reference the path depends on publishing/previewing
		if (isPublishing) {
			onlineImagePath = [[[[[self page] site] hostProperties] URLForResourceFile:onlineImagePath] absoluteString];
		}
		else {
			NSURL *baseURL = [NSURL fileURLWithPath:onlineImagePath];
			onlineImagePath = [baseURL absoluteString];
		}
		
		[result replaceOccurrencesOfString:@"#ONLINE#" 
								withString:[onlineImagePath stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]
								   options:NSLiteralSearch 
									 range:NSMakeRange(0,[result length])];
	}
	
	NSString *offlineImagePath = [self offlineImagePath];
	if (offlineImagePath)
	{
		// How we reference the path depends on publishing/previewing
		if (isPublishing) {
			offlineImagePath = [[[[[self page] site] hostProperties] URLForResourceFile:offlineImagePath] absoluteString];
		}
		else {
			NSURL *baseURL = [NSURL fileURLWithPath:offlineImagePath];
			offlineImagePath = [baseURL absoluteString];
		}
		
		[result replaceOccurrencesOfString:@"#OFFLINE#" 
								withString:offlineImagePath 
								   options:NSLiteralSearch 
									 range:NSMakeRange(0,[result length])];
	}
	
	[result replaceOccurrencesOfString:@"#HEADLINE#" 
						    withString:self.headlineText
							   options:NSLiteralSearch 
							     range:NSMakeRange(0, [result length])];
	
	return result;
}

- (NSString *)publishingHTML
{
	return [self generateHTMLPublishing:YES livePreview:NO];
}

- (NSString *)livePreviewHTML
{
	return [self generateHTMLPublishing:NO livePreview:YES];
}

- (NSString *)nonLivePreviewHTML
{
	return [self generateHTMLPublishing:NO livePreview:NO];
}


#pragma mark -
#pragma mark Other


- (NSImage *)imageWithBaseImage:(NSImage *)aBaseImage headline:(NSString *)aHeadline status:(NSString *)aStatus
{
	NSFont* font1 = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
	NSFont* font2 = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
	NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
	[aShadow setShadowOffset:NSMakeSize(0.5, -2.0)];
	[aShadow setShadowBlurRadius:2.0];
	[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
	
	NSMutableDictionary *attributes1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										font1, NSFontAttributeName, 
										aShadow, NSShadowAttributeName, 
										[NSColor colorWithCalibratedWhite:1.0 alpha:1.0], NSForegroundColorAttributeName,
										nil];
	
	NSMutableDictionary *attributes2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										font2, NSFontAttributeName, 
										aShadow, NSShadowAttributeName, 
										[NSColor colorWithCalibratedWhite:1.0 alpha:1.0], NSForegroundColorAttributeName,
										nil];
	
	NSSize textSize1 = [aHeadline sizeWithAttributes:attributes1];
	if (textSize1.width > 100)
	{
		attributes1 = attributes2;	// use the smaller size if it's going to be too large to fit well, but otherwise overflow...
	}
	
	NSImage *result = [[[NSImage alloc] initWithSize:[aBaseImage size]] autorelease];
	[result lockFocus];
	[aBaseImage drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0,0,[aBaseImage size].width, [aBaseImage size].height) operation:NSCompositeCopy fraction:1.0];
	
	[aHeadline drawAtPoint:NSMakePoint(19,40) withAttributes:attributes1];
	[aStatus drawAtPoint:NSMakePoint(32,12) withAttributes:attributes2];
	
	[result unlockFocus];
	return result;
}

- (BOOL) wantBorder
{
	BOOL result = [[[myConfigs objectAtIndex:self.selectedIMService]
					objectForKey:IMWantBorderKey] boolValue];
	return result;
}

- (NSString *)onlineImagePath
{
	IMStatusService *service = [self selectedService];
	NSString *result = [service onlineImagePath];
	
	// We have to make a special exception for the ichat service
	if ([[service serviceIdentifier] isEqualToString:@"aim"])
	{
		NSImage *compositedImage = [self imageWithBaseImage:[[self class] baseOnlineIChatImage]
												   headline:self.headlineText
													 status:self.onlineText];
		
		NSData *pngRepresentation = [[compositedImage bitmap] representationUsingType:NSPNGFileType
                                                                           properties:[NSDictionary dictionary]];
		result = [NSTemporaryDirectory() stringByAppendingPathComponent:@"online.png"];
		[pngRepresentation writeToFile:result atomically:NO];
	}
	
	return result;
}

- (NSString *)offlineImagePath
{
	IMStatusService *service = [self selectedService];
	NSString *result = [service offlineImagePath];
	
	// We have to make a special exception for the ichat service
	if ([[service serviceIdentifier] isEqualToString:@"aim"])
	{
		NSImage *compositedImage = [self imageWithBaseImage:[[self class] baseOfflineIChatImage]
												   headline:self.headlineText
													 status:self.offlineText];
		
		NSData *pngRepresentation = [[compositedImage bitmap] representationUsingType:NSPNGFileType
                                                                           properties:[NSDictionary dictionary]];
		
        result = [NSTemporaryDirectory() stringByAppendingPathComponent:@"offline.png"];
		[pngRepresentation writeToFile:result atomically:NO];
	}
	
	return result;
}

//- (NSString *)resourceDirectory
//{
//	if ([[self document] publishingMode] == kGeneratingPreview)
//	{
//		return [[NSURL fileURLWithPath:[ resourcePath]] absoluteString];
//	}
//	else
//	{
//		return [[self document] absolutePathToResourcePath];
//	}
//}

- (NSString *)serviceHTML
{
	int selectedService = self.selectedIMService;
	NSMutableString *html = [NSMutableString stringWithString:[[myConfigs objectAtIndex:selectedService] objectForKey:IMHTMLKey]];
	[html replaceOccurrencesOfString:@"#USER#" 
						  withString:self.username 
							 options:NSLiteralSearch 
							   range:NSMakeRange(0,[html length])];
	if ([self onlineImagePath])
	{
		[html replaceOccurrencesOfString:@"#ONLINE#" 
							  withString:[[[[[self page] site] hostProperties] URLForResourceFile:[self onlineImagePath]] absoluteString] 
								 options:NSLiteralSearch 
								   range:NSMakeRange(0,[html length])];
	}
	
	if ([self offlineImagePath])
	{
		[html replaceOccurrencesOfString:@"#OFFLINE#" 
							  withString:[[[[[self page] site] hostProperties] URLForResourceFile:[self offlineImagePath]] absoluteString]
								 options:NSLiteralSearch 
								   range:NSMakeRange(0,[html length])];
	}
	
	// put in the headline for the alt text
	[html replaceOccurrencesOfString:@"#HEADLINE#" 
						  withString:self.headlineText
							 options:NSLiteralSearch 
							   range:NSMakeRange(0,[html length])];
	
	return html;
}


// called via recursiveComponentPerformSelector

- (void)addResourcesToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSString *on = [self onlineImagePath];
	NSString *off = [self offlineImagePath];
	
	if (on && off)
	{
		// only add if we have both as only on is a placeholder
		[aSet addObject:on];
		[aSet addObject:off];
	}
}

/* took out:
 <key>KTPluginResourcesNeeded</key>
 <array>
 <string>online.png</string>
 <string>offline.png</string>
 </array>
 */




@end
