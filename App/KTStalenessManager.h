//
//  KTStalenessManager.h
//  Marvel
//
//  Created by Mike on 28/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDocument, KTPage;


@interface KTStalenessManager : NSObject
{
	KTDocument			*myDocument;
	NSMutableDictionary	*myNonStalePages;
	NSMutableSet		*myObservedPages;
}

- (id)initWithDocument:(KTDocument *)document;

- (KTDocument *)document;

// Observation
- (void)beginObservingPage:(KTPage *)page;
- (void)beginObservingAllPages;

- (void)stopObservingPage:(KTPage *)page;
- (void)stopObservingAllPages;

@end
