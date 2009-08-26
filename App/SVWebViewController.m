//
//  SVWebViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebViewController.h"

#import "KTHTMLParser.h"
#import "KTHTMLTextBlock.h"
#import "KTPage.h"
#import "SVBindableTextBlockDOMController.h"

#import "NSApplication+Karelia.h"
#import "DOMNode+Karelia.h"


@interface SVWebViewController ()
- (void)loadPage:(KTPage *)page;
@property(nonatomic, readwrite, getter=isLoading) BOOL loading;

@property(nonatomic, copy, readwrite) NSArray *textBlockControllers;

@end


#pragma mark -


@implementation SVWebViewController

#pragma mark Init & Dealloc

- (id)init
{
    [super init];
    return self;
}

- (void)dealloc
{
    [_webView release];
    [_page release];
    OBASSERT(!_textBlocks); [_textBlocks release];
    [_textBlockControllers release];
    
    [super dealloc];
}

#pragma mark View

- (void)loadView
{
    WebView *webView = [[WebView alloc] init];
    [self setView:webView];
    [self setWebView:webView];
    [webView release];
}

- (WebView *)webView
{
    [self view];    // make sure view is loaded first
    return _webView;
}

- (void)setWebView:(WebView *)webView
{
    // Tear down old delegates
    [[self webView] setFrameLoadDelegate:nil];
    [[self webView] setEditingDelegate:nil];
    
    
    // Store new webview
    [webView retain];
    [_webView release];
    _webView = webView;
    
    
    // I don't know if it really benefits us having a custom user-agent, but seems a nice courtesy. Mike.
    [webView setApplicationNameForUserAgent:[NSApplication applicationName]];
    
    
    // Spell-checking
    // TODO: Define a constant or method for this
    BOOL spellCheck = [[NSUserDefaults standardUserDefaults] boolForKey:@"ContinuousSpellChecking"];
	[webView setContinuousSpellCheckingEnabled:spellCheck];
    
    
    // Delegation
    [webView setFrameLoadDelegate:self];
    [webView setEditingDelegate:self];
}

#pragma mark Loading

- (KTPage *)page { return _page; }

- (void)setPage:(KTPage *)page
{
    [page retain];
    [_page release];
    _page = page;
    
    if (page)
    {
        [self loadPage:page];
    }
    else
    {
        // TODO: load blank webview
    }
}

// Support
- (void)loadPage:(KTPage *)page;
{
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse requests.
    [self setLoading:YES];
    
    
	// Build the HTML
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:page];
	
	/*KTWebViewComponent *webViewComponent = [[KTWebViewComponent alloc] initWithParser:parser];
	[self setMainWebViewComponent:webViewComponent];*/
	[parser setDelegate:self];
	//[webViewComponent release];*/
	
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	//[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
    OBASSERT(!_textBlocks);
    _textBlocks = [[NSMutableArray alloc] init];
    
	NSString *pageHTML = [parser parseTemplate];
	[parser release];
	
    
    // Figure out the URL to use
	NSURL *pageURL = [page URL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    
    // Load the HTML into the webview
    [[[self webView] mainFrame] loadHTMLString:pageHTML baseURL:pageURL];
}

- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTHTMLTextBlock *)textBlock;
{
    if ([textBlock isEditable]) [_textBlocks addObject:textBlock];
}

@synthesize loading = _isLoading;

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [sender mainFrame])
	{
		// Prepare controllers for each text block
        NSMutableArray *controllers = [[NSMutableArray alloc] initWithCapacity:[_textBlocks count]];
        for (KTHTMLTextBlock *aTextBlock in _textBlocks)
        {
            // Basic controller
            SVTextBlockDOMController *aController = [[SVBindableTextBlockDOMController alloc] initWithWebView:[self webView] elementID:[aTextBlock DOMNodeID]];
            [aController setRichText:[aTextBlock isRichText]];
            [aController setFieldEditor:[aTextBlock isFieldEditor]];
            
            [controllers addObject:aController];
            [aController release];
            
            // Binding
            [aController bind:NSValueBinding
                     toObject:[aTextBlock HTMLSourceObject]
                  withKeyPath:[aTextBlock HTMLSourceKeyPath]
                      options:nil];
        }
        
        [self setTextBlockControllers:controllers];
        [_textBlocks release], _textBlocks = nil;
        
        
        // Mark as loaded
        [self setLoading:NO];
	}
}

// TODO: WebFrameLoadDelegate:
//  - window title

#pragma mark Editing

/*	Called whenever the user tries to type something.
 *	We never allow a tab to be entered. (Although such a case never seems to occur)
 */
- (BOOL)webView:(WebView *)aWebView shouldInsertText:(NSString *)text replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
	BOOL result = YES;
	
	if ([text isEqualToString:@"\t"])	// Disallow tabs
	{
		result = NO;
	}
	
	return result;
}


/*	When certain actions are taken we override them
 */
- (BOOL)webView:(WebView *)aWebView doCommandBySelector:(SEL)selector
{
	OBPRECONDITION(aWebView == [self webView]);
	
    // Pass on responsibility for handling the command
    SVTextBlockDOMController *controller = [self controllerForSelection];
    return [controller webView:aWebView doCommandBySelector:selector];
}

/*  Need to return a fake undo manager so that the WebView doesn't record undo info to the window's undo manager (we will manage undo ourselves)
 */
- (NSUndoManager *)undoManagerForWebView:(WebView *)webView
{
	return [[[NSUndoManager alloc] init] autorelease];
}

// TODO: WebEditingDelegate:
//  - (void)webViewDidChangeSelection:(NSNotification *)notification
//  - (BOOL)webView:(WebView *)aWebView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action

#pragma mark Text Blocks

@synthesize textBlockControllers = _textBlockControllers;

- (SVTextBlockDOMController *)controllerForDOMNode:(DOMNode *)node;
{
    SVTextBlockDOMController *result = nil;
    DOMHTMLElement *editableElement = [node containingContentEditableElement];
    
    if (editableElement)
    {
        // Search each text block in turn for a match
        for (result in [self textBlockControllers])
        {
            if ([result DOMElement] == editableElement)
            {
                break;
            }
        }
        
        // It's possible (but very unlikely) that the editable element is part of a text block's content. If so, search up for the next one
        if (!result)
        {
            DOMNode *parent = [editableElement parentNode];
            if (parent) result = [self controllerForDOMNode:parent];
        }
    }
    
    return result;
}

- (SVTextBlockDOMController *)controllerForDOMRange:(DOMRange *)range;
{
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self controllerForDOMNode:[range startContainer]];
}

- (SVTextBlockDOMController *)controllerForSelection;
{
    return [self controllerForDOMRange:[[self webView] selectedDOMRange]];
}

@end

