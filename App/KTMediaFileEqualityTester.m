//
//  KTMediaFileEqualityTester.m
//  Marvel
//
//  Created by Mike on 18/05/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTMediaFileEqualityTester.h"
#import "KTInDocumentMediaFile.h"

#import "NSObject+Karelia.h"


@interface KTMediaFileEqualityTester ()
- (NSFileHandle *)fileHandleForMediaFile:(KTInDocumentMediaFile *)mediaFile;
@end


@implementation KTMediaFileEqualityTester

- (id)initWithPossibleMatches:(NSSet *)mediaFiles forPath:(NSString *)path
{
	[super init];
	
	myComparisonPath = [path copy];
	myPossibleMatches = [mediaFiles mutableCopy];
	myFileHandles = [[NSMutableDictionary alloc] initWithCapacity:[mediaFiles count]];
	
	return self;
}

- (void)dealloc
{
	[myComparisonPath release];
	
	[myFileHandles release];
	[myPossibleMatches release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

/*	The KTInDocumentMediaFiles we are tracking
 */
- (NSSet *)possibleMatches
{
	NSSet *result = [[myPossibleMatches copy] autorelease];
	return result;
}

/*	Gets the file handle corresponding to a particular media file
 */
- (NSFileHandle *)fileHandleForMediaFile:(KTInDocumentMediaFile *)mediaFile
{
	NSFileHandle *result = [myFileHandles objectForKey:mediaFile];
	
	if (!result)
	{
		result = [NSFileHandle fileHandleForReadingAtPath:[mediaFile currentPath]];
		CFDictionarySetValue((CFMutableDictionaryRef)myFileHandles, mediaFile, result);
	}
	
	return result;
}

/*	Once it's established that a MediaFile is not a match, this method dumps it.
 */
- (void)eliminateMediaFile:(KTInDocumentMediaFile *)mediaFile
{
	[myFileHandles removeObjectForKey:mediaFile];
	[myPossibleMatches removeObject:mediaFile];
}

#pragma mark -
#pragma mark Work

/*	Run through the possible matches using their file handle to figure the result.
 */
- (KTInDocumentMediaFile *)firstMatch
{
	NSFileHandle *comparisonFileHandle = [NSFileHandle fileHandleForReadingAtPath:myComparisonPath];
	
	
	// Loop though, comparing small chunks of the files, one at a time.
	BOOL continueTest = YES;
	while (continueTest)	
	{
		// This is a tight loop with lots of data being chucked about so will need an autorelease pool to keep it down.
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		
		// First grab a chunk of the new file. It could be nil if we're at the end
		NSData *comparisonChunk = [comparisonFileHandle readDataOfLength:1048576];
		
		
		// Compare this chunk to our possible matches
		NSSet *possibleMatches = [self possibleMatches];
		NSEnumerator *matchEnumerator = [possibleMatches objectEnumerator];
		KTInDocumentMediaFile *aPossibleMatch;
		
		while (aPossibleMatch = [matchEnumerator nextObject])
		{
			NSData *aChunk = [[self fileHandleForMediaFile:aPossibleMatch] readDataOfLength:1048576];
			if (![NSData object:comparisonChunk isEqual:aChunk])
			{
				[self eliminateMediaFile:aPossibleMatch];
			}
		}
		
		
		// Stop the test once there is no more data or matches.
		continueTest = (comparisonChunk && [comparisonChunk length] > 0 && [[self possibleMatches] count] > 0);
		
		
		// Tidy up
		[pool release];
	}
	
	
	// The result must be any of the remaining files or nil if none was found.
	KTInDocumentMediaFile *result = [[self possibleMatches] anyObject];
	return result;
}

@end

