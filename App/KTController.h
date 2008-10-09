//
//  KTController.h
//  Marvel
//
//  Created by Mike on 09/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDocument, KTDocWindowController;


@protocol KTDocumentControllerChain
- (id <KTDocumentControllerChain>)parentController;
- (KTDocument *)document;
- (KTDocWindowController *)windowController;
@end


@interface KTDocViewController : NSResponder <KTDocumentControllerChain>
{
    @private
    id <KTDocumentControllerChain>  _parentController;  // All weak refs
    KTDocWindowController           *_windowController;
    KTDocument                      *_document;
}

- (id <KTDocumentControllerChain>)parentController;
- (void)setParentController:(id <KTDocumentControllerChain>)controller;

- (KTDocWindowController *)windowController;
- (void)setWindowController:(KTDocWindowController *)controller;

- (KTDocument *)document;
- (void)setDocument:(KTDocument *)document;

@end
