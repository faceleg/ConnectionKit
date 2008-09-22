//
//  KTDocWebViewController+Private.h
//  Marvel
//
//  Created by Mike on 23/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocWebViewController.h"

@class KTPage;

@interface KTDocWebViewController (Private)
- (BOOL)hideWebView;

- (void)loadPageIntoSourceCodeTextView:(KTPage *)page;

// Editing
- (void)setCurrentTextEditingBlock:(KTHTMLTextBlock *)textBlock;
@end


@interface KTDocWebViewController (LoadingPrivate)
- (void)init_webViewLoading;
- (void)dealloc_webViewLoading;
@end
