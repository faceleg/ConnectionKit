//
//  KTMediaDataProxy.m
//  Marvel
//
//  Created by Greg Hulands on 30/03/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "KTMediaDataProxy.h"

#import <Sandvox.h>


@implementation KTMediaDataProxy

#pragma mark -
#pragma mark Init/Dealloc

+ (id)proxyForObject:(id)aMediaRelatedObject
{
	KTMediaDataProxy *result = nil;
	
	if ( [aMediaRelatedObject isKindOfClass:[KTMedia class]] )
	{
		KTMedia *media = aMediaRelatedObject;
		result = [[KTMediaDataProxy alloc] initWithDocument:[media document] media:media];
	}
	else if ( [aMediaRelatedObject isKindOfClass:[KTMediaRef class]] )
	{
		KTMedia *media = [(KTMediaRef *)aMediaRelatedObject media];
		result = [[KTMediaDataProxy alloc] initWithDocument:[media document] media:media];
	}
	else if ( [aMediaRelatedObject isKindOfClass:[KTCachedImage class]] )
	{
		KTMedia *media = [(KTCachedImage *)aMediaRelatedObject media];
		result = [[KTMediaDataProxy alloc] initWithDocument:[media document] 
													  media:media 
													   name:[aMediaRelatedObject name]];
	}
	else
	{
		LOG((@"KTMediaDataProxy +proxyForObject: unknown class! %@", [aMediaRelatedObject class]));
	}

	return [result autorelease];	
}

- (id)initWithDocument:(KTDocument *)doc media:(KTMedia *)media
{
	[super init];
	if ( nil != self )
	{
		//LOG((@"initing %@ %p", [self className], self));
		myDocumentWeakRef = doc;
		myUniqueID = [[media uniqueID] copy];
	}
	return self;
}

- (id)initWithDocument:(KTDocument *)doc media:(KTMedia *)media name:(NSString *)aName;
{
	[super init];
	if ( nil != self )
	{
		//LOG((@"initing %@ %p", [self className], self));
		myDocumentWeakRef = doc;
		myUniqueID = [[media uniqueID] copy];
		myName = [aName copy];
	}
	return self;
}

- (void)dealloc
{
	//LOG((@"deallocing %@ %p", [self className], self));
	[myUniqueID release]; myUniqueID = nil;
	[myRealData release]; myRealData = nil;
	[myName release]; myName = nil;
	[super dealloc];
}

- (unsigned)hash
{
	// turn myUniqueID+myName into an integer
	NSAssert((nil != myUniqueID), @"myUniqueID should not be nil");
	unsigned result = [myUniqueID intValue];
	
	if ( nil != myName )
	{
		result = result + [myName checksum:2147483647]; // large 32-bit prime
	}
	
	return result;
}

- (NSString *)name
{
	return myName;
}

- (NSString *)mediaID
{
	return myUniqueID;
}

#pragma mark -
#pragma mark Support

- (NSData *)realData	// Once this is invoked, the data are loaded into memory
{
	if ( nil == myRealData )
	{
		NSAssert([myDocumentWeakRef isKindOfClass:[KTDocument class]], @"myDocumentWeakRef should (still) exist and be a KTDocument");
		
		KTManagedObjectContext *context = [myDocumentWeakRef createPeerContext];
		[context lockPSCAndSelf];
		
		KTMedia *media = [context mediaWithUniqueID:myUniqueID];
		
		LOG((@"fetching realData for %@ %p %@", [self className], self, [media managedObjectDescription]));
		
		if ( nil != myName )
		{
			myRealData = [[media dataForImageName:myName] retain];
		}
		else
		{
			myRealData = [[media data] retain];
		}

		[context unlockPSCAndSelf];
		[myDocumentWeakRef releasePeerContext:context];
		
		myLength = [myRealData length];
	}
	
	return myRealData;
}

#pragma mark -
#pragma mark NSData overrides

- (const void *)bytes
{
	return [[self realData] bytes];
}

- (void)getBytes:(void *)buffer
{
	return [[self realData] getBytes:buffer];
}

- (void)getBytes:(void *)buffer length:(unsigned)length
{
	return [[self realData] getBytes:buffer length:length];
}

- (void)getBytes:(void *)buffer range:(NSRange)range
{
	return [[self realData] getBytes:buffer range:range];
}

- (unsigned)length
{
	// hopefully we've cached this in an ivar already
	if ( 0 == myLength )
	{
		KTManagedObjectContext *context = [myDocumentWeakRef createPeerContext];
		[context lockPSCAndSelf];
		KTMedia *media = [context mediaWithUniqueID:myUniqueID];
		if ( nil != media )
		{
			if ( nil != myName )
			{
				// we're looking for a scaled image, lets see if we can return that
				KTCachedImage *cachedImage = [media imageForImageName:myName];
				if ( nil != cachedImage )
				{
					unsigned int size = [[cachedImage cacheSize] unsignedIntValue];
					if ( size > 0 )
					{
						myLength = size;
					}
				}
			}
			else
			{
				// just return the size of the underlying media data
				unsigned int size = [media integerForKey:@"mediaDataLength"];
				if ( size > 0 )
				{
					myLength = size;
				}				
			}
		}
		[context unlockPSCAndSelf];
		[myDocumentWeakRef releasePeerContext:context];
		
		if ( 0 == myLength )
		{
			// if we still don't have it, use the underlying data
			myLength = [[self realData] length];
		}
	}
	
	return myLength;
}

- (NSData *)subdataWithRange:(NSRange)range
{
	return [[self realData] subdataWithRange:range];
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag
{
	return [[self realData] writeToFile:path atomically:flag];
}

- (BOOL)writeToFile:(NSString *)path options:(unsigned int)mask error:(NSError **)errorPtr
{
	return [[self realData] writeToFile:path options:mask error:errorPtr];
}

- (BOOL)writeToURL:(NSURL *)aURL atomically:(BOOL)atomically
{
	return [[self realData] writeToURL:aURL atomically:atomically];
}

- (BOOL)writeToURL:(NSURL *)aURL options:(unsigned int)mask error:(NSError **)errorPtr
{
	return [[self realData] writeToURL:aURL options:mask error:errorPtr];
}

#pragma mark -
#pragma mark disallowed constructors

+ (id)data { return nil; }
+ (id)dataWithBytes:(const void *)bytes length:(unsigned)length { return nil; }
+ (id)dataWithBytesNoCopy:(void *)bytes length:(unsigned)length { return nil; }
+ (id)dataWithBytesNoCopy:(void *)bytes length:(unsigned)length freeWhenDone:(BOOL)freeWhenDone { return nil; }
+ (id)dataWithContentsOfFile:(NSString *)path { return nil; }
+ (id)dataWithContentsOfFile:(NSString *)path options:(unsigned int)mask error:(NSError **)errorPtr { return nil; }
+ (id)dataWithContentsOfMappedFile:(NSString *)path { return nil; }
+ (id)dataWithContentsOfURL:(NSURL *)aURL { return nil; }
+ (id)dataWithContentsOfURL:(NSURL *)aURL options:(unsigned int)mask error:(NSError **)errorPtr { return nil; }
+ (id)dataWithData:(NSData *)aData { return nil; }

- (id)initWithBytes:(const void *)bytes length:(unsigned)length
{
	[self release];
	return nil;
}

- (id)initWithBytesNoCopy:(void *)bytes length:(unsigned)length
{
	[self release];
	return nil;
}

- (id)initWithBytesNoCopy:(void *)bytes length:(unsigned)length freeWhenDone:(BOOL)flag
{
	[self release];
	return nil;
}

- (id)initWithContentsOfFile:(NSString *)path
{
	[self release];
	return nil;
}

- (id)initWithContentsOfFile:(NSString *)path options:(unsigned int)mask error:(NSError **)errorPtr
{
	[self release];
	return nil;
}

- (id)initWithContentsOfMappedFile:(NSString *)path
{
	[self release];
	return nil;
}

- (id)initWithContentsOfURL:(NSURL *)aURL
{
	[self release];
	return nil;
}

- (id)initWithContentsOfURL:(NSURL *)aURL options:(unsigned int)mask error:(NSError **)errorPtr
{
	[self release];
	return nil;
}

- (id)initWithData:(NSData *)data
{
	[self release];
	return nil;
}

- (BOOL)isEqualToData:(NSData *)otherData
{
	BOOL result = NO;
	
	if ( [otherData isKindOfClass:[KTMediaDataProxy class]] )
	{
		// compare KTMediaDataProxy objects
		if ( [[self mediaID] isEqualToString:[(KTMediaDataProxy *)otherData mediaID]] )
		{
			result = YES;
			// unless they differ by uniqueName
			if ( (nil != [self name]) && (nil == [(KTMediaDataProxy *)otherData name]) )
			{
				result = NO;
			}
			else if ( (nil == [self name]) && (nil != [(KTMediaDataProxy *)otherData name]) )
			{
				result = NO;
			}
			else if ( (nil != [self name]) && (nil != [(KTMediaDataProxy *)otherData name]) )
			{
				result = [[self name] isEqualToString:[(KTMediaDataProxy *)otherData name]];
			}

		}
	}
	else
	{
		// compare NSData objects
		result = [[self realData] isEqualToData:otherData];
	}
	
	return result;
}

@end
