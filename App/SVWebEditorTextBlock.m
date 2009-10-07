//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextBlock.h"

#import "DOMNode+Karelia.h"


@interface SVWebEditorTextBlock ()
- (void)discardEditing_Undo;
@end


#pragma mark -


@implementation SVWebEditorTextBlock

#pragma mark Init & Dealloc

+ (void)initialize
{
    // Bindings
    [self exposeBinding:NSValueBinding];
}

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

@synthesize editing = _isEditing;

- (void)didBeginEditing;
{
    // Mark as editing
    OBPRECONDITION(_isEditing == NO);
    _isEditing = YES;
    
    
    // Tell controller we're starting editing
    [_controller objectDidBeginEditing:self];
    
    
    // Register undo op so the user can get back here if they wish
    [[[self undoManager] prepareWithInvocationTarget:self] discardEditing_Undo];
}

- (void)webEditorTextDidChange:(NSNotification *)notification;
{
    // Notify that editing began if this is the case
    if (![self isEditing])
    {
        [self didBeginEditing];
    }
    
    // Can now do other stuff in response to change
}

- (void)didEndEditingWithMovement:(NSNumber *)textMovement;
{
    // Handle any bindings
    if ([self isEditing])
    {
        // Push changes from the DOM down into the model
        NSString *editedValue = ([self isRichText] ? [self HTMLString] : [self string]);
        NSDictionary *bindingInfo = [self infoForBinding:NSValueBinding];
        id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
        [observedObject setValue:editedValue
                          forKey:[bindingInfo objectForKey:NSObservedKeyPathKey]];
        
        
        // Inform controller
        [_controller objectDidEndEditing:self];
    }
    
    
    _isEditing = NO;
    
    
    // Like NSTextField, we want the return key to select the field's contents
    if ([self isFieldEditor] && [textMovement intValue] == NSReturnTextMovement)
    {
        [[[self DOMElement] documentView] selectAll:self];
    }
}

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
{
    [self didEndEditingWithMovement:nil];
}

- (BOOL)doCommandBySelector:(SEL)selector
{
    BOOL result = NO;
    
    if (selector == @selector(insertNewline:) && [self isFieldEditor])
	{
		// Return key ends editing
        [self didEndEditingWithMovement:[NSNumber numberWithInt:NSReturnTextMovement]];
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

- (NSUndoManager *)undoManager
{
    if (!_undoManager)
    {
        // Just use the window's undo manager for now. Might get cleverer later
        _undoManager = [[[[[self DOMElement] documentView] window] undoManager] retain];
    }
    
    return _undoManager;
}

#pragma mark Bindings/NSEditor

- (void)bind:(NSString *)binding toObject:(id)observableController withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
    [super bind:binding toObject:observableController withKeyPath:keyPath options:options];
    
    // Want to store the controller for covenience
    if ([binding isEqualToString:NSValueBinding])
    {
        if ([observableController respondsToSelector:@selector(objectDidBeginEditing:)] &&
            [observableController respondsToSelector:@selector(objectDidEndEditing:)])
        {
            _controller = observableController; // weak ref
        }
    }
}

- (void)unbind:(NSString *)binding
{
    [super unbind:binding];
    
    if ([binding isEqualToString:NSValueBinding])
    {
        _controller = nil;
    }
}

/*  These 2 bridge Cocoa's "value" binding terminology with our internal one
 */

- (id)valueForKey:(NSString *)key
{
    if ([key isEqualToString:NSValueBinding])
    {
        return _uneditedValue;
    }
    else
    {
        return [super valueForKey:key];
    }
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    if ([key isEqualToString:NSValueBinding])
    {
        value = [value copy];
        [_uneditedValue release], _uneditedValue = value;
        
        if ([self isRichText])
        {
            [self setHTMLString:value];
        }
        else
        {
            [self setString:value];
        }
    }
    else
    {
        [super setValue:value forKey:key];
    }
}

- (void)discardEditing_Undo
{
    // I didn't want to implement -discardEditing, at least not yet. So had to mangle the name a little!
    
    // Reset DOM to original markup. Take advantage of our binding support to do this
    [self setValue:_uneditedValue forKey:NSValueBinding];
}

- (BOOL)commitEditing;
{
    // It's just like ending editing via the return key
    [self didEndEditingWithMovement:[NSNumber numberWithInt:NSReturnTextMovement]];
    return YES;
}

#pragma mark Sub-content

// Our subclasses implement this properly
- (NSArray *)contentItems { return nil; }

@end


