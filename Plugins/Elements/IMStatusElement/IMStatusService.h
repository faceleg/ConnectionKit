//
//  IMStatusService.h
//  IMStatusPagelet
//
//  Created by Mike on 06/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IMStatusService : NSObject
{
	NSString *myName;
	NSString *myIdentifier;
	NSString *myResourcesPath;
	NSString *myOnlineImagePath;
	NSString *myOfflineImagePath;
	
	NSString *myPublishingHTML;
	NSString *myLivePreviewHTML;
	NSString *myNonLivePreviewHTML;
}

+ (NSArray *)services;

+ (NSArray *)servicesWithArrayOfDictionaries:(NSArray *)services resourcePath:(NSString *)resourcePath;
- (id)initWithDictionary:(NSDictionary *)dictionary resourcePath:(NSString *)resources;

- (NSString *)serviceName;
- (NSString *)serviceIdentifier;

- (NSString *)badgeHTMLWithUsername:(NSString *)username
						   headline:(NSString *)headline
						onlineLabel:(NSString *)onlineLabel
					   offlineLabel:(NSString *)offlineLabel
					   isPublishing:(BOOL)isPublishing
					    livePreview:(BOOL)isLivePreview;

- (NSString *)publishingHTMLCode;
- (NSString *)livePreviewHTMLCode;
- (NSString *)nonLivePreviewHTMLCode;

- (NSString *)onlineImagePath;
- (NSString *)offlineImagePath;

@end
