//
//  KTMediaFileEqualityTester.h
//  Marvel
//
//  Created by Mike on 18/05/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTInDocumentMediaFile;


@interface KTMediaFileEqualityTester : NSObject
{
	NSString			*myComparisonPath;
	NSMutableSet		*myPossibleMatches;
	NSMutableDictionary	*myFileHandles;
}

- (id)initWithPossibleMatches:(NSSet *)mediaFiles forPath:(NSString *)path;
- (KTInDocumentMediaFile *)firstMatch;
@end
