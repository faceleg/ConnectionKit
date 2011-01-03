//
//  KTURLCredentialStorage.m
//  Marvel
//
//  Created by Mike on 23/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTURLCredentialStorage.h"

#import "KSUtilities.h"

#import <Connection/Connection.h>


@implementation KTURLCredentialStorage

+ (KTURLCredentialStorage *)sharedCredentialStorage
{
	static KTURLCredentialStorage *result; 
	if (!result)
	{
		result = [[KTURLCredentialStorage alloc] init];
	}
	return result;
}

- (NSURLCredential *)credentialForUser:(NSString *)user protectionSpace:(NSURLProtectionSpace *)space
{
	// Query the standard API first
	NSURLCredential *result = [[[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:space] objectForKey:user];
	
	if (!result)
	{
		OBASSERT(user);
		OBASSERT(![user isEqualToString:@""]);
		OBASSERT(space);
		
		
		EMInternetKeychainItem *keychainItem = [[EMKeychainProxy sharedProxy] internetKeychainItemForServer:[space host]
																							   withUsername:user 
																									   path:[space realm]
																									   port:[space port] 
																								   protocol:[KSUtilities SecProtocolTypeForProtocol:[space protocol]]];
		
		if (keychainItem)
		{
			result = [NSURLCredential credentialWithUser:[keychainItem username]
												password:[keychainItem password]
											 persistence:NSURLCredentialPersistencePermanent];
		}
	}
	
	return result;
}

- (void)setCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space
{
	if ([credential persistence] != NSURLCredentialPersistencePermanent ||
		[[space protocol] isEqualToString:@"http"] ||
		[[space protocol] isEqualToString:@"https"] ||
		[[space protocol] isEqualToString:@"ftp"] || 
		[[space protocol] isEqualToString:@"ftps"])
	{
		[[NSURLCredentialStorage sharedCredentialStorage] setCredential:credential forProtectionSpace:space];
	}
	else
	{
		[[EMKeychainProxy sharedProxy] addInternetKeychainItemForServer:[space host] 
														   withUsername:[credential user] 
															   password:[credential password]
																   path:[space realm]
																   port:[space port] 
															   protocol:[KSUtilities SecProtocolTypeForProtocol:[space protocol]]];
	}
}

@end
