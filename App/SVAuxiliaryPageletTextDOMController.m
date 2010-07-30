//
//  SVAuxiliaryPageletTextDOMController.m
//  Sandvox
//
//  Created by Mike on 21/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
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
        [[self textHTMLElement] setInnerHTML:NSLocalizedString(@"<p>Double-click to edit</p>", "placeholder")];
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
    [self updateDOMWithPlaceholderStringIfNeeded];
}

@end


@implementation SVAuxiliaryPageletText (SVAuxiliaryPageletTextDOMController)

- (SVDOMController *)newDOMController;
{
    SVTextDOMController *result = [[SVAuxiliaryPageletTextDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    
    return result;
}

@end