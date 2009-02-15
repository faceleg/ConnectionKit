//
//  ContinueReadingLinkTextBlock.h
//  Marvel
//
//  Created by Mike on 05/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLTextBlock.h"


@class KTPage;


@interface ContinueReadingLinkTextBlock : KTHTMLTextBlock
{
	KTPage *myTargetPage;
}

- (KTPage *)targetPage;
- (void)setTargetPage:(KTPage *)page;

- (NSString *)innerEditingHTML;

@end
