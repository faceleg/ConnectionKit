//
//  SVBindableTextBlockDOMController.m
//  Marvel
//
//  Created by Mike on 26/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBindableTextBlockDOMController.h"


@interface SVBindableTextBlockDOMController ()
@property(nonatomic, copy) NSString *boundValue;
@end


@implementation SVBindableTextBlockDOMController

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
    // Push changes (if any) from the DOM down into the model
    NSString *editedValue = ([self isRichText] ? [self HTMLString] : [self string]);
    if (![editedValue isEqualToString:[self boundValue]])
    {
        NSDictionary *bindingInfo = [self infoForBinding:NSValueBinding];
        id observerObject = [bindingInfo objectForKey:NSObservedObjectKey];
        [observerObject setValue:editedValue
                          forKey:[bindingInfo objectForKey:NSObservedKeyPathKey]];
    }
    
    return YES;
}

@end
