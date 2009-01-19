//
//  KTDocViewController.h
//  Marvel
//
//  Created by Mike on 09/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KSViewController.h"

#import "KTDocumentControllerChain.h"


@class KTDocument, KTDocWindowController;


@interface KTDocViewController : KSViewController <KTDocumentControllerChain>
{
@private
    id <KTDocumentControllerChain>  _parentController;  // All weak refs
    KTDocWindowController           *_windowController;
    KTDocument                      *_document;
}

#pragma mark Controller Chain
- (id <KTDocumentControllerChain>)parentController;
- (void)setParentController:(id <KTDocumentControllerChain>)controller;

- (KTDocWindowController *)windowController;
- (void)setWindowController:(KTDocWindowController *)controller;

- (KTDocument *)document;
- (void)setDocument:(KTDocument *)document;

@end
