//
//  NSURL+Amazon.m
//  Amazon List
//
//  Created by Mike on 05/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "NSURL+Amazon.h"

@interface NSString ( KareliaHack)
// this is actually implemented in KSURLUtilities.m
- (NSString *)ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:(BOOL)encodeSpacesAsPlusCharacters;
@end

@implementation NSURL ( Amazon )

#pragma mark -
#pragma mark REST

+ (NSURL *)URLWithBaseURL:(NSURL *)baseURL parameters:(NSDictionary *)parameters
{
	return [[[self alloc] initWithBaseURL: baseURL parameters: parameters] autorelease];
}

- (id)initWithBaseURL:(NSURL *)baseURL parameters:(NSDictionary *)parameters
{
	// Build the list of parameters as a string
	NSMutableString *parametersString = [NSMutableString string];

	if (nil != parameters)
	{
		NSEnumerator *enumerator = [parameters keyEnumerator];
		NSString *key;
		BOOL thisIsTheFirstParameter = YES;

		while (key = [enumerator nextObject])
		{
			id rawParameter = [parameters objectForKey: key];
			NSString *parameter = nil;
			
			// Treat arrays specially, otherwise just get the object description
			if ([rawParameter isKindOfClass:[NSArray class]])
			{
				parameter = [rawParameter componentsJoinedByString:@","];
			}
			else {
				parameter = [rawParameter description];
			}

			// Append the parameter and its key to the full query string
			if (thisIsTheFirstParameter)
			{
				[parametersString appendFormat: @"?%@=%@",
				 [key ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES],
				 [parameter ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]];
				thisIsTheFirstParameter = NO;
			}
			else {
				[parametersString appendFormat: @"&%@=%@",
				 [key ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES],
				 [parameter ks_stringByAddingPercentEscapesWithSpacesAsPlusCharacters:YES]];
			}
		}
	}
	
	// Create the URL from the parameters string
	[self initWithString: parametersString relativeToURL: baseURL];

	// Tidy up
	return self;
}

@end
