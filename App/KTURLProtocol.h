//
//  KTURLProtocol.h
//  Marvel
//
//  Created by Dan Wood on 3/2/05.
//  Copyright 2005 Biophony, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTDocument;

@interface KTURLProtocol : NSURLProtocol 
{
	NSThread *myThread;
}

// subclasses must implement +load and +canInitWithRequest:

- (KTDocument *)document;
- (NSURL *)substituteURLForRequestURL:(NSURL *)requestURL;

// subclasses must override one of these to finish processing of protocol and load data
- (void)startLoading;
- (NSData*)dataWithResourceSpecifier:(NSString *)aSpecifier 
							document:(KTDocument *)aDocument 
							mimeType:(NSString **)aMimeType 
							   error:(NSError **)anError;

+ (unsigned long)cacheConfusingNumber;
- (NSError *)errorWithString:(NSString *)aString;

// if aFlag, use KTThreadedURLLoader to perform KT_startLoading
- (void)startLoadingUsingThreadedLoading:(BOOL)aFlag;

@end
