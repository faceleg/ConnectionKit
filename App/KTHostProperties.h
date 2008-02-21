//
//  KTStoredDictionary+HostProperties.h
//  Marvel
//
//  Created by Dan Wood on 5/25/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTManagedObject.h"


@interface KTHostProperties : KTManagedObject

- (BOOL)remoteSiteURLIsValid;
- (NSString *)globalBaseURLUsingHome:(BOOL)inHome;
- (NSString *)globalSiteURL;
- (NSString *)localHostNameOrAddress;
- (NSString *)localPublishingRoot;
- (NSString *)localURL;
- (NSString *)remotePublishingRoot;
- (NSString *)remoteSiteURL;
- (NSString *)uploadURL;

@end
