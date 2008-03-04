//
//  KTSummaryWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 04/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTWebViewTextBlock.h"


@interface KTSummaryWebViewTextBlock : KTWebViewTextBlock
{
}

- (NSString *)summarisedContentHTML;
- (NSString *)unsummarisedContentHTML;

@end
