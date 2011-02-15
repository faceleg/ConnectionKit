//
//  SVMigrationManager.h
//  Sandvox
//
//  Created by Mike on 14/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVMigrationManager : NSMigrationManager
{
  @private
    NSManagedObjectModel    *_mediaModel;
    NSManagedObjectContext  *_mediaContext;
}

// Designated initializer
- (id)initWithSourceModel:(NSManagedObjectModel *)sourceModel
               mediaModel:(NSManagedObjectModel *)mediaModel
         destinationModel:(NSManagedObjectModel *)destinationModel;

- (BOOL)migrateDocumentFromURL:(NSURL *)sourceDocURL
              toDestinationURL:(NSURL *)dURL
                         error:(NSError **)error;

- (NSManagedObjectModel *)sourceMediaModel;
- (NSManagedObjectContext *)sourceMediaContext;

- (NSFetchRequest *)pagesFetchRequest;

@end
