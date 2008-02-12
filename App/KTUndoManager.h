//
//  KTUndoManager.h
//  Marvel
//
//  Created by Terrence Talbot on 5/1/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTDocument;
@interface KTUndoManager : NSUndoManager
{
	KTDocument *myDocument;
}

- (KTDocument *)document;
- (void)setDocument:(KTDocument *)aDocument;

@end
