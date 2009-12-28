//
//  SVWebTextField.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextFieldController.h"

#import "DOMNode+Karelia.h"


@implementation SVWebEditorTextFieldController

- (void)dealloc
{
    // Bindings don't automatically unbind themselves; have to do it ourself
    [self unbind:NSValueBinding];
    
    [_placeholder release];
    [_uneditedValue release];
    
    [super dealloc];
}

#pragma mark Bindings/NSEditor

+ (void)initialize
{
    // Bindings
    [self exposeBinding:NSValueBinding];
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
        
        // The change needs to be pushed through the GUI unless it was triggered by the user in the first place
        if (!_isCommittingEditing)
        {
            if ([self isRichText])
            {
                [self setHTMLString:value];
            }
            else
            {
                [self setString:value];
            }
        }
    }
    else
    {
        [super setValue:value forKey:key];
    }
}

- (BOOL)commitEditing;
{
    // It's just like ending editing via the return key
    [self didEndEditingTextWithMovement:[NSNumber numberWithInt:NSReturnTextMovement]];
    return YES;
}

- (void)didChangeText;
{
    [super didChangeText];
    
    
    // Push change down into the model
    NSString *editedValue = ([self isRichText] ? [self HTMLString] : [self string]);
    if (![editedValue isEqualToString:_uneditedValue])
    {
        NSDictionary *bindingInfo = [self infoForBinding:NSValueBinding];
        id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
        
        _isCommittingEditing = YES;
        [observedObject setValue:editedValue
                      forKeyPath:[bindingInfo objectForKey:NSObservedKeyPathKey]];
        _isCommittingEditing = NO;
    }
}

#pragma mark Placeholder

@synthesize placeholderString = _placeholder;
- (void)setPlaceholderString:(NSString *)placeholder
{
    // Store placeholder
    placeholder = [placeholder copy];
    [_placeholder release]; _placeholder = placeholder;
    
    // Display new placeholder if appropriate
    if ([[self HTMLString] length] == 0)
    {
        [[self textHTMLElement] setInnerText:placeholder];
    }
}

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    
    // Figure out the text element. Doing so by inspecting the DOM feels a little hacky to me, so would like to revisit.
    DOMHTMLElement *firstChild = [element firstChildOfClass:[DOMHTMLElement class]];
    if ([[firstChild tagName] isEqualToString:@"SPAN"] &&
        [[firstChild className] hasPrefix:@"in"])
    {
        [self setTextHTMLElement:firstChild];
    }
    else
    {
        [self setTextHTMLElement:element];
    }
}

- (void)setTextHTMLElement:(DOMHTMLElement *)element
{
    [super setTextHTMLElement:element];
    
    // Once attached to our DOM node, give it the placeholder text if needed
    if ([[self HTMLString] length] == 0 && [self placeholderString])
    {
        [[self textHTMLElement] setInnerText:[self placeholderString]];
    }
}

#pragma mark Debugging

- (NSString *)blurb
{
    return [[self textHTMLElement] innerText];
}

@end
