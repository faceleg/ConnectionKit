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
#import "SVContainerTextBlock.h"
#import "SVContentObject.h"

#import "DOMNode+Karelia.h"


@interface SVWebViewController ()
- (void)loadPage:(KTPage *)page;
@property(nonatomic, readwrite, getter=isLoading) BOOL loading;

@property(nonatomic, copy, readwrite) NSArray *textBlocks;
@property(nonatomic, retain, readwrite) SVTextBlock *selectedTextBlock;

@property(nonatomic, copy, readwrite) NSArray *contentObjects;

@end


#pragma mark -


@implementation SVWebViewController

#pragma mark Init & Dealloc

- (id)init
{
    return [self initWithNibName:@"WebView" bundle:nil];
}

- (void)dealloc
{
    [self setEditingOverlayView:nil];   // needed to tear down data source
    
    [_page release];
    OBASSERT(!_HTMLTextBlocks); [_HTMLTextBlocks release];
    [_textBlocks release];
    
    [super dealloc];
}

#pragma mark Views

- (void)setWebView:(WebView *)webView
{
    // Tear down old delegates
    [[self webView] setFrameLoadDelegate:nil];
    [[self webView] setEditingDelegate:nil];
    
    
    // Store new webview
    [super setWebView:webView];
    
    
    // Spell-checking
    // TODO: Define a constant or method for this
    BOOL spellCheck = [[NSUserDefaults standardUserDefaults] boolForKey:@"ContinuousSpellChecking"];
	[webView setContinuousSpellCheckingEnabled:spellCheck];
    
    
    // Delegation
    [webView setFrameLoadDelegate:self];
    [webView setEditingDelegate:self];
}

@synthesize editingOverlayView = _editingOverlay;
- (void)setEditingOverlayView:(SVWebEditingOverlay *)overlay
{
    [[self editingOverlayView] setDataSource:nil];
    
    [overlay retain];
    [_editingOverlay release];
    _editingOverlay = overlay;
    
    [overlay setDataSource:self];
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
	
    OBASSERT(!_HTMLTextBlocks);
    _HTMLTextBlocks = [[NSMutableArray alloc] init];
    
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
    if ([textBlock isEditable]) [_HTMLTextBlocks addObject:textBlock];
}

@synthesize loading = _isLoading;

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [sender mainFrame])
	{
		// Prepare controllers for each text block
        NSMutableArray *controllers = [[NSMutableArray alloc] initWithCapacity:[_HTMLTextBlocks count]];
        DOMDocument *domDoc = [[self webView] mainFrameDocument];
        
        for (KTHTMLTextBlock *aTextBlock in _HTMLTextBlocks)
        {
            // Basic controller
            DOMHTMLElement *element = (DOMHTMLElement *)[domDoc getElementById:[aTextBlock DOMNodeID]];
            OBASSERT([element isKindOfClass:[DOMHTMLElement class]]);
            
            Class textBlockClass = ([aTextBlock importsGraphics] ? [SVContainerTextBlock class] : [SVBindableTextBlock class]);
            SVTextBlock *aController = [[textBlockClass alloc] initWithDOMElement:element];
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
        
        [self setTextBlocks:controllers];
        [_HTMLTextBlocks release], _HTMLTextBlocks = nil;
        
        
        
        // Set up selection borders for all pagelets. Could we do this better by receiving a list of pagelets from the parser?
        NSArray *pagelets = [[[self page] sidebarPagelets] arrayByAddingObjectsFromArray:[[self page] callouts]];
        NSMutableArray *contentObjects = [[NSMutableArray alloc] initWithCapacity:[pagelets count]];
        
        for (KTPagelet *aPagelet in pagelets)
        {
            NSString *pageletID = [@"k-" stringByAppendingString:aPagelet.uniqueID];
            DOMElement *element = [domDoc getElementById:pageletID];
            
            SVContentObject *object = [[SVContentObject alloc] initWithDOMElement:element];
            
            [contentObjects addObject:object];
            [object release];
            
            
            [[self editingOverlayView] insertObject:element inSelectedNodesAtIndex:0];
        }
        
        [self setContentObjects:contentObjects];
        [contentObjects release];
        
        
        // Mark as loaded
        [self setLoading:NO];
	}
}

// TODO: WebFrameLoadDelegate:
//  - window title

#pragma mark Editing

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    OBPRECONDITION([notification object] == [self webView]);
	
    [self setSelectedTextBlock:[self textBlockForDOMRange:[[self webView] selectedDOMRange]]];
}

- (BOOL)webView:(WebView *)aWebView shouldEndEditingInDOMRange:(DOMRange *)range
{
    OBPRECONDITION(aWebView == [self webView]);
	
    // Ask the text block if it wants to end editing
    SVTextBlock *textBlock = [self textBlockForDOMRange:range];
    BOOL result = (textBlock ? [textBlock shouldEndEditing] : YES);
    return result;
}

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
    return [[self selectedTextBlock] webView:aWebView doCommandBySelector:selector];
}

/*  Need to return a fake undo manager so that the WebView doesn't record undo info to the window's undo manager (we will manage undo ourselves)
 */
- (NSUndoManager *)undoManagerForWebView:(WebView *)webView
{
	return [[[NSUndoManager alloc] init] autorelease];
}

// TODO: WebEditingDelegate:
//  - (BOOL)webView:(WebView *)aWebView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action

#pragma mark Text Blocks

@synthesize textBlocks = _textBlocks;

- (SVTextBlock *)textBlockForDOMNode:(DOMNode *)node;
{
    SVTextBlock *result = nil;
    DOMHTMLElement *editableElement = [node containingContentEditableElement];
    
    if (editableElement)
    {
        // Search each text block in turn for a match
        for (result in [self textBlocks])
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
            if (parent) result = [self textBlockForDOMNode:parent];
        }
    }
    
    return result;
}

- (SVTextBlock *)textBlockForDOMRange:(DOMRange *)range;
{
    // One day there might be better logic to apply, but for now, testing the start of the range is enough
    return [self textBlockForDOMNode:[range startContainer]];
}

@synthesize selectedTextBlock = _selectedTextBlock;

#pragma mark Content Objects

@synthesize contentObjects = _contentObjects;

- (BOOL)webEditingView:(SVWebEditingOverlay *)view nodeIsSelectable:(DOMNode *)node;
{
    BOOL result = NO;
    
    for (SVContentObject *aContentObject in [self contentObjects])
    {
        if ([node isDescendantOfNode:[aContentObject DOMElement]])
        {
            result = YES;
            break;
        }
    }
    
    return result;
}

@end

