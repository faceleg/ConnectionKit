//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextBlockDOMController.h"


@implementation SVTextBlockDOMController

- (id)initWithWebView:(WebView *)webView elementID:(NSString *)elementID;
{
    [super init];
    
    _webView = [webView retain];
    _elementID = [elementID copy];
    
    return self;
}

- (void)dealloc
{
    [_webView release];
    [_elementID release];
    
    [super dealloc];
}

- (void)loadDOMElement
{
    DOMElement *element = [[[_webView mainFrame] DOMDocument] getElementById:_elementID];
    if ([element isKindOfClass:[DOMHTMLElement class]])
    {
        [self setDOMElement:(DOMHTMLElement *)element];
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

- (void)didChangeText;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self];
}

- (void)didBeginEditingText;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidBeginEditingNotification object:self];
}

- (void)didEndEditingText;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidEndEditingNotification object:self];
}

- (BOOL)webView:(WebView *)aWebView doCommandBySelector:(SEL)selector
{
    BOOL result = NO;
    
    if (selector == @selector(insertNewline:) && [self isFieldEditor])
	{
		[self commitEditing];
		result = YES;
	}
	// When the user hits option-return insert a line break.
	else if (selector == @selector(insertNewlineIgnoringFieldEditor:))
	{
		[[[aWebView window] firstResponder] insertLineBreak:self];
		result = YES;
	}
	
	return result;
}

@end
