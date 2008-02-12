//
//  KTMediaDataProxy.h
//  Marvel
//
//  Created by Greg Hulands on 30/03/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTMedia, KTDocument;

@interface KTMediaDataProxy : NSData 
{
	KTDocument *myDocumentWeakRef;
	
	NSString	*myUniqueID; // media's uniqueID for later fetching
	NSData		*myRealData; // actual (possibly scaled) media data
	NSString	*myName;	 // name of scaled image, if used
	
	unsigned int myLength;
}

+ (id)proxyForObject:(id)aMediaRelatedObject;

- (id)initWithDocument:(KTDocument *)doc media:(KTMedia *)media;
- (id)initWithDocument:(KTDocument *)doc media:(KTMedia *)media name:(NSString *)aName;

- (NSString *)name;
- (NSString *)mediaID;

@end
