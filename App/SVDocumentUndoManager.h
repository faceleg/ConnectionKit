//
//  SVDocumentUndoManager.h
//  Sandvox
//
//  Created by Mike on 25/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVDocumentUndoManager : NSUndoManager
{
  @private
    unsigned short _lastRegisteredActionIdentifier;
}

@end
