//
//  KTMediaURLProtocol.m
//  Marvel
//
//  Created by Terrence Talbot on 6/30/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTMediaURLProtocol.h"

#import "KTDocument.h"
#import "KTDocWindowController.h"
//#import "KTOldMediaManager.h"
#import "KTThreadedURLLoader.h"


@implementation KTMediaURLProtocol

+ (void)Xload
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	(void) [NSURLProtocol registerClass:[KTMediaURLProtocol class]];
	[pool release];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	NSURL *theURL = [request URL];
	NSString *scheme = [theURL scheme];
    return [scheme isEqualToString:@"media"];
}

/*! returns media:/ URL for media object with uniqueID aMediaID and (optionally) anImageName */
+ (NSURL *)URLForDocument:(KTDocument *)aDocument 
				  mediaID:(NSString *)aMediaID
				imageName:(NSString *)anImageName
{
	// media:/<documentID>/<cacheconfuser>/<mediaID>/<imageName>
	NSString *urlString = [NSString stringWithFormat:@"media:/%@/%u/%@",
		[aDocument documentID], 
		[KTURLProtocol cacheConfusingNumber],
		aMediaID];
	
	if ( nil != anImageName )
	{
		urlString = [urlString stringByAppendingPathComponent:anImageName];
	}
	
	//LOG((@"%@ returning URL %@", NSStringFromSelector(_cmd), urlString));
	if ( (nil == aMediaID) || [aMediaID isEqualToString:@""] )
	{
		NSLog(@"error: media protocol returning bad URL %@", urlString);
	}
	
	return [NSURL URLWithString:[urlString URLQueryEncodedString:YES]];
}

- (void)startLoading
{
	// get our resourceSpecifier
	NSURL *requestURL = [self substituteURLForRequestURL:[[self request] URL]];
	NSString *resourceSpecifier = [requestURL resourceSpecifier];
	
	if ( (nil == requestURL) || (nil == resourceSpecifier) )
	{
		/// T saw a case where a thread was attempting to load a nil resource
		/// while a document was closing -- rather than throw, just return
		NSLog(@"warning: KTMediaURLProtocol attempted to load nil resource");
		return;
	}
	
	// scan past the documentID and the cacheConfusingNumber
	NSScanner *scanner = [NSScanner scannerWithString:resourceSpecifier];	
	(void) [scanner scanString:@"/" intoString:nil];
	(void) [scanner scanUpToString:@"/" intoString:nil];
	(void) [scanner scanString:@"/" intoString:nil];
	(void) [scanner scanUpToString:@"/" intoString:nil];
	(void) [scanner scanString:@"/" intoString:nil];
	
	// reset the resourceSpecifier to be the remainder of the string after the junk
	resourceSpecifier = [resourceSpecifier substringFromIndex:[scanner scanLocation]]; 
		
	// get our mediaID and our imageName
	NSArray *components = [resourceSpecifier pathComponents];
	NSString *mediaID = [components objectAtIndex:0];
	NSString *imageName = nil;

	if ( [components count] == 1 )
	{
		// no imageName, nothing to scale, just load normally
		[self startLoadingUsingThreadedLoading:NO];
		return;
	}
	else
	{
		imageName = [components objectAtIndex:1];
	}
	
	OBASSERTSTRING((nil != mediaID), @"mediaID should not be nil");
	OBASSERTSTRING((nil != imageName), @"imageName should not be nil");
	
	BOOL shouldUseThreadedLoading = NO;
	@synchronized ( [[[self document] windowController] addingPagesViaDragPseudoLock] )
	{
		// get our media object
		KTManagedObjectContext *context = [[self document] createPeerContext];
		[context lockPSCAndSelf];
		KTMedia *media = [context mediaWithUniqueID:mediaID];
		
		// do we have a cache file on disk for imageName?
		// if yes, process on this thread, if no, process on background thread
		shouldUseThreadedLoading = ![media hasValidCacheForImageName:imageName];
		
		[context unlockPSCAndSelf];
		[[self document] releasePeerContext:context];
	}
	
	if ( shouldUseThreadedLoading )
	{
		[self startLoadingUsingThreadedLoading:YES];
	}
	else
	{
		[self startLoadingUsingThreadedLoading:NO];
	}
}

/*! changes media:/ URL into applewebdata:// URL */

/*
 
OLDER WEBKIT:
 
Changes URL like this:   media:/11D16F2645B64AB190E6/71C3B191-A2A9-4589-8BAE-8A1F8CD1DE02/_Media/placeholder_large.jpeg
into this:				 media:/11D16F2645B64AB190E6/8/106/largeImage

NEWER WEBKIT: (Jan 2007):
 */

- (NSURL *)substituteURLForRequestURL:(NSURL *)requestURL
{
	NSMutableString *substitute = [NSMutableString stringWithString:[requestURL absoluteString]];
	[substitute deleteCharactersInRange:NSMakeRange(0,7)];
	unsigned idx = [substitute rangeOfString:@"/"].location;
	[substitute deleteCharactersInRange:NSMakeRange(0,idx+1)];
	[substitute insertString:@"applewebdata://" atIndex:0];
	
	NSURL *URL = [NSURL URLWithUnescapedString:substitute];

	// I really don't need anthing more than just the relative path, which is like this:  /_Media/placeholder_large.jpeg
	
	NSURL *result = nil;
	@synchronized ( [[[self document] windowController] addingPagesViaDragPseudoLock] )
	{
		KTManagedObjectContext *context = [[self document] createPeerContext];
		[context lockPSCAndSelf];
		result = [[[self document] oldMediaManager] URLForMediaPath:[URL relativePath] managedObjectContext:context];
		[context unlockPSCAndSelf];
		[[self document] releasePeerContext:context];
	}
	
	//LOG((@"substituteURLForRequestURL returning %@", result));
	
	return result;
}

- (NSData *)dataWithResourceSpecifier:(NSString *)aSpecifier 
							 document:(KTDocument *)aDocument
							 mimeType:(NSString **)aMimeType 
								error:(NSError **)anError
{
	//LOG((@"asking for KTMediaURLProtocol dataWithResourceSpecifier: %@", aSpecifier));	
	NSData *data = nil;
	
	NSArray *components = [aSpecifier pathComponents];
	OBASSERTSTRING((([components count] == 1) || ([components count] == 2)), @"bad component count");
	NSString *mediaID = [components objectAtIndex:0];
	
	NSString *imageName = nil;
	if ( [components count] == 2 )
	{
		imageName = [components objectAtIndex:1];
	}
			
	if ( (nil != mediaID) && ![mediaID isEqualToString:@""] )
	{	
		@synchronized ( [[[self document] windowController] addingPagesViaDragPseudoLock] )
		{
			KTManagedObjectContext *context = nil;
			@try
			{
				// find our corresponding media object
				context = [[self document] createPeerContext];
				KTMedia *media = [context mediaWithUniqueID:mediaID];
				
				// get and return its data
				if ( nil != media )
				{
					if ( nil == imageName )
					{
						//LOG((@"getting media with no name for uniqueID: %@", mediaID));
						data = [[media data] retain];
						*aMimeType = [media MIMEType];
					}
					else
					{
						//LOG((@"getting media with name: %@ for uniqueID: %@", imageName, mediaID));
						data = [[media dataForImageName:imageName] retain];
						*aMimeType = [media MIMETypeForImageName:imageName];
					}
				}
				else
				{
					*anError = [self errorWithString:[NSString stringWithFormat:
						NSLocalizedString(@"datastore contains no Media with uniqueID %@",
										  "datastore contains no Media with uniqueID %@"), mediaID]];
				}
			}
			@catch (NSException *e)
			{
				NSLog(@"error: caught exception asking for resource %@", aSpecifier);
				NSLog(@"exception: %@", e);
			}
			@finally 
			{
				// always release our context
				if ( nil != context )
				{
					[[self document] releasePeerContext:context];
				}
			}
		}
	}
	else
	{
		*anError = [self errorWithString:NSLocalizedString(@"mediaID cannot be nil", "mediaID cannot be nil")];
	}

	return [data autorelease];
}

@end
