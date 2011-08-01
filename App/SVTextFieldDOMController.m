//
//  SVTextFieldDOMController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVTextFieldDOMController.h"

#import "SVHTMLTextBlock.h"
#import "SVFieldEditorHTMLWriterDOMAdapator.h"
#import "SVWebEditorHTMLContext.h"

#import "DOMNode+Karelia.h"
#import "NSString+Karelia.h"


@interface SVTextFieldDOMController ()
- (void)setHTMLString:(NSString *)html needsUpdate:(BOOL)updateDOM;
@end


#pragma mark -


@implementation SVTextFieldDOMController

- (id)init;
{
    if (self = [super init])
    {
        _alignment = NSNaturalTextAlignment;
    }
    return self;
}

- (void)dealloc
{
    // Bindings don't automatically unbind themselves; have to do it ourself
    [self unbind:NSValueBinding];
    [self unbind:NSAlignmentBinding];
    
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
    if (updateDOM && [self textHTMLElement]) [self setNeedsUpdate];
}

- (NSString *)string
{
    NSString *result = [[self textHTMLElement] innerText];
    return result;
}

- (void)setString:(NSString *)string
{
    [[self innerTextHTMLElement] setInnerText:string];
}

#pragma mark Web Editor Item

/*      turned off for #75052
- (BOOL)isSelectable
{
    BOOL result = ([self representedObject] && [[self selectableAncestors] count] == 0);
    
    if ([self textBlock] && [[self textBlock] hyperlinkString]) result = NO;
    
    return result;
}*/

// TODO: This logic is the same as aux text
- (BOOL)isSelectable;
{
    return ([self representedObject] && [self enclosingGraphicDOMController]);
}

#pragma mark Updating

- (void)updateStyle
{
    // Regenerate style
      SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc]
                                       initWithOutputWriter:nil
                                       inheritFromContext:[self HTMLContext]];
    [[self textBlock] buildGraphicalText:context];
    
    
    // Copy across dependencies. #117522
    for (KSObjectKeyPathPair *aDependency in [[context rootDOMController] dependencies])
    {
        [self addDependency:aDependency];
    }
    
    NSString *style = [[[context currentElementInfo] attributesAsDictionary] objectForKey:@"style"];
    [[[self textHTMLElement] style] setCssText:style];
    [self setAlignment:[self alignment]];   // repair alignemnt #113613
    
    [context close];
    [context release];
}

- (void)update
{
    BOOL selectAfterUpdate = ([[self webEditor] focusedText] == self);
    
    DOMHTMLElement *innerTextElement = [self innerTextHTMLElement];
    [innerTextElement setInnerHTML:[self HTMLString]];
    
    
    [self updateStyle];

    
    
    // Mimic NSTextField and select all
    if (selectAfterUpdate)
    {
        DOMRange *range = [[[self HTMLElement] ownerDocument] createRange];
        [range selectNodeContents:[self textHTMLElement]];
        [[self webEditor] setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
    }
    
    [self didUpdateWithSelector:_cmd];
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
    [self updateStyle];
}

- (void)setHTMLString:(NSString *)html attachments:(NSSet *)attachments;
{
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
}

#pragma mark Alignment

@synthesize alignment = _alignment;
- (void)setAlignment:(NSTextAlignment)alignment;
{
    _alignment = alignment;
    
    if ([self isHTMLElementCreated])
    {
        DOMCSSStyleDeclaration *style = [[self textHTMLElement] style];
        
        switch (alignment)
        {
            case NSLeftTextAlignment:
                [style setTextAlign:@"left"];
                break;
            case NSRightTextAlignment:
                [style setTextAlign:@"right"];
                break;
            case NSCenterTextAlignment:
                [style setTextAlign:@"center"];
                break;
            case NSJustifiedTextAlignment:
                [style setTextAlign:@"justify"];
                break;
            default:
                [style setTextAlign:nil];
                break;
        }
    }
}

- (IBAction)alignCenter:(id)sender; { [[self representedObject] setAlignment:NSCenterTextAlignment]; }
- (IBAction)alignJustified:(id)sender; { [[self representedObject] setAlignment:NSJustifiedTextAlignment]; }
- (IBAction)alignLeft:(id)sender; { [[self representedObject] setAlignment:NSLeftTextAlignment]; }
- (IBAction)alignRight:(id)sender; { [[self representedObject] setAlignment:NSRightTextAlignment]; }

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
	VALIDATION((@"%s %@",__FUNCTION__, anItem));
    BOOL result = YES;
    
    SEL action = [anItem action];
    if (action == @selector(alignCenter:) ||
        action == @selector(alignJustified:) ||
        action == @selector(alignLeft:) ||
        action == @selector(alignRight:))
    {
        result = [[self representedObject] respondsToSelector:@selector(setAlignment:)];
    }
    
    return result;
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

@synthesize placeholderHTMLString = _placeholder;
- (void)setPlaceholderHTMLString:(NSString *)placeholder
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
    if (element && [self placeholderHTMLString] && [[[self innerTextHTMLElement] innerText] isWhitespace])
    {
        [[self innerTextHTMLElement] setInnerHTML:[self placeholderHTMLString]];
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
            
            // Make sure there's no later content outside the <SPAN> #92432
            DOMNode *nextNode;
            while (nextNode = [result nextSibling])
            {
                [result appendChild:nextNode];
            }
            
            // Move styling down to children. #133908
            if ([result hasAttribute:@"style"])
            {
                DOMElement *aChild = [result firstElementChild];
                do
                {
                    NSString *style = [aChild getAttribute:@"style"];
                    if ([style length] > 0)
                    {
                        style = [style stringByAppendingFormat:@" %@", [result getAttribute:@"style"]];
                    }
                    else
                    {
                        style = [result getAttribute:@"style"];
                    }
                    
                    [aChild setAttribute:@"style" value:style];
                    
                } while (aChild = [aChild nextElementSibling]);
                
                [result removeAttribute:@"style"];
            }
        }
        else
        {
            DOMRange *selection = [[self webEditor] selectedDOMRange];
            DOMNode *selectionNode = [selection commonAncestorContainer];
            BOOL selectAll = (selectionNode == result);
            
            
            // Create one and insert it
            firstChild = (DOMHTMLElement *)[[result ownerDocument] createElement:@"SPAN"];
            [firstChild setClassName:@"in"];
            
            DOMNode *refNode = [result firstChild];
            [result insertBefore:firstChild refChild:refNode];
            
            
            // Move any existing nodes inside the span
            while (refNode)
            {
                [firstChild appendChild:refNode];
                refNode = [firstChild nextSibling];
            }
            
            
            // Finish, repairing selection as needed
            result = firstChild;
            
            if (selectAll) [selection selectNodeContents:result];
            [[self webEditor] setSelectedDOMRange:selection affinity:0];
        }
    }
    
    return result;
}

#pragma mark Dependencies

- (void)startObservingDependencies;
{
    [super startObservingDependencies];
    
    id object = [self representedObject];
    if (object)
    {
        if (![self infoForBinding:NSValueBinding])
        {
            [self bind:NSValueBinding toObject:object withKeyPath:@"textHTMLString" options:nil];
        }
        
        if (![self infoForBinding:NSAlignmentBinding])
        {
            [self bind:NSAlignmentBinding toObject:object withKeyPath:@"alignment" options:nil];
        }
    }
}

- (void)stopObservingDependencies;
{
    [self unbind:NSAlignmentBinding];
    [self unbind:NSValueBinding];
    
    [super stopObservingDependencies];
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

- (SVTextDOMController *)newTextDOMController;
{
    SVTextFieldDOMController *result = [[SVTextFieldDOMController alloc] initWithRepresentedObject:self];
    [result setPlaceholderHTMLString:NSLocalizedString(@"Title", "placeholder")];
    [result setRichText:YES];
    [result setFieldEditor:YES];
    
    // Bind to model
    [result bind:NSValueBinding
        toObject:self
     withKeyPath:@"textHTMLString"
         options:nil];
    
    [result bind:NSAlignmentBinding toObject:self withKeyPath:@"alignment" options:nil];
    
    
    return result;
}

@end
