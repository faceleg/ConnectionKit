//
//  KTDocWebViewController+Private.h
//  Marvel
//
//  Created by Mike on 23/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocWebViewController.h"


@interface KTDocWebViewController (Private)
- (BOOL)hideWebView;

- (void)loadPageIntoSourceCodeTextView:(KTPage *)page;
@end
