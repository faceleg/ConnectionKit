//
//  SVWebViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"
#import "KTHTMLParser.h"
#import "SVEditingOverlay.h"


@class WebView, KTPage, SVTextBlock;


@interface SVWebViewController : KSWebViewController <SVWebEditingOverlayDataSource, KTHTMLParserDelegate>
{
    KTPage  *_page;
    BOOL    _isLoading;
    
    NSMutableArray  *_HTMLTextBlocks;
    NSArray         *_textBlocks;
    SVTextBlock     *_selectedTextBlock;
    
    SVEditingOverlay    *_editingOverlay;
    NSArray             *_contentItems;
}

// These should all be KVO-compliant
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;


#pragma mark Text Blocks

// An array of SVTextBlock objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textBlocks;
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVTextBlock *)textBlockForDOMNode:(DOMNode *)node;
- (SVTextBlock *)textBlockForDOMRange:(DOMRange *)range;

// Tracks what is selected in the webview in a KVO-compliant manner
@property(nonatomic, retain, readonly) SVTextBlock *selectedTextBlock;


#pragma mark Selectable Objects

@property(nonatomic, retain) SVEditingOverlay *editingOverlay;
@property(nonatomic, copy, readonly) NSArray *contentItems;

@end
