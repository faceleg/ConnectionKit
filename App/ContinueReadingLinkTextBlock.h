//
//  ContinueReadingLinkTextBlock.h
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTWebViewTextBlock.h"


@class KTPage;


@interface ContinueReadingLinkTextBlock : KTWebViewTextBlock
{
	KTPage *myTargetPage;
}

- (KTPage *)targetPage;
- (void)setTargetPage:(KTPage *)page;

- (NSString *)HTMLRepresentation;

@end
