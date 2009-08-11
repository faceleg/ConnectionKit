//
//  KTDocWebViewController+Private.h
//  Marvel
//
//  Created by Mike on 23/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocWebViewController.h"
#import "KTWebViewUndoManagerProxy.h"


@class KTPage;

@interface KTDocWebViewController ()

- (void)setWebViewLoading:(BOOL)isLoading;

- (BOOL)hideWebView;


// Editing
- (void)setCurrentTextEditingBlock:(KTHTMLTextBlock *)textBlock;
- (KTWebViewUndoManagerProxy *)webViewUndoManagerProxy;

@end


@interface KTDocWebViewController (LoadingPrivate)
- (void)init_webViewLoading;
- (void)dealloc_webViewLoading;

- (void)loadPageIntoSourceCodeTextView:(KTPage *)page;
@end
