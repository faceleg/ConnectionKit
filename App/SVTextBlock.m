//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextBlock.h"

#import "DOMNode+Karelia.h"


@implementation SVTextBlock

- (id)init
{
    return [self initWithDOMElement:nil];
}

- (id)initWithDOMElement:(DOMHTMLElement *)element;
{
    OBPRECONDITION(element);
    
    [super init];
    
    _element = [element retain];
    [self setWebView:[[[element ownerDocument] webFrame] webView]];
    
    return self;
}

- (void)dealloc
{
    [self setWebView:nil];
    [_element release];
    
    [super dealloc];
}

#pragma mark WebView

@synthesize DOMElement = _element;

@synthesize webView = _webView;
- (void)setWebView:(WebView *)webView
{
    // We monitor the webview for editing so as to mark ourself as editing if appropriate
    if (_webView)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:WebViewDidChangeNotification
                                                      object:_webView];
    }
    
    [webView retain];
    [_webView release];
    _webView = webView;
    
    if (webView)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(webViewDidChange:)
                                                     name:WebViewDidChangeNotification
                                                   object:webView];
    }
}

#pragma mark Contents

- (NSString *)HTMLString
{
    NSString *result = [[self DOMElement] innerHTML];
    return result;
}

- (void)setHTMLString:(NSString *)html
{
    [[self DOMElement] setInnerHTML:html];
}

- (NSString *)string
{
    NSString *result = [[self DOMElement] innerText];
    return result;
}

- (void)setString:(NSString *)string
{
    [[self DOMElement] setInnerText:string];
}

#pragma mark Attributes

- (BOOL)isEditable
{
    BOOL result = [[self DOMElement] isContentEditable];
    return result;
}

- (void)setEditable:(BOOL)flag
{
    [[self DOMElement] setContentEditable:(flag ? @"true" : nil)];
}

// Note that it's only a property for controlling editing by the user, it does not affect the existing HTML or stop programmatic editing of the HTML.
@synthesize isRichText = _isRichText;

@synthesize isFieldEditor = _isFieldEditor;

#pragma mark Editing

- (void)textDidEndEditingWithMovement:(NSNumber *)textMovement;
{
    _isEditing = NO;
    
    // Like NSTextField, we want the return key to select the field's contents
    if ([self isFieldEditor] && [textMovement intValue] == NSReturnTextMovement)
    {
        [[[self DOMElement] documentView] selectAll:self];
    }
}

#pragma mark SVWebEditorText

- (void)textDidEndEditing
{
    [self textDidEndEditingWithMovement:nil];
}

- (BOOL)doCommandBySelector:(SEL)selector
{
    BOOL result = NO;
    
    if (selector == @selector(insertNewline:) && [self isFieldEditor])
	{
		// Return key ends editing
        [self textDidEndEditingWithMovement:[NSNumber numberWithInt:NSReturnTextMovement]];
		result = YES;
	}
	else if (selector == @selector(insertNewlineIgnoringFieldEditor:))
	{
		// When the user hits option-return insert a line break.
        [[[[self webView] window] firstResponder] insertLineBreak:self];
		result = YES;
	}
	
	return result;
}

#pragma mark Sub-content

// Our subclasses implement this properly
- (NSArray *)contentItems { return nil; }

@end


#pragma mark -


@implementation SVTextBlock (Support)

#pragma mark Editing

- (void)didChangeText;
{
    // Notify that editing began if this is the case
    if (!_isEditing)
    {
        _isEditing = YES;
        [self didBeginEditingText];
    }
    
    // Notify of the change
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self];
}

- (void)didBeginEditingText;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidBeginEditingNotification object:self];
}

- (void)webViewDidChange:(NSNotification *)notification
{
    OBPRECONDITION([notification object] == [self webView]);
    
    
}

@end
