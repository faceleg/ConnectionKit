//
//  SVTextFieldDOMController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextFieldDOMController.h"

#import "SVHTMLTextBlock.h"
#import "SVFieldEditorHTMLWriter.h"
#import "SVWebEditorHTMLContext.h"

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

/*      turned off for #75052
- (BOOL)isSelectable
{
    BOOL result = ([self representedObject] && [[self selectableAncestors] count] == 0);
    
    if ([self textBlock] && [[self textBlock] hyperlinkString]) result = NO;
    
    return result;
}*/

#pragma mark Updating

- (void)update
{
    [super update];
    
    [[self textHTMLElement] setInnerHTML:[self HTMLString]];
    
    // Mimic NSTextField and select all
    DOMRange *range = [[[self HTMLElement] ownerDocument] createRange];
    [range selectNodeContents:[self textHTMLElement]];
    [[self webEditor] setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
}

#pragma mark Editing

- (void)webEditorTextDidBeginEditing;
{
    [super webEditorTextDidBeginEditing];
    
    // Remove any graphical text. But make sure to maintain element size otherwise editing feels weird
    if ([[[self HTMLElement] className] rangeOfString:@"replaced"].location != NSNotFound)
    {
        NSSize size = [[self HTMLElement] boundingBox].size;
        
        NSString *style = [[NSString alloc] initWithFormat:
                           @"min-width:%fpx; min-height:%fpx;",
                           size.width, size.height];
        
        [[[self HTMLElement] style] setCssText:style];
        [style release];
    }
}

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
{
    [super webEditorTextDidEndEditing:notification];
    
    
    // Restore graphical text
    SVHTMLContext *context = [self HTMLContext];
    [context push];
    NSString *style = [[self textBlock] graphicalTextPreviewStyle];
    [context pop];
    
    if (style)
    {
        [[[self HTMLElement] style] setCssText:style];
    }
}

- (void)webEditorTextDidChange;
{
    // Validate the HTML
    NSMutableString *html = [[NSMutableString alloc] init];
    SVFieldEditorHTMLWriter *context = [[SVFieldEditorHTMLWriter alloc] initWithStringWriter:html];
    [html release];
    
    
    DOMHTMLElement *textElement = [self innerTextHTMLElement];
    if (textElement)
    {
        [context writeInnerOfDOMNode:textElement];
    }
    
    
    // Copy HTML across to ourself
    if (![html isEqualToString:_uneditedValue])
    {
        [self setHTMLString:html needsUpdate:NO];
        
        
        // Push change down to model
        NSDictionary *bindingInfo = [self infoForBinding:NSValueBinding];
        id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
        
        _isCommittingEditing = YES;
        [observedObject setValue:html
                      forKeyPath:[bindingInfo objectForKey:NSObservedKeyPathKey]];
        _isCommittingEditing = NO;
    }
    
    
    // Finish up
    [context release];
    [super webEditorTextDidChange];
}

#pragma mark Alignment

/*  Text fields don't support alignment, so trap such calls. Bwahahaha!!
 */

- (IBAction)alignCenter:(id)sender; { NSBeep(); }
- (IBAction)alignJustified:(id)sender; { NSBeep(); }
- (IBAction)alignLeft:(id)sender; { NSBeep(); }
- (IBAction)alignRight:(id)sender; { NSBeep(); }

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = YES;
    
    SEL action = [anItem action];
    if (action == @selector(alignCenter:) ||
        action == @selector(alignJustified:) ||
        action == @selector(alignLeft:) ||
        action == @selector(alignRight:))
    {
        result = NO;
    }
    
    return result;
}

#pragma mark Links

- (IBAction)createLink:(id)sender { NSBeep(); }

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
            [self setHTMLString:value];
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
    [self setTextHTMLElement:element];
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

- (DOMHTMLElement *)innerTextHTMLElement;
{
    DOMHTMLElement *result = [self textHTMLElement];
    SVHTMLTextBlock *textBlock = [self textBlock];
    
    if ([textBlock hyperlinkString])
    {
        DOMHTMLElement *firstChild = [result firstChildOfClass:[DOMHTMLElement class]];
        result = ([[firstChild tagName] isEqualToString:@"A"] ? firstChild : nil);
    }
    
    if ([textBlock generateSpanIn])
    {
        DOMHTMLElement *firstChild = [result firstChildOfClass:[DOMHTMLElement class]];
        
        if ([[firstChild tagName] isEqualToString:@"SPAN"] &&
            [[firstChild className] isEqualToString:@"in"])
        {
            result = firstChild;
        }
        else
        {
            result = nil;
        }
    }
    
    return result;
}

#pragma mark Debugging

- (NSString *)blurb
{
    if ([self isHTMLElementCreated]) return [[self textHTMLElement] innerText];
    return [super blurb];
}

@end


#pragma mark -


#import "SVTitleBox.h"


@implementation SVTitleBox (SVDOMController)

- (SVDOMController *)newDOMController;
{
    SVTextDOMController *result = [[SVTextFieldDOMController alloc] init];
    [result setRepresentedObject:self];
    [result setRichText:YES];
    [result setFieldEditor:YES];
    
    // Bind to model
    [result bind:NSValueBinding
        toObject:self
     withKeyPath:@"textHTMLString"
         options:nil];
    
    return result;
}

@end
