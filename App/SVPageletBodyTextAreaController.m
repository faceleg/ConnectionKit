//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBodyTextAreaController.h"
#import "SVParagraphController.h"

#import "SVBodyParagraph.h"
#import "SVContentObject.h"
#import "SVPageletBody.h"
#import "SVWebContentItem.h"


@implementation SVPageletBodyTextAreaController

#pragma mark Init & Dealloc

- (id)initWithTextArea:(SVWebTextArea *)textArea content:(SVPageletBody *)pageletBody;
{
    [self init];
    
    _pageletBody = [pageletBody retain];
    
    _textArea = [textArea retain];
    [textArea setDelegate:self];
    [self updateEditorItems];
    
    
    // Match paragraphs up to the model
    _paragraphControllers = [[NSMutableArray alloc] initWithCapacity:[[pageletBody elements] count]];
    DOMNode *aDOMNode = [[textArea HTMLDOMElement] firstChild];
    SVBodyElement *aModelElement = [pageletBody firstElement];
    
    while (aModelElement)
    {
        if ([aDOMNode isKindOfClass:[DOMHTMLElement class]])
        {
            DOMHTMLElement *htmlElement = (DOMHTMLElement *)aDOMNode;
            if ([[htmlElement idName] isEqualToString:[aModelElement editingElementID]])
            {
                if ([aModelElement isKindOfClass:[SVBodyParagraph class]])
                {
                    SVParagraphController *controller = [[SVParagraphController alloc]
                                                         initWithParagraph:(SVBodyParagraph *)aModelElement
                                                         HTMLElement:htmlElement];
                    
                    [_paragraphControllers addObject:controller];
                    [controller release];
                }
                
                aModelElement = [aModelElement nextElement];
            }
        }
        
        aDOMNode = [aDOMNode nextSibling];
    }
    
    
    
    return self;
}

- (void)dealloc
{
    [_textArea setDelegate:nil];
    [_textArea release];
    
    [_pageletBody release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize textArea = _textArea;
@synthesize content = _pageletBody;

@synthesize editorItems = _editorItems;

- (void)updateEditorItems
{
    // Generate an editor item for each -contentItem
    NSSet *contentObjects = nil;//[[self content] contentObjects];
    NSMutableArray *editorItems = [[NSMutableArray alloc] initWithCapacity:[contentObjects count]];
    
    for (SVContentObject *aContentObject in contentObjects)
    {
        DOMElement *domElement = [[self content] elementForContentObject:aContentObject
                                                            inDOMElement:[[self textArea] HTMLDOMElement]];
        
        if (domElement)
        {
            SVWebContentItem *anItem = [[SVWebContentItem alloc] initWithDOMElement:domElement];
            [editorItems addObject:anItem];
            [anItem release];
        }
    }
    
    [_editorItems release], _editorItems = editorItems;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
