//
//  SVMediaMigrationPolicy.h
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVEntityMigrationPolicy.h"


@class SVMigrationManager;


@interface SVMediaMigrationPolicy : SVEntityMigrationPolicy

+ (NSManagedObject *)createDestinationInstanceForSourceInstance:(NSManagedObject *)sInstance mediaContainerIdentifier:(NSString *)mediaID entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;

+ (NSManagedObject *)sourceMediaFileForContainerIdentifier:(NSString *)containerID manager:(SVMigrationManager *)manager error:(NSError **)error;

@end


#pragma mark -


@interface SVFileMediaMigrationPolicy : SVMediaMigrationPolicy
@end



#pragma mark -


@interface SVFullPageRawHTMLMediaMigrationPolicy : SVEntityMigrationPolicy
@end