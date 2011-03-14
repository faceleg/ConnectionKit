//
//  SVURLPreviewViewController.m
//  Sandvox
//
//  Created by Mike on 15/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVURLPreviewViewController.h"

#import "KTDocWindowController.h"
#import "SVHTMLContext.h"
#import "KTHTMLEditorController.h"
#import "SVMediaRecord.h"
#import "SVSiteItem.h"
#import "SVTemplate.h"
#import "SVTemplateParser.h"
#import "SVExternalLink.h"
#import "SVWebContentAreaController.h"

#import "NSString+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "KSURLUtilities.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


static NSString *sURLPreviewViewControllerURLObservationContext = @"URLPreviewViewControllerURLObservation";


// NSLocalizedString(@"This page is a placeholder for the file ", "String_On_DownloadTemplate")
// NSLocalizedString(@"A link to this page will cause the file to be downloaded by the browser.", "String_On_DownloadTemplate")

// NSLocalizedString(@"No URL specified", "String_On_LinkPageTemplate")
// NSLocalizedString(@"Drag a link here or enter the URL below", "String_On_LinkPageTemplate")



@interface SVURLPreviewViewController ()
@end


#pragma mark -


@implementation SVURLPreviewViewController

@synthesize metaDescription = _metaDescription;

- (void)dealloc
{
    [self setSiteItem:nil];
    [super dealloc];
}

#pragma mark View

- (void)setWebView:(WebView *)webView
{
    [super setWebView:webView];
    [webView setFrameLoadDelegate:self];
    [webView setPolicyDelegate:self];
    [webView setUIDelegate:self];
}

- (NSString *)HTMLTemplateAndURL:(NSURL **)outURL
{
    static SVTemplate *template;
    static NSURL *URL;
    if (!template && !URL)
    {
        URL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Download"
                                                                                 ofType:@"html"]];
        template = [[SVTemplate alloc] initWithContentsOfURL:URL];
    }
    
    if (outURL) *outURL = URL;
    return [template templateString];
}

#pragma mark Actions

- (BOOL)canEditHTML;
{
    SVSiteItem *item = [self siteItem];
    SVMediaRecord *media = [item mediaRepresentation];
    if (media)
    {
        return [media isEditableText];
    }
    return NO;
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
    if ([self canEditHTML])
    {
        SVSiteItem *item = [self siteItem];
        
        KTHTMLEditorController *controller = [[[[self view] window] windowController] HTMLEditorController];
        
        [controller setHTMLSourceObject:(id <KTHTMLSourceObject>)item];
        
        [controller showWindow:self];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
{
    BOOL result = YES;
    
    if ([menuItem action] == @selector(editRawHTMLInSelectedBlock:))
    {
        result = [self canEditHTML];
    }
    
    return result;
}

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame;
{
    SVWebContentAreaController *tabController = (id)[self parentViewController];    // yes, hack
    if ([tabController selectedViewControllerWhenReady] == self)
    {
        [tabController setSelectedViewController:self];
    }
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        // Build HTML
        NSURL *baseURL = nil;
        NSString *template = [self HTMLTemplateAndURL:&baseURL];
        NSMutableString *markup = [[NSMutableString alloc] init];
        
        SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:markup];
        [SVTemplateParser parseTemplate:template component:self writeToStream:context];
        
        // Load
        [frame loadAlternateHTMLString:markup
                               baseURL:baseURL
                     forUnreachableURL:[self URLToLoad]];
        
        // Tidy up
        [markup release];
        [context release];
    }
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [self setTitle:title];
		[self webView:sender didFinishLoadForFrame:frame];		// frame not loaded yet, but we MIGHT have the meta description by now, so try it early.
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
{
	if (nil == self.metaDescription && frame == [sender mainFrame])	// only check if we don't have our meta description yet
	{
		DOMDocument *domDoc = [frame DOMDocument];
		DOMNodeList *metas = [domDoc getElementsByTagName:@"meta"];
		unsigned i, length = [metas length];
		for (i = 0; i < length; i++)
		{
			DOMHTMLMetaElement *node = (DOMHTMLMetaElement *)[metas item:i];
			NSString *name = [node name];
			if ([[name lowercaseString] isEqualToString:@"description"])
			{
				NSString *content = [node content];
				
				self.metaDescription = content;		// this will then get propagated to the page details controller
				break;	// no point in looping through more meta tags
			}
		}
	}
}


#pragma mark Presentation

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Did we move because of an in-progress load?
    if (![[self webView] isLoading])
    {
        [self setSiteItem:nil];
    }
    
    // clear title, meta description, since they are not applicable anymore
	self.title = nil;
	self.metaDescription = nil;
}

#pragma mark Loading

- (BOOL)viewShouldAppear:(BOOL)animated
webContentAreaController:(SVWebContentAreaController *)controller;
{
    // Don't want to appear until old page is unloaded. But if we're already on screen, that's fine
    BOOL result = ([controller selectedViewController] == self || ![self siteItem]);
    
    // Start loading the page
    [self setSiteItem:[controller selectedPage]];
    
    return result;
}

@synthesize siteItem = _siteItem;
- (void)setSiteItem:(SVSiteItem *)item
{
    // Close HTML editor
    if ([self siteItem])
    {
        KTDocWindowController *windowController = [[[[self parentViewController] view] window] windowController];
        KTHTMLEditorController *editor = [windowController HTMLEditorController];
        
        if ((id)[editor HTMLSourceObject] == [self siteItem])
        {
            [windowController setHTMLEditorController:nil];
        }
    }
    
    
    // teardown
    [_siteItem removeObserver:self forKeyPath:@"URL"];
    [_siteItem removeObserver:self forKeyPath:@"mediaRepresentation"];
    
    item = [item retain];
    [_siteItem release]; _siteItem = item;
    
    
    // observe new
    if (item)
    {
        [item addObserver:self
               forKeyPath:@"URL" 
                  options:NSKeyValueObservingOptionInitial
                  context:sURLPreviewViewControllerURLObservationContext];
        [item addObserver:self
               forKeyPath:@"mediaRepresentation" 
                  options:NSKeyValueObservingOptionInitial
                  context:sURLPreviewViewControllerURLObservationContext];
    }
    else
    {
        [[self webView] close];
        [self setWebView:nil];
        [self setView:nil];
    }
}

- (NSURL *)URLToLoad;
{
    SVSiteItem *item = [self siteItem];
    SVMediaRecord *media = [item mediaRepresentation];
    
    if (media)
    {
        return [[item mediaRepresentation] fileURL];
    }
    else
    {
        return [item URL];
    }
}

- (NSString *)iconURL
{
	NSString *iconPath = [[NSBundle mainBundle] pathForImageResource:@"download"];
	NSString *result = [[NSURL fileURLWithPath:iconPath] absoluteString];
	return result;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sURLPreviewViewControllerURLObservationContext)
    {
		self.title = nil;
		self.metaDescription = nil;		// clear out these data ASAP so we don't show old values
		
        // Display best representation
        WebFrame *frame = [[self webView] mainFrame];
        NSURL *URL = [self URLToLoad];
        
        if (URL)
        {
			[frame stopLoading];		// stop loading any previous page
			OFF((@"Loading %@", URL));
            [frame loadRequest:[NSURLRequest requestWithURL:URL]];
        }
        else
        {
            SVMediaRecord *record = [object mediaRepresentation];
            if (record)
            {
                NSString *filename = [record preferredFilename];
                NSString *type = [NSString UTIForFilenameExtension:[filename pathExtension]];
                NSData *data = [NSData newDataWithContentsOfMedia:[record media]];
                
                [frame loadData:data
                       MIMEType:[NSString MIMETypeForUTI:type]
               textEncodingName:nil
                        baseURL:[object URL]];
                [data release];
            }
            else
            {
                // Placeholder. #104314
                SVTemplate *template = [SVTemplate templateNamed:@"LinkPageTemplate.html"];
                
                SVTemplateParser *parser = [[SVTemplateParser alloc]
                                            initWithTemplate:[template templateString]
                                            component:[self siteItem]];
                
                NSMutableString *html = [[NSMutableString alloc] init];
                [parser parseWithOutputWriter:html];
                [parser release];
                
                [frame loadHTMLString:html baseURL:nil];
                [html release];
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (IBAction)reload:(id)sender
{
    [[self webView] reload:sender];
}

#pragma mark WebPolicyDelegate

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener;
{
    BOOL result = YES;
    
    if (frame == [webView mainFrame])
    {
        WebNavigationType type = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
        switch (type)
        {
            case WebNavigationTypeOther:
                if (_copyNextLoadedURLToModel)
                {
                    _copyNextLoadedURLToModel = NO;
                    [(SVExternalLink *)[self siteItem] setURL:[request URL]];
                }
                
            case WebNavigationTypeReload:
                break;
                
            default:
                result = NO;
        }
    }
    
    if (result)
    {
        [listener use];
    }
    else
    {
        [listener ignore];
        NSURL *URL = [request URL];
        [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
    }
    
    _copyNextLoadedURLToModel = NO; // reset
}

/*	We don't want to allow navigation within Sandvox! Open in web browser instead
 */
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
decisionListener:(id <WebPolicyDecisionListener>)listener
{
	// Open the URL in the user's web browser
	[listener ignore];
	
	NSURL *URL = [request URL];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
}

#pragma mark WebUIDelegate

- (void)webView:(WebView *)sender willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id < NSDraggingInfo >)draggingInfo
{
    if (action == WebDragDestinationActionLoad) _copyNextLoadedURLToModel = YES;
}

@end
