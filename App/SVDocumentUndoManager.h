//
//  SVDocumentUndoManager.h
//  Sandvox
//
//  Created by Mike on 25/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVTextDOMController.h" // for its undo manager additions


// Declaring the deleted media API on a vanilla undo manager, so you can use without typescasting. The default implementations don't do a lot!

@interface NSUndoManager (SVDeletedMedia)
- (NSURL *)deletedMediaDirectory;
- (BOOL)haveCreatedDeletedMediaDirectory;
- (BOOL)removeDeletedMediaDirectory:(NSError **)error; // returns YES if directory was never created
@end


#pragma mark -


// Concrete implementation of deleted media and action identifier methods.

@interface SVDocumentUndoManager : NSUndoManager
{
  @private
    NSURL           *_deletedMediaDirectory;
    unsigned short  _lastRegisteredActionIdentifier;
}

@end
