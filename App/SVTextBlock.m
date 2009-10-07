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

- (void)didBeginEditing;
{
    _isEditing = YES;
    
    // Subclasses might do something interesting here
}

- (void)webEditorTextDidChange:(NSNotification *)notification;
{
    // Notify that editing began if this is the case
    if (!_isEditing)
    {
        [self didBeginEditing];
    }
    
    // Can now do normal stuff in response to change
}

- (void)textDidEndEditingWithMovement:(NSNumber *)textMovement;
{
    _isEditing = NO;
    
    // Like NSTextField, we want the return key to select the field's contents
    if ([self isFieldEditor] && [textMovement intValue] == NSReturnTextMovement)
    {
        [[[self DOMElement] documentView] selectAll:self];
    }
}

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
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


