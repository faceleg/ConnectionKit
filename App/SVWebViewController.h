//
//  SVWebViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"
#import "SVHTMLTemplateParser.h"
#import "SVWebEditorView.h"


@class KTPage, SVWebTextArea;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebViewController : KSWebViewController <SVWebEditorViewDataSource, SVWebEditorViewDelegate, SVHTMLTemplateParserDelegate>
{
    KTPage  *_page;
    BOOL    _isLoading;
    
    NSMutableArray  *_parsedTextBlocks;
    NSArray         *_textAreas;
    NSArray         *_textAreaControllers;
    
    SVWebEditorView     *_webEditorView;
    DOMHTMLDivElement   *_sidebarDiv;
    NSArray             *_contentItems;
    
    id <SVWebEditorViewControllerDelegate>  _delegate;  // weak ref
}


#pragma mark View
@property(nonatomic, retain) SVWebEditorView *webEditorView;


#pragma mark Page
// These should all be KVO-compliant
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;


#pragma mark Text Areas

// An array of SVTextBlock objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textAreas;
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVWebTextArea *)textAreaForDOMNode:(DOMNode *)node;
- (SVWebTextArea *)textAreaForDOMRange:(DOMRange *)range;

@property(nonatomic, copy, readonly) NSArray *textAreaControllers;


#pragma mark Selectable Objects

@property(nonatomic, copy, readonly) NSArray *contentItems;


#pragma mark Elements
- (IBAction)insertElement:(id)sender;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebEditorViewControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebEditorViewControllerDelegate

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)webEditorViewController:(SVWebViewController *)sender openPage:(KTPage *)page;

@end

