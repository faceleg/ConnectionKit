//
//  KTStalenessManager.h
//  Marvel
//
//  Created by Mike on 28/11/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDocument, KTAbstractPage;


@interface KTStalenessManager : NSObject
{
	KTDocument			*myDocument;
	NSMutableDictionary	*myNonStalePages;
	NSMutableSet		*myObservedPages;
}

- (id)initWithDocument:(KTDocument *)document;

- (KTDocument *)document;

// Observation
- (void)beginObservingPage:(KTAbstractPage *)page;
- (void)beginObservingAllPages;

- (void)stopObservingPage:(KTAbstractPage *)page;
- (void)stopObservingAllPages;

@end
