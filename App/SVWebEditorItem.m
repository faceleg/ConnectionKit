//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"

#import "SVBodyElement.h"
#import "SVHTMLContext.h"

#import "DOMNode+Karelia.h"


@implementation SVWebEditorItem

- (void)dealloc
{
    [self setChildWebEditorItems:nil];
    [_bodyText release];
    
    [super dealloc];
}

#pragma mark Accessors

- (void)loadHTMLElement
{
    // Try to create HTML corresponding to our content (should be a Pagelet or plug-in)
    NSString *htmlString = [self representedObjectHTMLString];
    OBASSERT(htmlString);
    
    DOMDocumentFragment *fragment = [[self HTMLDocument]
                                     createDocumentFragmentWithMarkupString:htmlString
                                     baseURL:[[self HTMLContext] baseURL]];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [self setHTMLElement:element];
}

@synthesize bodyText = _bodyText;

- (NSString *)representedObjectHTMLString;
{
    SVHTMLContext *context = [self HTMLContext];
    
    [context push];
    NSString *result = [[self representedObject] HTMLString];
    [context pop];
    
    return result;
}

- (BOOL)isEditable { return NO; }

- (SVWebEditorView *)webEditorView
{
    return [[self parentWebEditorItem] webEditorView];
}

#pragma mark Tree

/*  Fairly basic heirarchy maintenance stuff here
 */

@synthesize childWebEditorItems = _childControllers;
- (void)setChildWebEditorItems:(NSArray *)controllers
{
    [[self childWebEditorItems] makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                                withObject:nil];
    
    controllers = [controllers copy];
    [_childControllers release]; _childControllers = controllers;
    
    [controllers makeObjectsPerformSelector:@selector(setParentWebEditorItem:)
                                 withObject:self];
}

@synthesize parentWebEditorItem = _parentController;

- (void)addChildWebEditorItem:(SVWebEditorItem *)controller;
{
    OBPRECONDITION(controller);
    
    NSArray *children = [[self childWebEditorItems] arrayByAddingObject:controller];
    if (!children) children = [NSArray arrayWithObject:controller];
    [_childControllers release]; _childControllers = [children copy];
    
    [controller setParentWebEditorItem:self];
}

- (void)removeFromParentWebEditorItem;
{
    [self setParentWebEditorItem:nil];
    
    SVWebEditorItem *parent = [self parentWebEditorItem];
    
    NSMutableArray *children = [[parent childWebEditorItems] mutableCopy];
    [children removeObject:self];
    
    if (parent)
    {
        [parent->_childControllers release]; parent->_childControllers = children;
    }
}

@end
