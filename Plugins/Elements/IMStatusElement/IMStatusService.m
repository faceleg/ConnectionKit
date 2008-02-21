//
//  IMStatusService.m
//  IMStatusPagelet
//
//  Created by Mike on 06/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "IMStatusService.h"

#import <SandvoxPlugin.h>


@interface IMStatusService (Private)

@end


@implementation IMStatusService

+ (NSArray *)services
{
	static NSArray *sServices;
	
	if (!sServices)
	{
		// Build the list of services
		NSMutableArray *services = [NSMutableArray arrayWithCapacity:3];
		
		NSBundle *bundle = [NSBundle bundleForClass:self];
		NSArray *pluginServices = [bundle objectForInfoDictionaryKey:@"IMServices"];
		[services addObjectsFromArray:[IMStatusService servicesWithArrayOfDictionaries:pluginServices
																		  resourcePath:[bundle resourcePath]]];
		
		sServices = [services copy];
	}
	
	return sServices;
}

#pragma mark -
#pragma mark Init & Dealloc

+ (NSArray *)servicesWithArrayOfDictionaries:(NSArray *)services resourcePath:(NSString *)resourcePath
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:1];
	
	NSEnumerator *enumerator = [services objectEnumerator];
	NSDictionary *aServiceDict;
	
	while (aServiceDict = [enumerator nextObject])
	{
		IMStatusService *service = [[IMStatusService alloc] initWithDictionary:aServiceDict
																  resourcePath:resourcePath];
		
		[result addObject:service];
		[service release];
	}
	
	return result;
}

- (id)initWithDictionary:(NSDictionary *)dictionary resourcePath:(NSString *)resources
{
	[super init];
	
	myName = [[dictionary objectForKey:@"serviceName"] copy];
	myIdentifier = [[dictionary objectForKey:@"serviceIdentifier"] copy];
	myResourcesPath = [resources copy];
	myOnlineImagePath =[[dictionary objectForKey:@"onlineImage"] copy];
	myOfflineImagePath = [[dictionary objectForKey:@"offlineImage"] copy];
	
	myPublishingHTML = [[dictionary objectForKey:@"publishingHTML"] copy];
	myLivePreviewHTML = [[dictionary objectForKey:@"livePreviewHTML"] copy];
	myNonLivePreviewHTML = [[dictionary objectForKey:@"nonLivePreviewHTML"] copy];
	
	return self;
}

- (void)dealloc
{
	[myName release];
	[myIdentifier release];
	[myPublishingHTML release];
	[myLivePreviewHTML release];
	[myNonLivePreviewHTML release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSString *)serviceName { return myName; }

- (NSString *)serviceIdentifier { return myIdentifier; }

- (NSString *)onlineImagePath
{
	NSString *result = nil;
	
	if (myOnlineImagePath)
	{
		result = [myResourcesPath stringByAppendingPathComponent:myOnlineImagePath];
	}
	
	return result;
}

- (NSString *)offlineImagePath
{
	NSString *result = nil;
	
	if (myOfflineImagePath)
	{
		result = [myResourcesPath stringByAppendingPathComponent:myOfflineImagePath];
	}
	
	return result;
}

#pragma mark -
#pragma mark HTML

- (NSString *)publishingHTMLCode { return myPublishingHTML; }

/*	The live preview HTML if specified. If not, falls back to the publishing HTML
 */
- (NSString *)livePreviewHTMLCode
{
	NSString *result = myLivePreviewHTML;
	
	if (!result || [result isEqualToString:@""])
	{
		result = [self publishingHTMLCode];
	}
	
	return result;
}

- (NSString *)nonLivePreviewHTMLCode
{
	NSString *result = myNonLivePreviewHTML;
	
	if (!result || [result isEqualToString:@""])
	{
		result = [self livePreviewHTMLCode];
	}
	
	return result;
}

- (NSString *)badgeHTMLWithUsername:(NSString *)username
						   headline:(NSString *)headline
						onlineLabel:(NSString *)onlineLabel
					   offlineLabel:(NSString *)offlineLabel
					   isPublishing:(BOOL)isPublishing
					    livePreview:(BOOL)isLivePreview
{
	// Get the appropriate code for the publishing mode
	NSString *HTMLCode = nil;
	if (isPublishing) {
		HTMLCode = [self publishingHTMLCode];
	}
	else if (isLivePreview) {
		HTMLCode = [self livePreviewHTMLCode];
	}
	else {
		HTMLCode = [self nonLivePreviewHTMLCode];
	}
	
	NSMutableString *result = [NSMutableString stringWithString:HTMLCode];
	
	// Parse the code to get the finished HTML
	[result replaceOccurrencesOfString:@"#USER#" 
						    withString:[username urlEncode]
							   options:NSLiteralSearch 
							     range:NSMakeRange(0, [result length])];
	
	if ([self onlineImagePath])
	{
		[result replaceOccurrencesOfString:@"#ONLINE#" 
							  withString:[self onlineImagePath] 
								 options:NSLiteralSearch 
								   range:NSMakeRange(0,[result length])];
	}
	
	if ([self offlineImagePath])
	{
		[result replaceOccurrencesOfString:@"#OFFLINE#" 
							  withString:[self onlineImagePath] 
								 options:NSLiteralSearch 
								   range:NSMakeRange(0,[result length])];
	}

	[result replaceOccurrencesOfString:@"#HEADLINE#" 
						    withString:headline 
							   options:NSLiteralSearch 
							     range:NSMakeRange(0, [result length])];
	
	return result;
}

@end
