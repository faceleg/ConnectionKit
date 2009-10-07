//
//  SVBindableTextBlockDOMController.m
//  Marvel
//
//  Created by Mike on 26/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBindableTextBlock.h"


@interface SVBindableTextBlock ()
@property(nonatomic, copy) NSString *boundValue;
@end


@implementation SVBindableTextBlock

#pragma mark Bindings/NSEditor

// Just like a Text View/Field, we implement the NSEditor protocol for easy control of editing
+ (void)initialize
{
    // Bindings
    [self exposeBinding:NSValueBinding];
    //[self exposeBinding:@"HTMLString"];
}

@synthesize boundValue = _boundValue;

// These bridge Cocoa's "value" binding terminology with our internal one
- (id)valueForKey:(NSString *)key
{
    if ([key isEqualToString:NSValueBinding])
    {
        return [self boundValue];
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
        [self setBoundValue:value];
        
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

- (void)discardEditing
{
    // Reset DOM to match our bound value
    if ([self isRichText])
    {
        [self setHTMLString:[self boundValue]];
    }
    else
    {
        [self setString:[self boundValue]];
    }
}

- (BOOL)commitEditing;
{
    // Since the edit is going to be committed to the model, we no longer want the WebView handling undo
    [[self webView] _clearUndoRedoOperations];
    
    
    // Push changes (if any) from the DOM down into the model
    NSString *editedValue = ([self isRichText] ? [self HTMLString] : [self string]);
    if (![editedValue isEqualToString:[self boundValue]])
    {
        NSDictionary *bindingInfo = [self infoForBinding:NSValueBinding];
        id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
        [observedObject setValue:editedValue
                          forKey:[bindingInfo objectForKey:NSObservedKeyPathKey]];
    }
    
    
    // Tell controller we're done. It's an informal protocol that object may or may not implement
    id observedObject = [[self infoForBinding:NSValueBinding] objectForKey:NSObservedObjectKey];
    if ([observedObject respondsToSelector:@selector(objectDidEndEditing:)])
    {
        [observedObject objectDidEndEditing:self];
    }
    
    return YES;
}

#pragma mark Superclass Hooks
// How we know that something changed and therefore binding needs to match

- (void)textDidEndEditingWithMovement:(NSNumber *)textMovement;
{
    [super textDidEndEditingWithMovement:textMovement];
    [self commitEditing];   // TODO: Can we handle it returning NO?
}

- (void)didBeginEditing;
{
    [super didBeginEditing];
    
    // Tell controller we're starting editing. It's an informal protocol that object may or may not implement
    id observedObject = [[self infoForBinding:NSValueBinding] objectForKey:NSObservedObjectKey];
    if ([observedObject respondsToSelector:@selector(objectDidBeginEditing:)])
    {
        [observedObject objectDidBeginEditing:self];
    }
}

@end
