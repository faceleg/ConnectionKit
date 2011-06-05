//
//  SVAuxiliaryPageletTextDOMController.m
//  Sandvox
//
//  Created by Mike on 21/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVAuxiliaryPageletTextDOMController.h"
#import "SVAuxiliaryPageletText.h"


@implementation SVAuxiliaryPageletTextDOMController

- (BOOL)shouldDisplayPlaceholderString;
{
    SVAuxiliaryPageletText *text = [self representedObject];
    return [text isEmpty];
}

- (void)updateDOMWithPlaceholderStringIfNeeded;
{
    if ([self shouldDisplayPlaceholderString])
    {
        NSString *entityName = [[[self representedObject] entity] name];
        
        NSString *placeholder;
        if ([entityName isEqualToString:@"PageletIntroduction"])
        {
            placeholder = NSLocalizedString(@"<p>Introduction text</p>", "placeholder");
        }
        else if ([entityName isEqualToString:@"PageletCaption"])
        {
            placeholder = NSLocalizedString(@"<p>Caption text</p>", "placeholder");
        }
        else
        {
            placeholder = NSLocalizedString(@"<p>Double-click to edit</p>", "placeholder");
        }
        
        [[self textHTMLElement] setInnerHTML:placeholder];
    }
}

- (void)setTextHTMLElement:(DOMHTMLElement *)element;
{
    [super setTextHTMLElement:element];
    [self updateDOMWithPlaceholderStringIfNeeded];
}

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
{
    [super webEditorTextDidEndEditing:notification];
    
    if ([self shouldDisplayPlaceholderString])
    {
        SVRichText *text = [self representedObject];
        if ([text respondsToSelector:@selector(setHidden:)])
        {
            [text setValue:NSBOOL(YES) forKey:@"hidden"];
        }
        else
        {
            [self updateDOMWithPlaceholderStringIfNeeded];
        }
    }
}

#pragma mark Selection

- (DOMElement *)selectableDOMElement;
{
    return ([self representedObject] && [self enclosingGraphicDOMController] ?
            [self HTMLElement] :
            nil);
}

@end


@implementation SVAuxiliaryPageletText (SVAuxiliaryPageletTextDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVGraphicDOMController alloc] initWithRepresentedObject:self];
}

- (SVTextDOMController *)newTextDOMController;
{
    SVTextDOMController *result = [[SVAuxiliaryPageletTextDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    
    return result;
}

@end