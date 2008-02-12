//
//  NSError+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 10/30/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSError+Karelia.h"

#import "KT.h"
#import "KTAbstractPlugin.h"		// for the benefit of L'izedStringInKTComponents macro

@implementation NSError ( KTExtensions )

+ (id)errorWithDomain:(NSString *)anErrorDomain code:(int)anErrorCode localizedDescription:(NSString *)aLocalizedDescription
{
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:aLocalizedDescription forKey:NSLocalizedDescriptionKey];
	return [self errorWithDomain:anErrorDomain code:anErrorCode userInfo:errorInfo];
}

+ (id)errorWithLocalizedDescription:(NSString *)aLocalizedDescription
{
	return [self errorWithDomain:kKareliaErrorDomain code:KTGenericError localizedDescription:aLocalizedDescription];
}

+ (id) errorWithHTTPStatusCode:(int)aStatusCode URL:(NSURL *)aURL
{
	NSString *statusDescription = [NSHTTPURLResponse localizedStringForStatusCode:aStatusCode];
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSString stringWithFormat:
								NSLocalizedString(@"Server returned status code %d %@",@"Description of an HTTP error"),
								aStatusCode, statusDescription],NSLocalizedDescriptionKey,
							   [aURL absoluteString], NSErrorFailingURLStringKey,
							   nil];
	return [self errorWithDomain:@"NSHTTPPropertyStatusCodeKey" code:aStatusCode userInfo:errorInfo];
	// NSHTTPPropertyStatusCodeKey is deprecated, but we'll continue to use it for ourselves
}
					



#pragma mark Error Handing

+ (void)presentErrorWithLocalizedDescription:(NSString *)aLocalizedDescription
{
    NSError *error = [self errorWithLocalizedDescription:aLocalizedDescription];
    [[NSApplication sharedApplication] presentError:error];
}

@end
