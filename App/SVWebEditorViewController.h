//
//  SVWebEditorViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSWebViewController.h"
#import "SVHTMLTemplateParser.h"
#import "SVWebEditorView.h"


@class KTPage, SVHTMLContext, SVWebTextArea;
@protocol KSCollectionController;
@protocol SVWebEditorViewControllerDelegate;


@interface SVWebEditorViewController : KSWebViewController <SVWebEditorViewDataSource, SVWebEditorViewDelegate, SVHTMLTemplateParserDelegate>
{
    BOOL                        _isLoading;
    SVHTMLContext               *_HTMLGenerationContext;
    KTPage                      *_page;
    id <KSCollectionController> _contentController;
    
    NSArray         *_textAreas;
    
    SVWebEditorView     *_webEditorView;
    DOMHTMLDivElement   *_sidebarDiv;
    NSArray             *_contentItems;
    
    id <SVWebEditorViewControllerDelegate>  _delegate;  // weak ref
}


#pragma mark View
@property(nonatomic, retain) SVWebEditorView *webEditorView;


#pragma mark Content
// Everything here should be KVO-compliant

- (void)loadHTMLString:(NSString *)html;  // you are expected to supply a valid SVHTMLContext while calling this
@property(nonatomic, readonly, getter=isLoading) BOOL loading;

//  Neither of these immediately affect the Web Editor, but are used for information upon the next load
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, retain) id <KSCollectionController> contentController;


#pragma mark Text Areas

// An array of SVTextBlock objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textAreas;
// A series of methods for retrieving the Text Block to go with a bit of the webview
- (SVWebTextArea *)textAreaForDOMNode:(DOMNode *)node;
- (SVWebTextArea *)textAreaForDOMRange:(DOMRange *)range;


#pragma mark Selectable Objects

@property(nonatomic, copy, readonly) NSArray *contentItems;
- (id <SVWebEditorItem>)contentItemForObject:(id)object;


#pragma mark Content Objects
- (IBAction)insertPagelet:(id)sender;
- (IBAction)insertPageletInSidebar:(id)sender;
- (IBAction)insertElement:(id)sender;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebEditorViewControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVWebEditorViewControllerDelegate

// The controller is not in a position to open a page by itself; it lets somebody else decide how to
- (void)webEditorViewController:(SVWebEditorViewController *)sender openPage:(KTPage *)page;

@end

