//
//  SVDocumentUndoManager.m
//  Sandvox
//
//  Created by Mike on 25/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDocumentUndoManager.h"


@implementation SVDocumentUndoManager

- (unsigned short)lastRegisteredActionIdentifier;
{
    return _lastRegisteredActionIdentifier;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    _lastRegisteredActionIdentifier++;
    return [super forwardInvocation:anInvocation];
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
    _lastRegisteredActionIdentifier++;
    return [super registerUndoWithTarget:target selector:aSelector object:anObject];
}

- (void)undoNestedGroup
{
    _lastRegisteredActionIdentifier++;
    return [super undoNestedGroup];
}

- (void)redo
{
    _lastRegisteredActionIdentifier++;
    return [super redo];
}

@end
