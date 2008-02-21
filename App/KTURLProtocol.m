//
//  KTURLProtocol.m
//  Marvel
//
//  Created by Dan Wood on 3/2/05.
//  Copyright 2005 Biophony, LLC. All rights reserved.
//

#import "KTURLProtocol.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTThreadedURLLoader.h"
#import "NSString+Karelia.h"
#import "NSObject+Karelia.h"

@interface KTURLProtocol (Private)
- (void)KT_startLoading;
@end

static unsigned long sCacheConfusingNumber = 0;

@implementation KTURLProtocol

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [[[a URL] resourceSpecifier] isEqualToString:[[b URL] resourceSpecifier]];
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client
{
	if (self = [super initWithRequest:request cachedResponse:cachedResponse client:client])
	{
		myThread = [NSThread currentThread];
	}
	return self;
}

/*! allow subclasses to sub a url */
- (NSURL *)substituteURLForRequestURL:(NSURL *)requestURL
{
	return [[requestURL retain] autorelease];
}

- (KTDocument *)document
{
	NSURL *requestURL = [[self request] URL];
	NSString *resourceSpecifier = [requestURL resourceSpecifier];
	
	// If there is no extension, it seems to crash to call UTIForFilenameExtension
	NSString *mimeType = nil;
	
	NSString *ext = [resourceSpecifier pathExtension];
	if (nil != ext && ![ext isEqualToString:@""])
	{
		NSString *uti = [NSString UTIForFilenameExtension:ext];
		mimeType = [NSString MIMETypeForUTI:uti];
	}
	
	NSScanner *scanner = [NSScanner scannerWithString:resourceSpecifier];	
	NSString *documentID = nil;
	
	// Get document ID
	(void) [scanner scanString:@"/" intoString:nil];
	(void) [scanner scanUpToString:@"/" intoString:&documentID];

	return [[NSApp delegate] documentWithID:documentID];
}

/*! scans up through <urlprotocol>:/documentID/junk/
	and then calls dataWithProctolScanner:document:resourceSpecifier:mimeType:error:
*/
- (void)startLoading
{
	[self startLoadingUsingThreadedLoading:NO]; // do not use threaded loader by default
}

- (void)startLoadingUsingThreadedLoading:(BOOL)aFlag
{
	if ( aFlag )
	{
		TJT((@"threading load of %@", [self substituteURLForRequestURL:[[self request] URL]]));
		[[[KTThreadedURLLoader sharedLoader] prepareWithInvocationTarget:self] KT_startLoading];
	}
	else
	{
		[self KT_startLoading];
	}
}

- (void)KT_startLoading
{	
	NSURL *requestURL = [self substituteURLForRequestURL:[[self request] URL]];
	LOG((@"startLoading:%@", requestURL));
	NSString *resourceSpecifier = [requestURL resourceSpecifier];
	
	// If there is no extension, it seems to crash to call UTIForFilenameExtension
	NSString *mimeType = nil;
	
	NSString *ext = [resourceSpecifier pathExtension];
	if (nil != ext && ![ext isEqualToString:@""])
	{
		NSString *uti = [NSString UTIForFilenameExtension:ext];
		mimeType = [NSString MIMETypeForUTI:uti];
	}
	
	NSScanner *scanner = [NSScanner scannerWithString:resourceSpecifier];	
	NSString *documentID = nil;
	NSData *data = nil;
	NSError *error = nil;
	
	// Get document ID
	(void) [scanner scanString:@"/" intoString:nil];
	(void) [scanner scanUpToString:@"/" intoString:&documentID];
	(void) [scanner scanString:@"/" intoString:nil];
	KTDocument *document = [[NSApp delegate] documentWithID:documentID];
	
	//[[document mediaLoadingLock] lock];

	
	// Scan past unique ID that is there only to confuse the cache
	(void) [scanner scanUpToString:@"/" intoString:nil];
	(void) [scanner scanString:@"/" intoString:nil];
	
	// reset the resourceSpecifier to be the remainder of the string after the junk
	resourceSpecifier = [resourceSpecifier substringFromIndex:[scanner scanLocation]]; 
	if (nil != document)
	{
		data = [[self dataWithResourceSpecifier:resourceSpecifier
									  document:document
									  mimeType:&mimeType 
										 error:&error] retain];
	}
	else
	{
		error = [self errorWithString:[NSString stringWithFormat:NSLocalizedString(@"Unable to find document #%@",
																				   "error: KTURLProtocol"), documentID]];
	}
	
	if (nil != data)
	{
		NSURLResponse *response = [[[NSURLResponse alloc] initWithURL:requestURL
                                                             MIMEType:mimeType
                                                expectedContentLength:-1
                                                     textEncodingName:nil] autorelease];
		
		// Note: I tried to not autorelease the above, and instead release it below the
		// callback method below, trying track down an apparent leak.  But instead, I
		// found that the response is needed later.  So keep this autoreleased.
		
		[[self client] URLProtocol:self
				didReceiveResponse:response
				cacheStoragePolicy:NSURLCacheStorageNotAllowed];
		
		[[self client] URLProtocol:self
					   didLoadData:data];
		
		[[self client] URLProtocolDidFinishLoading:self];
	}
	else
	{
		[[self client] URLProtocol:self didFailWithError:error];
		
		if ([[error domain] isEqualToString:NSCocoaErrorDomain]
			&& NSFileReadNoSuchFileError == [error code])
		{
			NSLog(@"FILE NOT FOUND: %@", [[[error userInfo] objectForKey:NSFilePathErrorKey] stringByAbbreviatingWithTildeInPath]);
		}
		else
		{
			NSLog(@"URL %@ -> error %@",requestURL, error);
		}
	}
	[data autorelease];
	
	//[[document mediaLoadingLock] unlock];
}

- (void)stopLoading
{
}

+ (unsigned long)cacheConfusingNumber
{
	++sCacheConfusingNumber;
	return sCacheConfusingNumber;
}

- (NSData*)dataWithResourceSpecifier:(NSString *)aSpecifier 
							document:(KTDocument *)aDocument 
							mimeType:(NSString **)aMimeType 
							   error:(NSError **)anError
{
	[self subclassResponsibility:_cmd];
	return nil;
}

- (NSError *)errorWithString:(NSString *)aString
{
	return [NSError errorWithDomain:kKTURLPrococolErrorDomain
							   code:-16336 
						   userInfo:[NSDictionary dictionaryWithObject:aString 
																forKey:NSLocalizedDescriptionKey]];
}

@end
