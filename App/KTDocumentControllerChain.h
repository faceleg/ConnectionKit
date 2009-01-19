//
//  KTDocumentControllerChain.h
//  Marvel
//
//  Created by Mike on 09/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//



@class KTDocument, KTDocWindowController;


@protocol KTDocumentControllerChain
- (id <KTDocumentControllerChain>)parentController;
- (KTDocument *)document;
- (KTDocWindowController *)windowController;
@end


