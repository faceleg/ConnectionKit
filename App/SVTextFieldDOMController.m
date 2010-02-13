//
//  SVTextFieldDOMController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextFieldDOMController.h"

#import "SVTitleBoxHTMLContext.h"

#import "DOMNode+Karelia.h"


@interface SVTextFieldDOMController ()
- (void)setHTMLString:(NSString *)html needsUpdate:(BOOL)updateDOM;
@end


#pragma mark -


@implementation SVTextFieldDOMController

- (void)dealloc
{
    // Bindings don't automatically unbind themselves; have to do it ourself
    [self unbind:NSValueBinding];
    
    [_placeholder release];
    [_uneditedValue release];
    [_HTMLString release];
    
    [super dealloc];
}

#pragma mark Contents

@synthesize HTMLString = _HTMLString;
- (void)setHTMLString:(NSString *)html
{
    [self setHTMLString:html needsUpdate:YES];
}

- (void)setHTMLString:(NSString *)html needsUpdate:(BOOL)updateDOM
{
    // Store HTML
    html = [html copy];
    [_HTMLString release]; _HTMLString = html;
    
    // Update DOM to match
    if (updateDOM) [self setNeedsUpdate];
}

- (NSString *)string
{
    NSString *result = [[self textHTMLElement] innerText];
    return result;
}

- (void)setString:(NSString *)string
{
    [[self textHTMLElement] setInnerText:string];
}

#pragma mark Web Editor Item

- (BOOL)isSelectable { return [self isEditable]; }

#pragma mark Updating

- (void)update
{
    [super update];
    [[self textHTMLElement] setInnerHTML:[self HTMLString]];
}

#pragma mark Editing

- (void)didChangeText;
{
    // Validate the HTML
    SVTitleBoxHTMLContext *context = [[SVTitleBoxHTMLContext alloc] init];
    [[self textHTMLElement] writeInnerHTMLToContext:context];
    
    
    // Do usual stuff
    [super didChangeText];
    
    
    // Copy HTML across to ourself
    [self setHTMLString:[[self textHTMLElement] innerHTML] needsUpdate:NO];
    
    
    // Push change down to model
    NSString *editedValue = [context mutableString];
    if (![editedValue isEqualToString:_uneditedValue])
    {
        NSDictionary *bindingInfo = [self infoForBinding:NSValueBinding];
        id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
        
        _isCommittingEditing = YES;
        [observedObject setValue:editedValue
                      forKeyPath:[bindingInfo objectForKey:NSObservedKeyPathKey]];
        _isCommittingEditing = NO;
    }
    
    
    // Tidy up
    [context release];
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
    if ([[firstChild tagName] isEqualToString:@"A"])
    {
        element = firstChild;
        firstChild = [element firstChildOfClass:[DOMHTMLElement class]];
    }
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
    if ([self placeholderString] && [[self HTMLString] length] == 0)
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
